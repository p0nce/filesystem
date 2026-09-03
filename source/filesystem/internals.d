/**
    Stuff internal to `filesystem` package.

    Copyright: Guillaume Piolat 2026.
    License: MIT (https://mit-license.org/)
*/
module filesystem.internals;

import numem;
import nulib;
import nulib.text.unicode;
import nulib.io.stream.file;
import nulib.io.stream;
import nulib.memory;

import filesystem.types;
import filesystem.path;
import filesystem.freefunc;


version(Windows)
{
    import core.sys.windows.windef;
    import core.sys.windows.winbase;
    import core.sys.windows.winuser;
    import core.sys.windows.winioctl;
    pragma(lib, "user32");
}
else version(Posix)
{
    import punistd  = core.sys.posix.unistd;
    import pstat   = core.sys.posix.sys.stat;
    import cerrno  = core.stdc.errno;
    import cstdlib = core.stdc.stdlib;
}


@nogc:

// the `isFreeDesktop` constant
version(OSX) {
    enum isFreedesktop = false;
} else version(Android) {
    enum isFreedesktop = false;
} else version(linux) {
    enum isFreedesktop = true;
} else version(FreeBSD) {
    enum isFreedesktop = true;
} else version(OpenBSD) {
    enum isFreedesktop = true;
} else version(NetBSD) {
    enum isFreedesktop = true;
} else version(DragonFlyBSD) {
    enum isFreedesktop = true;
} else version(BSD) {
    enum isFreedesktop = true;
} else version(Hurd) {
    enum isFreedesktop = true;
} else version(Solaris) {
    enum isFreedesktop = true;
} else {
    enum isFreedesktop = false;
}

/**
    Above that size, we consider the file can't possibly
    by that big. That's nearly 8191 petabytes.
*/
enum ulong MAXIMUM_FILE_SIZE = long.max;

// Pool of error messages, to save a bit of codegen.
static immutable string 
    kStrFileNotFound       = "File not found: `",
    kStrInvalidPath        = "Invalid path: `",
    kStrFileAttributes     = "Can't get file attributes",
    kStrFileFullPath       = "Can't get file full path",
    kStrInvalidFileSize    = "Invalid file size",
    kStrDeepFuture         = "You've reached the deep future",
    kStrErrCreateDirectory = "Can't create directory",    
    kStrErrRemoveFileDir   = "Can't remove file or directory",
    kStrErrRenameFileDir   = "Can't rename file or directory",
    kStrErrCopyFileNonReg  = "File copy source is not a regular file",
    kStrErrCopyDestNonReg  = "File copy target is not a regular file",
    kStrErrCopyDestExists  = "File copy target already exists",
    kStrErrFileCopyFailed  = "File copy failed",
    kStrErrOpenFileFailed  = "Can't open file",
    kStrErrFileReadFailed  = "File read failed",
    kStrErrFileResizeFail  = "File resize failed",
    kStrErrFileWriteFailed = "File write failed",
    kStrErrChmodFailed     = "File chmod failed",
    kStrErrInvalidArg      = "Invalid argument",
    kStrErrCurrentPath     = "Can't get current path",
    kStrErrTempPath        = "Can't get temp path",
    kStrErrCopySameFile    = "Source and target are the same",
    kStrErrMetadataAccess  = "Can't access file metadata",
    kStrPathIsEmptyNoAbs   = "Cannot make absolute path from empty",
    kStrErrFileSearch      = "File search failed",
    kStrErrFSAvailInfo     = "Can't get disc usage",
    kStrErrChdirFailed     = "Can't change current directory",
    kStrErrUnrealDiscSize  = "Disc reports too large a size",
    kStrErrNotSymlink      = "File is not a symlink",
    kStrErrSymlinkRead     = "Can't read symlink",
    kStrErrSymlinkCreate   = "Can't create symlink",
    kStrErrCopyOther       = "Cannot copy this type of file.",
    kStrErrNoCanonical     = "Path can't be made canonical";

noreturn throwException(const(char)[] msg)
{
    throw nogc_new!FileSystemException(msg);
}

noreturn throwFileNotFound(const(char)[] path)
{
    throw nogc_new!FileNotFoundException(path);
}

noreturn throwInvalidPath(const(char)[] path)
{
    throw nogc_new!InvalidPathException(path);
}

noreturn throwIO(const(char)[] msg)
{
    // simply throw the same exception
    throw nogc_new!FileSystemException(msg);
}

size_t fs_strlen(const(char)* str) pure
{
    assert(str !is null);
    size_t len = 0;
    while (str[len] != '\0')
        len++;

    return len;
}

size_t fs_wstrlen(const(wchar)* str) pure
{
    assert(str !is null);
    size_t len = 0;
    while (str[len] != '\0')
        len++;

    return len;
}

int fs_strcmp( const(char)* lhs, const(char)* rhs ) pure @system
{
    while(true)
    {
        char left = *lhs++;
        char right = *rhs++;
        if (left < right)
            return -1;
        else if (left > right)
            return 1;
        if (left == 0)
            break;
    }
    return 0;
}

int fs_wcscmp( const(wchar)* lhs, const(wchar)* rhs ) pure @system
{
    while(true)
    {
        wchar left = *lhs++;
        wchar right = *rhs++;
        if (left < right)
            return -1;
        else if (left > right)
            return 1;
        if (left == 0)
            break;
    }
    return 0;
}

const(char)[] fs_strip(return const(char)[] s) pure nothrow @safe 
{
    const(char)[] r = s;
    while (r.length > 0 && fs_isspace(r[0])) r = r[1..$];
    while (r.length > 0 && fs_isspace(r[$-1])) r = r[0..$-1];
    return r;
}

int fs_isspace(char ch) pure nothrow @safe 
{
    switch (ch)
    {
    case ' ':
    case '\t':
    case '\n':
    case '\v':
    case '\f':
    case '\r':
        return true;

    default:
        return false;
    }
}


// Return same string with one char replaced
nstring fs_replaceChar(const(char)[] s, char needle, char replacement) 
    pure nothrow
{
    if (s is null)
        return nstring();

    if (needle == replacement)
        return nstring(s);

    char[] r;
    r.nu_resize(s.length);
    scope(exit) r.nu_resize(0);

    foreach(i; 0..s.length)
        if (s[i] == needle)
            r[i] = replacement;
        else
            r[i] = s[i];

    return nstring(r);
}
nstring fs_replaceCharStr(string s, char needle, char replacement) 
    pure nothrow
{
    if (s is null)
        return nstring();
    return fs_replaceChar(s.ptr[0..s.length], needle, replacement);
}

nwstring toUTF16OrCrash(nstring s) nothrow
{
    try
    {
        return toUTF16(s);
    }
    catch(NuException e)
    {
        e.freeNoThrow();
    }
    catch(Exception e)
    {   
    }
    assert(0);
}

nstring toUTF8OrEmpty(nwstring s) nothrow
{
    try
    {
        return toUTF8(s);
    }
    catch(NuException e)
    {
        e.freeNoThrow();
    }
    catch(Exception e)
    {
    }
    return nstring.init;
}

// Returns: true if path a == path b.
// On Windows, compare with case-insensitive casing.
bool equalsWithOSCaseSensitivity(nstring a, nstring b)
{
    version(Windows)
    {
        // PERF: that's 4 allocations...

        nwstring wa = a.toUTF16();
        nwstring wb = b.toUTF16();

        uint la = cast(uint) wa.length;
        uint lb = cast(uint) wb.length;

        wchar[] bufA, bufB;
        bufA.nu_resize(la);
        bufB.nu_resize(lb);
        
        for (size_t n = 0; n < la; ++n)
            bufA[n] = wa[n];

        for (size_t n = 0; n < lb; ++n)
            bufB[n] = wb[n];

        // Convert to upper case
        // "The function examines the number of characters indicated 
        //  by cchLength, even if one or more characters are null 
        // characters."
        // Though to be fair, we wouldn't be here on invalid Unicode.
        DWORD resA = CharUpperBuffW(bufA.ptr, la);
        assert(resA == la);

        DWORD resB = CharUpperBuffW(bufB.ptr, lb);
        assert(resB == lb);

        bool equal = bufA[] == bufB[];

        bufA.nu_resize(0);
        bufB.nu_resize(0);

        return equal;
    }
    else version(Posix)
    {
        return a == b;
    }
}
 

version(Windows)
{
    bool windowsErrIsFileNotFound(DWORD err) pure nothrow
    {
        return (err == ERROR_FILE_NOT_FOUND
                || err == ERROR_PATH_NOT_FOUND
                || err == ERROR_INVALID_DRIVE);
    }

    void setFileSizeAndType(ref FileStatus r,
                            DWORD dwFileAttributes,
                            DWORD nFileSizeHigh,
                            DWORD nFileSizeLow)
    {
        if (dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
        {
            r.type = FileType.directory;
            r.sizeBytes = 0;
        }
        else
        {
            r.type = FileType.regular;

            ulong size = cast(long)(nFileSizeHigh) << 32;
            size |= nFileSizeLow;

            // Excessive size, should fit in a long.
            if (size > MAXIMUM_FILE_SIZE)
                throwException(kStrInvalidFileSize);

            r.sizeBytes = cast(long)size;
        }
    }

    void setTimeFromFILETIME(ref FileStatus r, FILETIME time)
    {
        // Extract time of last write.
        ulong timeWin = cast(long)(time.dwHighDateTime) << 32;
        timeWin |= time.dwLowDateTime;

        // Excessive size, should fit in a long.
        if (timeWin > long.max)
            throwException(kStrDeepFuture);
        r.lastWriteTime = windowsTickToUnixSeconds(timeWin);
    }

    // A Windows FILETIME contains a 64-bit value representing the 
    // number of 100-nanosecond intervals since January 1, 1601 (UTC).
    // Note: it's safe to represent as signed, long lead us to 30848 
    // A.D for an issue with 64-bit overflow.
    //
    // The Unix epoch (also called Unix time, POSIX time, or a Unix
    // timestamp) is the number of seconds since January 1, 1970,
    // 00:00:00 UTC, not counting leap seconds (ISO 8601:
    // 1970-01-01T00:00:00Z). Again, no issue with 64-bit overflow.
    long windowsTickToUnixSeconds(long winTicks) pure
    {
        // 1e7, because there 1e9 nanoseconds in second
        enum long WINDOWS_TICK      = 10000000;
        enum long SEC_TO_UNIX_EPOCH = 11644473600L;
        return winTicks / WINDOWS_TICK - SEC_TO_UNIX_EPOCH;
    }
}

version(Posix)
{
    //  Throws: `FileSystemException`, `FileNotFoundException`
    void posix_stat(Path p, pstat.stat_t* buf, bool followIfSymlink)
    {
        FileStatus r;
        nstring s = p.native();

        int res;
        if (followIfSymlink)
            res = pstat.stat(s.ptr, buf);
        else
            res = pstat.lstat(s.ptr, buf);

        if (res != 0)
        {
            r.permissions = FilePerms.none;
            if (cerrno.errno == cerrno.ENOENT)
                throwFileNotFound(p);
            else
                throwIO(kStrFileAttributes);
        }
    }

    //  Throws: `FileSystemException`, `FileNotFoundException`.
    FileStatus posix_statusFromPath(Path p, bool followIfSymlink)
    {
        pstat.stat_t buf;
        posix_stat(p, &buf, followIfSymlink);
        return statusFromPosixStat(buf);
    }

    // Throws: `FileSystemException`.
    FileStatus statusFromPosixStat(ref pstat.stat_t buf)
    {
        FileStatus r;
        r.permissions = cast(FilePerms)(buf.st_mode & FilePerms.mask);
        switch(buf.st_mode & pstat.S_IFMT)
        {
            case pstat.S_IFREG:  r.type = FileType.regular; break;
            case pstat.S_IFDIR:  r.type = FileType.directory; break;
            case pstat.S_IFLNK:  r.type = FileType.symlink; break;
            case pstat.S_IFBLK:  r.type = FileType.block; break;
            case pstat.S_IFCHR:  r.type = FileType.character; break;
            case pstat.S_IFIFO:  r.type = FileType.fifo; break;
            case pstat.S_IFSOCK: r.type = FileType.socket; break;
            default:
                r.type = FileType.unknown;
        }

        if (buf.st_size < 0)
            throwIO(kStrInvalidFileSize);

        r.sizeBytes = buf.st_size;
        static long getMtime(ref pstat.stat_t buf)
        {
            return buf.st_mtime;
        }
        long mtime = assumeNoGC(&getMtime, buf);
        r.lastWriteTime = mtime;
        return r;
    }
}

// Create a directory, return its path if successfully created, or
// Path.init in case of error.
// This is used for user XDG paths such as "./local/share", so
// the rights need to be restricted.
Path createIfNeeded(Path path, bool shouldCreate) nothrow @trusted
{
    if (! path.empty() && shouldCreate)
    {
        // On POSIX, this will create the directory with 0700 perms
        // Note: if creating .local, will create as 0700 not 0755
        //       which can be a tiny bit unlike what distros do, but
        //       I don't see how this could hurt.
        if (ensureExists(path, FilePerms.ownerAll))
            return path;
        else
            return Path.init;
    }
    else
        return path;
}

// Returns true if path `dir` exists after this function, false if an
// error occured.
bool ensureExists(Path dir, FilePerms perms) nothrow
{
    bool ok;
    try 
    {
        createDirectories(dir, Path.init, perms);
        return true;
    } 
    catch(NuException e)
    {
        e.freeNoThrow();
        return false;
    }
    catch(Exception e)
    {
        return false;
    }
    return ok;
}

// Input range that pulls from a file stream to give lines.
// This one deletes the line endings.
// It doesn't follow an input range interface!
struct LineSplitter
{
@nogc:
private:
    enum State
    {
        regular,
        seenCR  // last char was \r
    }

    Stream stream;
    vector!char buf;
    State state;
    bool seenEOF;

public:

    @disable this(this);
    @disable this(ref LineSplitter);

    // take ownership of the stream, use move
    this(weak_ptr!FileStream stream)
    {
        this.stream = stream;
        assert(stream.canRead());
        state = State.regular;
        seenEOF = false;
    }

    // Give next lines and `null` if terminated/error.
    // returned buffer is owned by the LineSplitter.
    // Note: line endings can be: "\n", "\r\n" or "\r"
    bool nextLine(out const(char)[] outLine)
    {
        if (seenEOF)
        {
            outLine = null;
            return false;
        }

        buf.resize(0);
        int lineLen = 0;
        while (true)
        {
            char ch;
            if (next(ch))
            {
                bool isLF = ch == '\n';
                bool isCR = ch == '\r';

                if (isLF)
                    break; // Seen \n or \r\n, line is complete
                else if (isCR)
                {
                    if (state == State.regular)
                        state = State.seenCR;
                    else if (state == State.seenCR)
                        break; // Seen "\r\r", line is complete
                }
                else
                {
                    if (state == State.seenCR)
                    {
                        // Seen a stray \r, remove one char of 
                        // lookahead, line is complete
                        undo();
                        state = State.regular;
                        break;
                    }
                    else
                    {
                        lineLen++;
                        buf ~= ch;
                    }
                }
            }
            else
            {
                seenEOF = true; // next time, return null
                break; // EOF
            }
        }
        if (buf.length)
        {
            outLine = buf[0..lineLen];
            return true;
        }
        else
        {
            outLine = null;
            // Note: unclear whether to return this final "" here
            return true; 
        }
    }

    void undo()
    {
        stream.seek(-1, SeekOrigin.relative);
    }

    // true if got a char, false on error or eof
    bool next(out char ch)
    {
        ubyte[1] buf;
        ptrdiff_t r = stream.read(buf);
        if (r <= 0)
            return false;
        ch = buf[0];
        return true;
    }
}

Path getFromUserDirs(const(char)[] xdgdir, Path home, Path confpath)
{
    unique_ptr!FileStream file = fileOpenRead(confpath);
    LineSplitter splitter = LineSplitter(file.borrow());
    const(char)[] line;
    while (splitter.nextLine(line))
    {
        line = fs_strip(line);
        auto index = xdgdir.length;
        if ( line.length > index
             && (line[0..index] == xdgdir) 
             && line[index] == '=') 
        {
            line = line[index+1..$];
            if (line.length > 2 && line[0] == '"' && line[$-1] == '"')
            {
                line = line[1..$-1];

                if (line.startsWith("$HOME/"))
                {
                    return home.maybeAppend(line[6..$]);
                }

                if (line.length == 0 || line[0] != '/') {
                    continue; // skip relative paths
                }
                return Path(line);
            }
        }
    }
    return Path.init;
}

Path getFromDefaultDirs(const(char)[] key, Path home, Path confpath) 
{
    import core.stdc.stdio;
    unique_ptr!FileStream file = fileOpenRead(confpath);
    LineSplitter splitter = LineSplitter(file.borrow());
    const(char)[] line;
    while (splitter.nextLine(line))
    {
        line = fs_strip(line);
        auto index = key.length;
        if ( line.length > index
            && (line[0..index] == key) 
            && line[index] == '=')
        {
            line = line[index+1..$];
            return home / line;
        }
    }
    return Path.init;
}

vector!Path pathsFromEnvValue(const(nstring) envValue, 
                              char separator = ':',
                              nstring subfolder = nstring.init) 
{
    // Note: relative path are filtered out, as per XDG spec:
    // 
    // "All paths set in these environment variables must be absolute. 
    // If an implementation encounters a relative path in any of these 
    // variables it should consider the path invalid and ignore it."

    vector!Path result;
    int lastSep = -1;
    for (int n = 0; n <= cast(int)envValue.length; ++n)
    {
        char ch = (n == envValue.length) ? separator : envValue[n];
        bool issep = (ch == separator);
        if (issep)
        {
            int start = lastSep + 1;
            int stop  = n;
            if (stop > start)
            {
                Path path = Path(envValue[start..stop]);
                path = (path / subfolder).lexicallyNormal;
                if (result.find(path) == -1)
                {
                    // only append to results if absolute
                    if (path.isAbsolute())
                        result ~= path;
                }
            }
            lastSep = n;
        }
    }
    return result;
}

version(Windows)
{
    align(1) struct FS_REPARSE_DATA_BUFFER 
    {
        ULONG  ReparseTag;
        USHORT ReparseDataLength;
        USHORT Reserved;
        union 
        {
            align(1) static struct SymbolicLinkReparseBuffer_t
            {
                USHORT SubstituteNameOffset;
                USHORT SubstituteNameLength;
                USHORT PrintNameOffset;
                USHORT PrintNameLength;
                ULONG  Flags;
                WCHAR[1]  PathBuffer;
            } 

            align(1) static struct MountPointReparseBuffer_t
            {
                USHORT SubstituteNameOffset;
                USHORT SubstituteNameLength;
                USHORT PrintNameOffset;
                USHORT PrintNameLength;
                WCHAR[1]  PathBuffer;
            }

            SymbolicLinkReparseBuffer_t SymbolicLink;
            MountPointReparseBuffer_t MountPoint;
        }
    }
}

Path resolveSymlink(Path p)
{
    version(Windows)
    {
        vector!ubyte vReparse = getReparseData(p);
        auto reparse = cast(FS_REPARSE_DATA_BUFFER*) vReparse.ptr;

        if (reparse is null)
            throwIO(kStrErrSymlinkRead);

        nwstring printName, substName;

        wchar* parseBuf, printPtr, substPtr;
        size_t printOfs, printLen, substOfs, substLen;

        if (reparse.ReparseTag == IO_REPARSE_TAG_MOUNT_POINT)
        {
            parseBuf = reparse.MountPoint.PathBuffer.ptr;
            printOfs = reparse.MountPoint.PrintNameOffset / 2;
            printLen = reparse.MountPoint.PrintNameLength / 2;
            printPtr = &parseBuf[printOfs];
            printName = nwstring(printPtr[0..printLen]);
            substOfs = reparse.MountPoint.SubstituteNameOffset / 2;
            substLen = reparse.MountPoint.SubstituteNameLength / 2;
            substPtr = &parseBuf[substOfs];
            substName = nwstring(substPtr[0..substLen]);
        }
        else if (reparse.ReparseTag == IO_REPARSE_TAG_SYMLINK)
        {
            parseBuf = reparse.SymbolicLink.PathBuffer.ptr;
            printOfs = reparse.SymbolicLink.PrintNameOffset / 2;
            printLen = reparse.SymbolicLink.PrintNameLength / 2;
            printPtr = &parseBuf[printOfs];
            printName = nwstring(printPtr[0..printLen]);
            substOfs = reparse.SymbolicLink.SubstituteNameOffset / 2;
            substLen = reparse.SymbolicLink.SubstituteNameLength / 2;
            substPtr = &parseBuf[substOfs];
            substName = nwstring(substPtr[0..substLen]);
        }
        else
            assert(0);
        Path result;
        // Strip the weird \??\ prefix.
        if (startsWith(substName, nwstring(`\??\`w)))
        {
            substName = substName[4..$];
        }
        result = Path(substName.toUTF8());

        if (reparse.SymbolicLink.Flags & 0x1) // SYMLINK_FLAG_RELATIVE
            result = p.parentPath() / result;

        return result;
    }
    else version(Posix)
    {
        size_t bSz = 256;
        ptrdiff_t bytes;
        while (bSz <= 1024 * 1024) 
        {
            vector!char linkbuf;
            linkbuf.resize(bSz);            
            bytes = punistd.readlink(p.native.ptr, linkbuf.ptr, bSz);
            if (bytes < 0)
                throwIO(kStrErrSymlinkRead);
            else if (bytes < bSz)
            {
                return Path(linkbuf[0..bytes]);
            }
            else
                bSz *= 2;
        }
        return Path.init;
    }
    else
        static assert(0);
}

version(Windows)
{
    // Note: REPARSE_DATA_BUFFER is a C struct terminated by a number 
    // of additional bytes.
    // We return a ubyte buffer to be read as a `REPARSE_DATA_BUFFER`.
    // Throws: `FileSystemException`.
    vector!ubyte getReparseData(Path p)
    {
        DWORD shareFlags = FILE_SHARE_READ 
                         | FILE_SHARE_WRITE 
                         | FILE_SHARE_DELETE;
        DWORD fileFlags  = FILE_FLAG_OPEN_REPARSE_POINT 
                         | FILE_FLAG_BACKUP_SEMANTICS;
        HANDLE file = CreateFileW(p.native.toUTF16().ptr, 0, 
            shareFlags, null, OPEN_EXISTING, fileFlags, null);

        if (!file)
            throwIO(kStrErrSymlinkRead);

        scope(exit) CloseHandle(file);

        vector!ubyte r;
        r.resize(MAXIMUM_REPARSE_DATA_BUFFER_SIZE);
        ULONG bufferUsed;
        if (DeviceIoControl(file, FSCTL_GET_REPARSE_POINT, null, 0, 
            r.ptr, MAXIMUM_REPARSE_DATA_BUFFER_SIZE, &bufferUsed, 
            null)) 
        {
            r.resize(bufferUsed);
            return r;
        }
        else
        {
            r.resize(0);
            throwIO(kStrErrSymlinkRead);
        }
    }
}