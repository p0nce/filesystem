/**
    Home of `DirectoryEntry`, `DirectoryRange` and `dirEntries`.

    For some reason, both Phobos and std::filesystem have a directory
    entry type that ease access to many of the attributes, though
    most of the time you are mostly interested by their path.

    Copyright: Copyright (c) 2026, Guillaume Piolat <contact@auburnsounds.com>

    License: MIT (https://mit-license.org/)
*/
module filesystem.direntry;

import nulib.text.unicode;
import nulib.string;
import nulib.memory;
import nulib.collections.vector;

import filesystem.types;
import filesystem.path;
import filesystem.internals;
import filesystem.freefunc;

//debug = recursive;

version(Windows)
{
    import core.sys.windows.windef;
    import core.sys.windows.winbase;
}
else version(Posix)
{
    import cerrno  = core.stdc.errno;
    import pdirent = core.sys.posix.dirent;
}

@nogc:

// PERF: it would be possible to be all-struct if nulib vector would hold
// movable, non-copyable structs.

// To debug the tricky recursive subdir
debug(recursive) import core.stdc.stdio;

/**
    Represents a directory entry. The object stores a path as a member 
    and may also store additional file attributes (hard link count, 
    status, symlink status, file size, and last write time) during 
    directory iteration. 
*/
struct DirectoryEntry
{
nothrow @nogc:
public:

    /// Path to the directory entry, can be relative or absolute.
    Path path;

    /// Status of the file as it was when discovered. 
    ///
    /// Warning: By the time you access it, it might not exist 
    /// anymore.
	FileStatus status;

	this(Path path, FileStatus status)
	{
		this.path = path;
		this.status = status;
	}
}

/**
    Iterate over a directory's entries.
*/
class DirectoryRange
{
@nogc:
    /**
        Constructs a directory iterator that refers to the first 
        directory entry of a directory identified by `p`. If `p` 
        refers to a non-existing file or not a directory, throws.

        Content of the directory doesn't follow the symlinks,
        the symlinks are returned instead. You can eventually 
        resolve them using `readSymlink`.

        Params:
            p = Path to a directory.
            options = Options modifier for traversal.

        Throws: `FileSystemIOException`, 
                `FileNotFoundException`,
                `InvalidPathException`.
    */
    this(Path p, DirectoryOptions options = DirectoryOptions.none)
    {       
        this.base = p;
        this.options = options;
        this.finished = false;
        if (p.empty)
        {
            finished = true;
            return;
        }

        bool skipPermDenied = (options & DirectoryOptions.skipPermissionDenied) != 0;

        version(Windows)
        {
            ZeroMemory(&findData, findData.sizeof);
            nwstring wpath = (p / "*").native.toUTF16();
            searchHandle = FindFirstFileW(wpath.ptr, &findData);
            
            if (searchHandle == INVALID_HANDLE_VALUE)
            {
                DWORD err = GetLastError();
                cleanupSearch();
                finished = true;

                if (err == ERROR_PATH_NOT_FOUND)
                {
                    // directory itself doesn't exist
                    throwFileNotFound(p);
                }
                else if (err == ERROR_FILE_NOT_FOUND)
                {
                    // there is no file => no error
                }
                else if (err == ERROR_ACCESS_DENIED && skipPermDenied)
                {
                    // access is denied, no files and no errors
                }
                else
                    throwIO(kStrErrFileSearch);
            }

            bool skip = ! fillResEntry();

            if (skip || isSpecial())
                nextFile();
        }
        else version(Posix)
        {
            Path nativePath = p.native();
            do 
            { 
                dir = pdirent.opendir(nativePath.ptr);
            } while(cerrno.errno == cerrno.EINTR && !dir);
            
            if (!dir) 
            {
                int error = cerrno.errno;
                if (error == cerrno.ENOENT)
                {
                    throwFileNotFound(p);
                }
                else if ( (error == cerrno.EACCES || error == cerrno.EPERM) && skipPermDenied)
                {
                    // lack of permission, ignore
                }
                else
                    throwIO(kStrErrFileSearch);
            }
            else 
            {
                nextFile();
            }
        }
        else
            static assert(0);
    }

    ~this()
    {
        if (!finished) 
        {            
            cleanupSearch();
            finished = true;
        }
    }

    /**
        Returns: true if `front()` is the current file.
    */
    bool empty()    => finished;

    /**
        Proceed to the next file in directory.
    */
    void popFront() => nextFile();

    /** 
        Get the current iterated file.
        This needs to not make a system call, since at this point
        the file might have disappeared since the API is racey.
    */
    DirectoryEntry front()
    {
        return resEntry;
    }

private:
    Path base;
    DirectoryOptions options;
    bool finished = true; // .init must be empty
    DirectoryEntry resEntry;

    void cleanupSearch()
    {
        version(Windows)
        {
            if (searchHandle != INVALID_HANDLE_VALUE)
            {
                FindClose(searchHandle);
                searchHandle = INVALID_HANDLE_VALUE;
            }
        }
        else version(Posix)
        {
            pdirent.closedir(dir);
            dir = null;
            // Note: errors on closedir are ignored there, a bit
            // like for fclose
        }
        else
            static assert(0);
    }

    void nextFile()
    {
        version(Windows)
        {
            bool skip;
            do
            {
                skip = false;
                BOOL res = FindNextFileW(searchHandle, &findData);
                if (res == 0)
                {
                    if (GetLastError() == ERROR_NO_MORE_FILES)
                    {
                        cleanupSearch();
                        finished = true;
                        break;
                    }
                    else
                        throwIO(kStrErrFileSearch);
                }
                else
                {
                    skip = ! fillResEntry();
                }
            } while(skip || isSpecial());
        }
        else version(Posix)
        {
            bool skipPermDenied = (options & DirectoryOptions.skipPermissionDenied) != 0;

            if (dir) 
            {
                bool skip;
                do 
                {
                    skip = false;
                    int err;
                    do 
                    {
                        // "If the end of the directory stream is reached, NULL is returned
                        //  and errno is not changed.  If an error occurs, NULL is returned
                        //  and errno is set to indicate the error.  To distinguish end of
                        //  stream from an error, set errno to zero before calling readdir()
                        //  and then check the value of errno if NULL is returned."
                        cerrno.errno = 0;
                        dirent = pdirent.readdir(dir);
                        err = cerrno.errno;
                    } while (err == cerrno.EINTR && !dirent);

                    if (dirent) 
                    {
                        if (isSpecial())
                        {
                            skip = true;
                            continue;
                        }

                        resEntry.path = base / nstring(fromStringz(dirent.d_name.ptr));

                        // Now getting its file status, however it may fail (eg: file being 
                        // deleted in a racey way between readdir and stat). In this case,
                        // skip this entry.
                        if (!statusNothrow(resEntry.path, resEntry.status))
                            continue;
                    }
                    else if (err == 0)
                    {
                        // end of directory stream
                        cleanupSearch();
                        finished = true;
                        break;
                    }
                    else if ((err == cerrno.EACCES || err == cerrno.EPERM) && skipPermDenied)
                    {
                        skip = true;
                    }
                    else
                        throwIO(kStrErrFileSearch);

                } while (skip);
            }
        }
        else
            static assert(0);
    }

    version(Windows)
    {
        WIN32_FIND_DATAW findData;
        HANDLE searchHandle = INVALID_HANDLE_VALUE;         

        bool isSpecial()
        {
            return fs_wcscmp(findData.cFileName.ptr, "."w.ptr) == 0
                || fs_wcscmp(findData.cFileName.ptr, ".."w.ptr) == 0;
        }

        // Returns: true if entry is correct, 
        //          false if the file should be skipped
        // That happens the name is invalid Unicode.
        bool fillResEntry()
        {            
            nwstring name = nwstring(fromStringz(findData.cFileName.ptr));
            nstring nameutf8 = name.toUTF8();
            
            // Invalid Unicode, do not consider this file.
            if (! nulib.text.unicode.utf16.validate(name))
                return false;

            resEntry.path = base / name.toUTF8();

            setTimeFromFILETIME(resEntry.status, findData.ftLastWriteTime);
            setFileSizeAndType(resEntry.status,
                               findData.dwFileAttributes,
                               findData.nFileSizeHigh,
                               findData.nFileSizeLow);
            resEntry.status = symlinkStatus(resEntry.path);

            return true;
        }
    }
    else version(Posix)
    {
         pdirent.DIR* dir;
         pdirent.dirent* dirent;

         bool isSpecial()
         {
            assert(dirent);
            return fs_strcmp(dirent.d_name.ptr, ".".ptr) == 0 
                || fs_strcmp(dirent.d_name.ptr, "..".ptr) == 0;
         }
    }
    else
        static assert(0);
}


/**
    Iterate over a directory's entries, recursively by iterating
    sub-directories.
*/
class RecursiveDirectoryRange
{
@nogc:

    this(Path p, DirectoryOptions opts = DirectoryOptions.none)
    {
        this.opts = opts;
        stack ~= nogc_new!RangePlusParent( nogc_new!DirectoryRange(p, opts), DirectoryEntry.init);
        state = State.initial;
        finished = ! nextFile(stored); // pick the first file
    }

    bool empty() => finished;

    void popFront()
    {
        finished = ! nextFile(stored);
    }

    /** 
        Get the current iterated file.
        This needs to not make a system call, since at this point
        the file might have disappeared since the API is racey.
    */
    DirectoryEntry front()
    {
        return stored;
    }

    // Note: goal is to eliminate front and treat it
    // Surprisingly hard algorithm to get right.
    // Returns: false if the iteration is finished, true if 
    // outEntry is the next item to return.
    bool nextFile(out DirectoryEntry outEntry)
    {
        debug(recursive) printf("nextFile\n");
        bool depthFirst = isDepthFirst();

        // there must be at least one range in the stack
        assert(! stack.empty); 

       // bool found = false;
        bool doNotPop = false;
        while(true)
        {
            final switch(state)
            {
                case State.initial:
                {
                    debug(recursive) printf("# State.initial\n", state);
                    if ((*top).range.empty)
                    {
                        debug(recursive) printf(" whole recursive range is empty\n", state);
                        // the whole recursive range is empty
                        stack.popBack();
                        return false;
                    }
                    else
                    {
                        // unless if a directory!
                        state = State.frontIsTopFront;
                        doNotPop = true;
                    }
                    break;
                }

                case State.frontIsTopFront:
                {
                    debug(recursive) printf("# State.frontIsTopFront\n", state);

                    // top.front must exist, if it does not, we entered an empty directory
                    // Ugly, the right design would be simpler.
                    if (top.range.empty)
                    {
                        goto findNonEmptyTopRange;
                    }

                    //DirectoryEntry current = front();
                    //debug(recursive) printf(" => current .front is %.*s\n", cast(int)current.path.length, current.path.ptr);

                    // Pop from the top range, see what happens

                    if (!doNotPop)
                    {
                        //printf(" => popFront into top range\n");
                        top.range.popFront();

                    findNonEmptyTopRange:
                        // top range is empty
                        if (top.range.empty())
                        {
                            debug(recursive) printf(" => now the top range is empty\n");
                            if (depthFirst)
                            {
                                debug(recursive) printf(" returning the directory after its contents\n");
                                state = State.frontIsParentPostOrder;
                                outEntry = top.parentEntry;
                                return stack.length > 1; // if there is only one item, it's the root item
                            }
                            else
                            {
                                // remove done range
                                stack.popBack();

                                // was last range?
                                if (stack.empty)
                                    return false;

                                goto findNonEmptyTopRange;
                            }
                        }
                        // Else just proceed to next file in list,
                        // where the logic join with the initial
                        // "do not pop"
                    }
                    doNotPop = false;

                    // if we are here, top.front() is our newfind
                    // However it could be a directory.

                    DirectoryEntry f = top.range.front();
                    debug(recursive) printf("top.front() is %.*s\n", cast(int) f.path.length, f.path.ptr);

                    if ((opts & DirectoryOptions.followDirectorySymlink) && isSymlink(f.status))
                    {
                        // FUTURE: detect when a link points upper in the tree, 
                        // makes for an infinite loop
                        Path target = resolveSymlink(f.path);
                        if (isDirectory(target))
                        {
                            f.path = target;
                            f.status.type = FileType.directory;
                        }
                    }

                    if (f.status.type == FileType.directory)
                    {
                        debug(recursive) printf("  => and it is a directory...\n");
                        if (depthFirst)
                        {
                            debug(recursive) printf("  => push it on stack\n");
                            // Push this directory range in stack, WITH parent info
                            stack ~= nogc_new!RangePlusParent( nogc_new!DirectoryRange(f.path, opts), f);
                            state = State.frontIsTopFront;
                            doNotPop = true;
                            break;
                        }
                        else
                        {
                            // Consume the directory slot, it avoid lack of emptiness detection
                            // because to be empty a recursive range need all empty ranges.
                            top.range.popFront();

                            debug(recursive) printf("  => make it return in pre-order\n");
                            stack ~= nogc_new!RangePlusParent( nogc_new!DirectoryRange(f.path, opts), f);
                            state = State.frontIsParentPreOrder;

                            outEntry = f;
                            return true;
                        }
                    }
                    else
                    {
                        debug(recursive) printf(" => and it is a regular file, return that\n", state);
                        outEntry = f;
                        doNotPop = true;
                        return true;
                    }
                    break;
                }

                case State.frontIsParentPreOrder:
                {
                    debug(recursive) printf("# State.frontIsParentPreOrder\n");
                    // Push this directory range in stack, with no parent info
                    assert( ! depthFirst);
                    state = State.frontIsTopFront;
                    doNotPop = true; // do not pop first item in the directory
                    break;
                }

                case State.frontIsParentPostOrder:
                {
                    debug(recursive) printf("# frontIsParentPostOrder\n");
                    assert(depthFirst);

                    assert(top.range.empty);
                    stack.popBack();
                    // was last range?
                    if (stack.empty)
                    {
                        debug(recursive) printf(" => was the last range\n");
                        return false;
                    }
                    assert( ! top.range.empty );
                    debug(recursive) printf(" Drop item %.*s from range\n", top.range.front.path.length, top.range.front.path.ptr);

                    top.range.popFront(); // skip over the directory we used to enter
                    if (top.range.empty)
                    {
                        if (stack.length == 1)
                            return false; // do not return root .

                        outEntry = top.parentEntry;
                        return true;
                    }
                    else
                    {
                        state = State.frontIsTopFront;
                        doNotPop = true;
                    }
                    break;
                }
            }
        }
        return false;
    }

private:

    // A stack of ranges, that iterate over sub-dirs.
    // Item 0 is the "root" path in argument.
    vector!RangePlusParent stack;

    State state;
    bool finished = false;
    DirectoryEntry stored;

    enum State
    {
        // Never happen once the range is constructed.
        initial,

        // Nominal case
        //
        // sub1/
        //      sub11/
        //          D
        //      A
        //      B   <----
        // sub2/
        //      C
        frontIsTopFront,

        // Breadth first, output directory before going into it
        //
        // sub1/
        //      sub11/ <-----
        //          D
        //      A
        //      B
        // sub2/
        //      C
        frontIsParentPreOrder,

        // Depth first, just after D.
        //
        // sub1/
        //      sub11/ <----- (but post D)
        //          D
        //      A
        //      B
        // sub2/
        //      C
        frontIsParentPostOrder,
    }

    static class RangePlusParent
    {
    nothrow @nogc:
        DirectoryRange range;

        // copy of the parent entry, .init on root
        // only used in depth first, and not for the root dir
        DirectoryEntry parentEntry;  

        this(DirectoryRange range, DirectoryEntry parentEntry)
        {
            this.range = range;
            this.parentEntry = parentEntry;
        }
    }

    bool hasTop() => ! stack.empty;

    RangePlusParent* top()
    {
        return stack.back;
    }

    DirectoryOptions opts;

    bool isDepthFirst()
        => (opts & DirectoryOptions.spanDepthFirst) != 0;
}