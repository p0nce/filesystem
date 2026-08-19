/**
    Free functions like in `std::filesystem`.

    Non-member functions go here. There is quite a bit of 
    free functions in std::filesystem, see the reference:
    https://en.cppreference.com/cpp/filesystem

    Copyright: Copyright (c) 2026, Guillaume Piolat <contact@auburnsounds.com>
    Copyright: Copyright (c) 2018, Steffen Schümann <s.schuemann@pobox.com>

    License: MIT (https://mit-license.org/)
*/
module filesystem.freefunc;

import nulib;
import nulib.text.unicode;
import nulib.memory;
import nulib.collections.vector;
import numem;

import filesystem.types;
import filesystem.path;
import filesystem.internals;
import filesystem.direntry;

@nogc:

version(Windows)
{
    import core.sys.windows.stat;
    import core.sys.windows.windef;
    import core.sys.windows.winbase;
}
else version(Posix)
{
    import core.stdc.errno;
    import core.sys.posix.unistd;
    import core.sys.posix.fcntl;
    import core.sys.posix.sys.stat;

    import core.sys.posix.stdlib;
    import cstdlib = core.stdc.stdlib;
    import cstdio = core.stdc.stdio: remove, rename;
}

// TODO: do we want isDirectory to throw when the path is invalid,
// an I/O error returned, or the directory isn't found? Or just return
// false.


/**
    Returns a path referencing the same file system location as p, 
    for which `Path.isAbsolute()` is true.

    Warning: this isn't thread-safe, as any other thread
    could modify this process' current directory.

    May throw `FilesystemException` if an error occurs.
*/
Path absolute(Path p)
{
    if (p == "")
        throwException(kStrPathIsEmptyNoAbs);
    return currentPath() / p;
}
///ditto
Path absolute(const(char)[] p)
    => absolute(Path(p));


/**
    Converts path `p` to a canonical absolute path, i.e. an absolute 
    path that has no dot, dot-dot elements or symbolic links in its 
    generic format representation. If `p` is not an absolute path, the 
    function behaves as if it is first made absolute by `absolute(p)`. 
    The path `p` must exist.
*/
// TODO
//Path canonical(Path p)
//{
//    /// need to implement: \\?\ pathes, \\.\ pathes, UNC pathes, read_symlink...
//}
// TODO weakly_canonical

/**
    Returns p made relative to base. Resolves symlinks and normalizes both p and base before other processing. 
*/
// TODO: need weakly_canonical
/*
Path relative(Path p, Path base = currentPath())
{
    return weakly_canonical(p).lexicallyRelative(weaklyCanonical(base));
}
*/

// TODO relative
// TODO proximate

// TODO copy
//  * it needs working symlinkStatus

/**
    Copies a single file from from to to, using the copy options 
    indicated by options.
*/
bool copyFile(Path from, Path to, 
              CopyOptions options = CopyOptions.none)
{
    if (! isRegularFile(from))
        throwException(kStrErrCopyFileNonReg);

    bool fromExists = false;
    bool toExists = false;
    FileStatus statusFrom = statusExists(from, fromExists);
    FileStatus statusTo   = statusExists(to, toExists);

    bool overwrite = false;
    if (toExists)
    {
        // destination exists

        // destination is source?
        if (equivalent(to, from))
            throwException(kStrErrCopySameFile);

        if (! isRegularFile(statusTo))
            throwException(kStrErrCopyDestNonReg);

        // What to do?
        int behaviour = options & 3;
        if (behaviour == CopyOptions.reportAnError)
        {
            throwIO(kStrErrCopyDestExists);
            return false;
        }
        else if (behaviour == CopyOptions.skipExisting) 
        {
            return false;
        }
        else if (behaviour == CopyOptions.overwriteExisting) 
        {
            overwrite = true;
        }
        else 
        {
            assert(behaviour == CopyOptions.updateExisting);
            if (lastWriteTime(from) > lastWriteTime(to))
                overwrite = true;
            else
                return false;
        }
    }

    // PERF Linux use instead copy_file_range

    version(Windows)
    {
        nwstring wfrom = from.native.toUTF16();
        nwstring wto = to.native.toUTF16();
        BOOL bFailIfExists = ! overwrite;
        if (! CopyFileW(wfrom.ptr, wto.ptr, bFailIfExists)) 
            throwIO(kStrErrFileCopyFailed);        
        return true;
    }
    else version(Posix)
    {
        int inHandle  = -1, 
            outHandle = -1;

        if ((inHandle = .open(from.native.ptr, O_RDONLY)) < 0) 
            throwIO(kStrErrOpenFileFailed); 

        assert(fromExists); // since it was opened, hence statusFrom is valid

        int mode = O_CREAT | O_WRONLY | O_TRUNC;
        if (!overwrite)
            mode |= O_EXCL;

        if ((outHandle = .open(to.native.ptr, mode, statusFrom.perms & FilePerms.all)) < 0) 
        {
            .close(inHandle);
            throwIO(kStrErrOpenFileFailed); 
        }

        if (overwrite)
        {
            if (statusTo.perms != statusFrom.perms) 
            {
                if (.fchmod(outHandle, cast(mode_t)(statusFrom.perms & FilePerms.all)) != 0) 
                {
                    .close(inHandle);
                    .close(outHandle);
                    throwIO(kStrErrChmodFailed); 
                }
            }
        }

        enum int BLOCK_SIZE = 16384;
        vector!byte buf;
        buf.resize(BLOCK_SIZE);        

        while (true) 
        {
            ptrdiff_t bytesRead;
            ptrdiff_t bytesWritten;

            do 
            {
                bytesRead = .read(inHandle, buf.ptr, BLOCK_SIZE);
            } while (bytesRead == -1 && errno == EINTR);

            if (bytesRead < 0)
                throwIO(kStrErrFileReadFailed);

            if (bytesRead == 0)
                break; // input file finished

            ptrdiff_t offset = 0;
            do 
            {
                bytesWritten = .write(outHandle, buf.ptr + offset, bytesRead);
                if (bytesWritten > 0)
                {
                    bytesRead -= bytesWritten;
                    offset += bytesWritten;
                }
                else if (bytesWritten <= 0 && errno != EINTR)
                {
                    // Note: 0 byte progressed is an error.
                    .close(inHandle);
                    .close(outHandle);
                    throwIO(kStrErrFileWriteFailed);
                }
            } while (bytesRead);
        }
        .close(inHandle);
        .close(outHandle);
        return true;

    }
    else
        static assert(0);
}


// TODO copy_symlink


/**
    Create a directory as if by POSIX `mkdir()`.
    The parent directory must already exist.

    Returns: `true` if created, `false` if already existing.
    
    Throws: `FileSystemIOException` or `InvalidPathException`.

    TODO: attributes, copy them from another file.
*/
bool createDirectory(Path p)
{
    // Already exists?
    try
    {
        FileStatus fs = status(p);
        if (isDirectory(fs))
            return false;
    }
    catch(FileNotFoundException e)
    {
        e.free();
    }

    // Doesn't yet exist, proceed to creation
    version(Windows)
    {
        nwstring ws = p.native.toUTF16();
        if (! CreateDirectoryW(ws.ptr, null))
            throwIO(kStrErrCreateDirectory);
    }
    else version(Posix)
    {
        mode_t attribs = cast(mode_t)FilePerms.all;
        if (mkdir(p.native.ptr, attribs) != 0)
            throwIO(kStrErrCreateDirectory);
    }
    return true;
}


/**
    Create a chain of directories.

    Returns: `true` if created, `false` if already existing.

    Throws: `FileSystemIOException` or `InvalidPathException`.

    TODO: attributes, copy them from another file.
*/
bool createDirectories(Path p)
{
    Path native = p.native();
    bool created = false;
    Path current = native.rootPath();

    foreach(part; native.iterateWithoutRootPath())
    {
        if (part == "") continue; // terminal separator
        if (part == ".") continue;
        current /= part;

        FileStatus fs;
        try
        {
             fs = status(current);

            // A file exists with the same name, and is not
            // a directory? Error.
            if (!isDirectory(fs))
                throwIO(kStrErrCreateDirFile);
        }
        catch(FileNotFoundException e)
        {
            e.free();

            // Create the directory
            if (createDirectory(current))
                created = true;
            else
                throwIO(kStrErrCreateDirectory);
        }
    }
    return created;
}

// TODO create_hard_link
// TODO create_symlink
// TODO create_directory_symlink


/**
    Returns the absolute path of the current working directory.

    Warning: this isn't thread-safe, as any other thread
    could modify this process' current directory.

    May throw `FileSystemIOException` if an error occurs.
*/
Path currentPath() /* pure */
{

    version(Windows)
    {
        DWORD len = GetCurrentDirectoryW(0, null);
        if (len == 0) 
            throwIO(kStrErrCurrentPath);
        wchar[] buf;
        buf.nu_resize(len + 1);
        scope(exit) buf.nu_resize(0);
        len = GetCurrentDirectoryW(len + 1, buf.ptr);
        if (len == 0)
            throwIO(kStrErrCurrentPath);
        return Path(toUTF8(nwstring(buf[0..len])));
    }
    else
    {
        char[PATH_MAX] name;
        if (getcwd(name.ptr, name.length) == null) 
            throwIO(kStrErrCurrentPath);
        return Path(nstring(name[0..fs_strlen(name.ptr)]));
    }
}


/**
    Returns: A shallow directory range to iterate over the files in
    this directory.

    Warning: this DirectoryRange should be free after iteration with
    `dirEntriesFree()`.
*/
unique_ptr!DirectoryRange dirEntries(Path p, DirectoryOptions opts = DirectoryOptions.none)
{
    return unique_new!DirectoryRange(p, opts);
}

/**
    Returns: A recursive directory range to iterate over the files in
    this directory, and its sub-directories.
*/
unique_ptr!RecursiveDirectoryRange dirEntriesRecursive(Path p, DirectoryOptions opts = DirectoryOptions.none)
{
    return unique_new!RecursiveDirectoryRange(p, opts);
}


/**
    Checks if the given file status or path corresponds to an existing 
    file or directory. 

    May throw: `InvalidPathException` and `FileSystemIOException`.
*/
bool exists(Path p) // symlinks are followed here
{
    try
    {
        status(p);
        return true;
    }
    catch(FileNotFoundException e)
    {
        e.free();
        return false;
    }
}


/**
    Checks whether the paths `p1` and `p2` resolve to the same file 
    system entity.
    If either `p1` or `p2` does not exist, an error is reported.

    Two paths are considered to resolve to the same file system entity 
    if the two candidate entities the paths resolve to are located on 
    the same device at the same location. For POSIX, this means that 
    the `st_dev` and `st_ino` members of their POSIX `stat` structure, 
    obtained as if by POSIX `stat()`, are equal.

    In particular, all hard links for the same file or directory are 
    equivalent, and a symlink and its target on the same file system 
    are equivalent.

    Returns: `true` if both path exists and are the same thing.

    Throws: InvalidPathException, 
            FileNotFoundException, 
            FileSystemIOException.
*/
bool equivalent(Path p1, Path p2)
{
    version(Windows)
    {
        nwstring wp1 = p1.native.toUTF16();
        nwstring wp2 = p2.native.toUTF16();

        DWORD dwDesiredAccess = 0; // just meta-data
        DWORD dwShareMode     = FILE_SHARE_READ 
                              | FILE_SHARE_WRITE 
                              | FILE_SHARE_DELETE;

        HANDLE h1 = CreateFileW(wp1.ptr, dwDesiredAccess, dwShareMode, 
            null, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, null);

        if (h1 == INVALID_HANDLE_VALUE)
            throwIO(kStrErrMetadataAccess);

        HANDLE h2 = CreateFileW(wp2.ptr, dwDesiredAccess, dwShareMode, 
            null, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, null);

        if (h2 == INVALID_HANDLE_VALUE)
            throwIO(kStrErrMetadataAccess);

        BY_HANDLE_FILE_INFORMATION inf1, inf2;
        if (! GetFileInformationByHandle(h1, &inf1))
            throwIO(kStrErrMetadataAccess);

        if (! GetFileInformationByHandle(h2, &inf2))
            throwIO(kStrErrMetadataAccess);

        return inf1.nFileIndexHigh       == inf2.nFileIndexHigh 
            && inf1.nFileIndexLow        == inf2.nFileIndexLow 
            && inf1.dwVolumeSerialNumber == inf2.dwVolumeSerialNumber;
    }
    else
    {
        stat_t buf1, buf2;
        bool followSymlinks = true;
        posix_stat(p1, &buf1, followSymlinks);
        posix_stat(p2, &buf2, followSymlinks);
        return s1.st_dev == s2.st_dev && s1.st_ino == s2.st_ino;
    }
}



/**
    For a regular file `p`, returns the size determined as if by 
    reading the `st_size` member of the structure obtained by POSIX 
    `stat` (symlinks are followed).

    The result of attempting to determine the size of a directory is 
    implementation-defined.

    Throws: `FileNotFoundException`, `FileSystemIOException`, `InvalidPathException`.
*/
long fileSize(Path p)
{
    return status(p).sizeBytes;
}

// TODO hard_link_count


/**
    Returns the time of the last modification of p, determined as 
    if by accessing the member st_mtime of the POSIX `stat`
    (symlinks are followed).

    For directories, this returns the time when the directory's 
    contents were last modified?specifically when files were created, 
    renamed, or deleted inside that folder.
*/
FileTime lastWriteTime(Path p)
{
    return status(p).lastWriteTime;
}


/**
    Changes access permissions of the file to which p resolves, as if by POSIX `fchmodat`. 

    Symlinks are followed unless `PermOptions.nofollow` is set in opts.
*/
void permissions(Path p, FilePerms prms, PermOptions opts = PermOptions.replace)
{
    FileStatus fs = symlinkStatus(p);

    switch (opts & 3)
    {
        case PermOptions.replace:
            break;
        case PermOptions.add:
            prms = fs.permissions | prms;
            break;
        case PermOptions.remove:
            prms = fs.permissions & ~prms;
            break;
        case 3:
        default:
            assert(0);

        version(Windows)
        {
            nwstring wpath = p.native.toUTF16();
            DWORD oldAttr = GetFileAttributesW(wpath.ptr);
            if (oldAttr == INVALID_FILE_ATTRIBUTES)
                throwIO(kStrFileAttributes);

            DWORD newAttr;
            bool readOnly = (prms & FilePerms.ownerWrite) == 0;
            if (readOnly)
                newAttr = oldAttr & ~cast(DWORD)FILE_ATTRIBUTE_READONLY;
            else
                newAttr = oldAttr | cast(DWORD)FILE_ATTRIBUTE_READONLY;

            if (oldAttr == newAttr)
                return;

            if (SetFileAttributesW(wpath.ptr, newAttr) == 0)
                throwIO(kStrErrChmodFailed);
        }
        else version(Posix)
        {
            bool noFollow = (opts & FilePerms.nofollow) != 0;

            if (! noFollow)
            {
                if (.chmod(p.native.ptr, cast(mode_t)prms) != 0) 
                    throwIO(kStrErrChmodFailed);
            }
        }
        else
            static assert(0);
    }
}

// TODO read_symlink


/**
    The file or **empty** directory identified by the path p is deleted as
    if by the POSIX `remove`. Symlinks are not followed (symlink is 
    removed, not its target).

    Returns: true if remove, false if doesn't exist.

    Throws:
        FileSystemIOException on I/O error.
        InvalidPathException on invalid path.
*/
bool remove(Path p)
{
    version(Windows)
    {
        nwstring path = p.native.toUTF16();
        DWORD attr = GetFileAttributesW(path.ptr);
        if (attr == INVALID_FILE_ATTRIBUTES)
        {
            if (windowsErrIsFileNotFound(GetLastError()))
                return false;
            else
                throwIO(kStrErrRemoveFileDir);
        }

        // Like in Steffen's implementation (and unlike Phobos), 
        // we try to remove a read-only attribute if there. 
        // There is actually a deep issue lore about this:
        // https://github.com/gulrak/filesystem/issues/121/
        if (attr & FILE_ATTRIBUTE_READONLY)
        {
            // RACE: if another process removes the dir, it 
            // could well be "not found" instead of I/O err
            DWORD newAttr = attr & ~FILE_ATTRIBUTE_READONLY;
            if (! SetFileAttributesW(path.ptr, newAttr))
                throwIO(kStrErrRemoveFileDir);
        }

        if (attr & FILE_ATTRIBUTE_DIRECTORY) 
        {
            // RACE: if another process removes the dir, it 
            // could well be "not found" instead of I/O err
            if (!RemoveDirectoryW(path.ptr))
                throwIO(kStrErrRemoveFileDir);
        }
        else 
        {
            // RACE: if another process removes the dir, it 
            // could well be "not found" instead of I/O err
            if (!DeleteFileW(path.ptr))
                throwIO(kStrErrRemoveFileDir);
        }
        return true;
    }
    else version(Posix)
    {
        // Warning: using libc here
        if (cstdio.remove(p.native().ptr) != 0)
        {
            int error = errno;
            if (error == ENOENT)
                return false;
            else
                throwIO(kStrErrRemoveFileDir);
            return false;
        }
        else
            return true;
    }
    else
        static assert(0);
}


/**
    Deletes the contents of p (if it is a directory) and the contents
    of all its subdirectories, recursively, then deletes `p` itself as 
    if by repeatedly applying the POSIX `remove()`. Symlinks are not 
    followed (symlink is removed, not its target).

    Returns: the number of files and directories that were deleted 
    (which may be zero if p did not exist to begin with).

    BUG: symlinks not implemented.
*/
int removeAll(Path p)
{
    // TODO be sure we do not follow symlinks in case you end up deleting 
    // the whole world.
    int r = 0;

    DirectoryOptions opts = DirectoryOptions.spanDepthFirst;
    foreach(dirEntry; dirEntriesRecursive(p, opts))
        if (remove(dirEntry.path))
            r += 1;

    if (remove(p))
        r += 1;
    return r;
}


/**
    Rename file or directory from `oldPath` to `newPath`, as if by 
    POSIX `rename()`.

    - It is possible to rename a non-empty directory.
    - It is not possible to rename a file across different mount 
      points or drives.

    If `newpath` already exists, it will be atomically replaced, so 
    that there is no point at which another **process** attempting to 
    access newpath will find it missing.  However, there will probably 
    be a window in which both oldpath and newpath refer to the file 
    being renamed.

    Symbolic links are NOT followed, this will rename/delete symlinks
    themselves.

    Returns: true on success.

    Throws:
        FileSystemIOException on I/O error or if `oldPath` doesn't exist.
        InvalidPathException on invalid path.    
*/
bool rename(Path oldPath, Path newPath)
{
    // Note: in https://github.com/gulrak/filesystem/,
    // path are compared and if identical nothing happens.
    // But I believe this is wrong if not compared normalized.

    version(Windows)
    {
        // BUG: MoveFileExW is not actually atomic
        // https://github.com/untitaker/rust-atomicwrites/issues/27
        nwstring wold = oldPath.native.toUTF16();
        nwstring wnew = newPath.native.toUTF16();
        DWORD flags = MOVEFILE_REPLACE_EXISTING;
        if (0 == MoveFileExW(wold.ptr, wnew.ptr, flags))
            throwIO(kStrErrRenameFileDir);
        return true;
    }
    else version(Posix)
    {
        if (cstdio.rename(oldPath.native.ptr, newPath.native.ptr) != 0)
            throwIO(kStrErrRenameFileDir);
        return true;
    }
}


// TODO resize_file
// TODO space
// TODO temp_directory_path


/**
    Determines the type and attributes of the filesystem object 
    identified by `path` as if by POSIX `lstat` (symlinks are 
    NOT followed to their targets).

    Can throw:
    - `FileNotFoundException`  => equivalent to C++'s file_type::not_found
    - `InvalidPathException`   => equivalent to C++'s file_type::none
    - `FileSystemIOException`  => equivalent to C++'s file_type::none
*/
FileStatus status(Path path)
{
    version(Windows)
    {
        return symlinkStatus(path);
        // TODO: this is wrong, need to detect symlink there.
        // See std::filesystem implementations.
    }
    else
    {
        return posix_statusFromPath(path, true);
    }
}


/**
    Determines the type and attributes of the filesystem object 
    identified by `path` as if by POSIX `lstat` (symlinks are 
    NOT followed to their targets).

    Can throw:
    - `FileNotFoundException`  => equivalent to C++'s file_type::not_found
    - `InvalidPathException`   => equivalent to C++'s file_type::none
    - `FileSystemIOException`  => equivalent to C++'s file_type::none
*/
FileStatus symlinkStatus(Path path)
{
    version(Windows)
    {
        FileStatus r;
        nwstring ws = path.native.toUTF16();
        WIN32_FILE_ATTRIBUTE_DATA info;
        int res = GetFileAttributesExW(cast(wchar*) ws.ptr, GET_FILEEX_INFO_LEVELS.GetFileExInfoStandard, &info);
        if (res == 0)
        {
            DWORD err = GetLastError();
            r.permissions = FilePerms.none;
            if (windowsErrIsFileNotFound(err))
                throwFileNotFound(path);
            else
                throwIO(kStrFileAttributes);
        }
        else
        {
            r.setTimeFromFILETIME(info.ftLastWriteTime);            

            // FUTURE: support NTFS symbolic links
            if (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
            {
                r.type = FileType.directory;
                r.sizeBytes = 0;                
            }
            else
            {
                r.type = FileType.regular;

                ulong size = cast(long)(info.nFileSizeHigh) << 32;
                size |= info.nFileSizeLow;

                // Excessive size, should fit in a long.
                if (size > MAXIMUM_FILE_SIZE)
                    throwException(kStrInvalidFileSize);

                r.sizeBytes = cast(long)size;
            }
        }
        return r;
    }
    else version(Posix)
    {
        return posix_statusFromPath(path, false);
    }
    else 
        static assert(0);
}


/**
    Checks if the given file status or path corresponds to a block 
    special file, as if determined by the POSIX `S_ISBLK`. Examples of 
    block special files are block devices such as `/dev/sda` or 
    `/dev/loop0` on Linux.

    May throw: `FileNotFoundException`, `FileSystemIOException`, `InvalidPathException`.
*/
bool isBlockFile(FileStatus s) pure nothrow
    => s.type == FileType.block;
///ditto
bool isBlockFile(Path p) // symlinks are followed here
    => isBlockFile(status(p));


/**
    Checks if the given file status or path corresponds to a character
    special file, as if determined by POSIX `S_ISCHR`. Examples of 
    character special files are character devices such as `/dev/null`, 
    `/dev/tty`, `/dev/audio`, or `/dev/nvram` on Linux.

    May throw: `FileNotFoundException`, `FileSystemIOException`, `InvalidPathException`.
*/
bool isCharacterFile(FileStatus s) pure nothrow
    => s.type == FileType.character;
///ditto
bool isCharacterFile(Path p) // symlinks are followed here
    => isCharacterFile(status(p));


/**
    Checks if the given file status or path corresponds to a 
    directory.

    May throw: `FileNotFoundException`, `FileSystemIOException`, `InvalidPathException`.
*/
bool isDirectory(FileStatus s) pure nothrow
    => s.type == FileType.directory;
///ditto
bool isDirectory(Path p) // symlinks are followed here
    => isDirectory(status(p));


// TODO is_empty checks whether the given path refers to an empty file or directory


/**
    Checks if the given file status or path corresponds to a FIFO or 
    pipe file as if determined by POSIX `S_ISFIFO`. 

    May throw: `FileNotFoundException`, `FileSystemIOException`, `InvalidPathException`.
*/
bool isFIFO(FileStatus s) pure nothrow
    => s.type == FileType.fifo;
///ditto
bool isFIFO(Path p) // symlinks are followed here
    => isFIFO(status(p));


/**
    Checks if the given file status or path corresponds to a file of 
    type "other" type. That is, the file exists, but is:
    - neither regular file, 
    - nor directory 
    - nor a symlink.

    May throw: `FileNotFoundException`, `FileSystemIOException`, `InvalidPathException`.
*/
bool isOther(FileStatus s) pure
    => !isRegularFile(s) && !isDirectory(s) && !isSymlink(s);
///ditto
bool isOther(Path p) // symlinks are followed here
    => isOther(status(p));


/**
    Checks if the given file status or path corresponds to a regular 
    file.

    May throw: `FileNotFoundException`, `FileSystemIOException`, `InvalidPathException`.
*/
bool isRegularFile(FileStatus s) pure nothrow
    => s.type == FileType.regular;
///ditto
bool isRegularFile(Path p) // symlinks are followed here
    => isRegularFile(status(p));


/**
    Checks if the given file status or path corresponds to a named IPC 
    socket, as if determined by the POSIX `S_IFSOCK`.

    May throw: `FileNotFoundException`, `FileSystemIOException`, `InvalidPathException`.
*/
bool isSocket(FileStatus s) pure nothrow
    => s.type == FileType.socket;
///ditto
bool isSocket(Path p) // symlinks are followed here
    => isSocket(status(p));


/**
    Checks if the given file status or path corresponds to a symbolic 
    link, as if determined by the POSIX `S_IFLNK`.

    This function is the only of its kind that doesn't follow 
    symlinks, for obvious reasons.

    May throw: `FileNotFoundException`, `FileSystemIOException`, `InvalidPathException`.
*/
bool isSymlink(FileStatus s) pure nothrow
    => s.type == FileType.socket;
///ditto
bool isSymlink(Path p)
{
    // symlinks are NOT followed here
    // unlik the other isXXX functions.
    return isSymlink(symlinkStatus(p));
}


// Not public:
//
// - bool statusKnown(FileStatus s) pure nothrow;
//
//   The problem with this API is it's not intuitive at
//   all, it returns true if the file status was queried
//   and the OS called didn't fail, which means the file
//   may not exist, or have a type we don't recognize.
//   Specifically the "unknown" file type still yield
//   true for statusKnown in std::filesystem.
//   So perhaps best to leave this function out, it's too
//   easy to misunderstand it.



private:


/*
    Version that return even if the file doesn't exist.
    Can still throw on I/O and invalid path.

    Returns: FileStatus.init if the file doesn't exists.
*/
FileStatus statusExists(Path p, out bool exists)
{
    FileStatus st;
    try
    {
        st = status(p);
        exists = true;
    }
    catch(FileNotFoundException e)
    {
        e.free();
        exists = false;
        st = FileStatus.init;
    }
    return st;
}


