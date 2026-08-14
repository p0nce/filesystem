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
}
else version(Posix)
{
    import core.sys.posix.stdlib;
    import cstdlib = core.stdc.stdlib;
}

@nogc:

static immutable string 
    kStrFileNotFound       = "File not found",
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
    kStrErrChmodFailed     = "File chmod failed";


// Future: decide if we keep this file

void throwException(const(char)[] msg)
{
    throw nogc_new!FileSystemException(msg);
}

void throwFileNotFound(const(char)[] path)
{
    // FUTURE: build proper exc message
    throw nogc_new!FileNotFoundException(kStrFileNotFound);
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