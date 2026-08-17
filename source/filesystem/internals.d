/**
    Public API, import this to start using filesystem.

    Copyright: Guillaume Piolat 2026.
    License: MIT (https://mit-license.org/)
*/
module filesystem.internals;

import numem;
import nulib;
import nulib.text.unicode;
import filesystem.types;

version(Windows)
{
    import core.sys.windows.windef;
    import core.sys.windows.winbase;
    import core.sys.windows.winuser;
    pragma(lib, "user32");
}
else version(Posix)
{
    import core.sys.posix.stdlib;
    import cstdlib = core.stdc.stdlib;
}

@nogc:

/**
    Above that size, we consider the file can't possibly
    by that big. That's nearly 8191 petabytes.
*/
enum ulong MAXIMUM_FILE_SIZE = long.max;

// Pool of error messages, to save a bit of codegen.
static immutable string 
    kStrFileNotFound       = "File not found: `",
    kStrInvalidPath        = "Invalid path",
    kStrFileAttributes     = "Can't get file attributes",
    kStrInvalidFileSize    = "Invalid file size",
    kStrDeepFuture         = "You've reached the deep future",
    kStrErrCreateDirectory = "Can't create directory",    
    kStrErrCreateDirFile   = "Can't create directory because a file with the same name exists",
    kStrErrRemoveFileDir   = "Can't remove file or directory",
    kStrErrRenameFileDir   = "Can't rename file or directory",
    kStrErrCopyFileNonReg  = "copyFile source is not a regular files",
    kStrErrCopyDestNonReg  = "copyFile destination is not a regular file",
    kStrErrCopyDestExists  = "copyFile destination already exists",
    kStrErrFileCopyFailed  = "File copy failed",
    kStrErrOpenFileFailed  = "Can't open file",
    kStrErrFileReadFailed  = "File read failed",
    kStrErrFileWriteFailed = "File write failed",
    kStrErrChmodFailed     = "File chmod failed",
    kStrErrInvalidArg      = "Invalid argument",
    kStrErrCurrentPath     = "Can't get current path",
    kStrErrCopySameFile    = "Source and destination are the same",
    kStrErrMetadataAccess  = "Can't access file metadata",
    kStrPathIsEmptyNoAbs   = "Cannot make absolute path from empty",
    kStrErrFileSearch      = "File search failed";


// Future: decide if we keep this file

void throwException(const(char)[] msg)
{
    throw nogc_new!FileSystemException(msg);
}

void throwFileNotFound(const(char)[] path)
{
    throw nogc_new!FileNotFoundException(path);
}

void throwInvalidPath(const(char)[] path)
{
    // FUTURE: build proper exc message
    throw nogc_new!InvalidPathException(kStrInvalidPath);
}

void throwIO(const(char)[] msg)
{
    throw nogc_new!FileSystemIOException(msg);
}

// Note: technically getenv and setenv do not belong
// to the filesystem library, but well.

/// Get environment variable.
nstring getEnvironmentVariable(nstring name)
{
    version(Posix)
    {
        const(char)* p = getenv(name.ptr);
        if (p)
            return nstring(p[0..nu_strlen(p)]);
        else
            return nstring.init;
    }
    else version(Windows)
    {
        nwstring name16 = toUTF16(name);
        enum int BUFSIZE = 16;
        wchar[BUFSIZE] buf;
        DWORD res = GetEnvironmentVariableW(name16.ptr, buf.ptr, BUFSIZE);
        if (res == 0)
            return nstring.init;
        else if (res <= BUFSIZE)
            return toUTF8(nwstring(buf[0..res]));
        else
        {
            wchar[] buf2;
            buf2.nu_resize(res + 1);
            scope(exit) buf2.nu_resize(0);
            res = GetEnvironmentVariableW(name16.ptr, buf2.ptr, res + 1);
            return toUTF8(nwstring(buf2[0..res]));
        }
    }
    else
        static assert(0);
}

/// Set environment variable.
/// Returns: true if successful.
// FUTURE: unset variable if value == ""
bool setEnvironmentVariable(nstring name, nstring value)
{
    version(Posix)
    {
        int overwrite = 1;
        int r = setenv(name.ptr, value.ptr, overwrite);
        return r == 0;
    }
    else version(Windows)
    {
        nwstring name16 = toUTF16(name);
        nwstring value16 = toUTF16(value);
        return SetEnvironmentVariableW(name16.ptr, value16.ptr) != 0;
    }
    else
        static assert(0);
}

size_t fs_strlen(const(char)* str) pure
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



// Returns: true if path a == path b.
// On Windows, compare with case-insensitive casing.
// Reference: https://web.archive.org/web/20130528052217/http://blogs.msdn.com:80/b/michkap/archive/2005/10/17/481600.aspx
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

    bool isWindowsSymlink(ref WIN32_FILE_ATTRIBUTE_DATA info) pure nothrow
    {
        if (info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)
        {
            // TODO support for Windows symlink requires much more additional work.
            // See std::filesystem implementations.
            return false;
        }
        else
            return false;
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
    //
    // Reference: https://stackoverflow.com/questions/6161776/convert-windows-filetime-to-second-in-unix-linux
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
    //  Throws: InvalidPathException, FileNotFoundException, FileSystemIOException
    void posix_stat(Path p, stat_t* buf, bool followIfSymlink)
    {
        FileStatus r;
        nstring s = p.native();

        int res;
        if (followIfSymlink)
            res = stat(s.ptr, buf);
        else
            res = lstat(s.ptr, buf);

        if (res != 0)
        {
            r.perms = FilePerms.none;
            int err = errno;
            if (errno == ENOENT)
                throwFileNotFound(p);
            else
                throwIO(kStrFileAttributes);
        }
    }

    //  Throws: InvalidPathException, FileNotFoundException, FileSystemIOException.
    FileStatus posix_statusFromPath(Path p, bool followIfSymlink)
    {
        stat_t buf;
        posix_stat(p, &buf, followIfSymlink);
        return statusFromPosixStat(buf);
    }

    // Throws: FileSystemIOException.
    FileStatus statusFromPosixStat(ref stat_t buf)
    {
        FileStatus r;
        r.perms = cast(FilePerms) (buf.st_mode & FilePerms.mask);
        switch(buf.st_mode & S_IFMT)
        {
            case S_IFREG:  r.type = FileType.regular; break;
            case S_IFDIR:  r.type = FileType.directory; break;
            case S_IFLNK:  r.type = FileType.symlink; break;
            case S_IFBLK:  r.type = FileType.block; break;
            case S_IFCHR:  r.type = FileType.character; break;
            case S_IFIFO:  r.type = FileType.fifo; break;
            case S_IFSOCK: r.type = FileType.socket; break;
            default:
                r.type = FileType.unknown;
        }

        if (buf.st_size < 0)
            throwIO(kStrInvalidFileSize);

        r.sizeBytes = buf.st_size;
        r.lastWriteTime = buf.st_mtime;
        return r;
    }
}

