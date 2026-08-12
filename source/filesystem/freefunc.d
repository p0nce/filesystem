/**
    Free functions like in `std::filesystem`.

    Non-member functions go here. There is quite a bit of 
    free functions in std::filesystem, see the reference:
    https://en.cppreference.com/cpp/filesystem

    Copyright: Guillaume Piolat 2026.
    License: MIT (https://mit-license.org/)
*/
module filesystem.freefunc;

import nulib;
import nulib.text.unicode;
import numem;

import filesystem.types;
import filesystem.path;
import filesystem.internals;

version(Windows)
{
    import core.sys.windows.stat;
    import core.sys.windows.windef;
    import core.sys.windows.winbase;
}
else version(Posix)
{
    import core.stdc.unistd: getcwd;
    import core.stdc.string: strlen;
    import core.sys.posix.sys.stat;
}


/**
    Returns a path referencing the same file system location as p, 
    for which `Path.isAbsolute()` is true.

    May throw `FilesystemException` if an error occurs.
*/
Path absolute(Path p)
{
    if (p == "")
        throwException(`Cannot make absolute path from empty`);
    return currentPath() / p;
}
///ditto
Path absolute(const(char)[] p)
    => absolute(Path(p));


// TODO canonical
// TODO weakly_canonical
// TODO relative
// TODO proximate
// TODO copy
// TODO copy_file
// TODO copy_symlink
// TODO create_directory
// TODO create_directories
// TODO create_hard_link
// TODO create_symlink
// TODO create_directory_symlink


/**
    Returns the absolute path of the current working directory.

    May throw `FilesystemException` if an error occurs.
*/
Path currentPath() /* pure */
{
    static immutable errmsg = `Can't get current path`;
    version(Windows)
    {
        DWORD len = GetCurrentDirectoryW(0, null);
        if (len == 0) 
            throwException(errmsg);
        wchar[] buf;
        buf.nu_resize(len + 1);
        scope(exit) buf.nu_resize(0);
        len = GetCurrentDirectoryW(len + 1, buf.ptr);
        if (len == 0)
            throwException(errmsg);
        return Path(toUTF8(nwstring(buf[0..len])));
    }
    else
    {
        char[256] name;
        if (getcwd(name.ptr, 256) == null) 
            throwException(errmsg);
        return Path(nstring(name[0..strlen(name.ptr)]));
    }
}


/**
    Checks if the given file status or path corresponds to an existing 
    file or directory. 
*/
bool exists(FileStatus s)
    => statusKnown(s) && s.type != FileType.notFound;
///ditto
bool exists(Path p) // symlinks are followed here
    => exists(status(p));

// TODO equivalent

// TODO fileSize
// TODO hard_link_count
// TODO last_write_time
// TODO permissions
// TODO read_symlink
// TODO remove
// TODO remove_all
// TODO rename
// TODO resize_file
// TODO space
// TODO temp_directory_path


/**
    Determines the type and attributes of the filesystem object 
    identified by `path` as if by POSIX `lstat` (symlinks are 
    NOT followed to their targets).

    If not found or I/O error, returns `FileType.notFound` 
    and `FileType.none` respectively.

    However it will also throw if the path is invalid.
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

    If not found or I/O error, returns `FileType.notFound` 
    and `FileType.none` respectively.

    However it will also throw if the path is invalid.
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
            r.perms = FilePerms.none;
            if (err == ERROR_FILE_NOT_FOUND
                || err == ERROR_PATH_NOT_FOUND
                || err == ERROR_INVALID_DRIVE)
                r.type = FileType.notFound;
            else
                r.type = FileType.none;
        }
        else
        {
            // FUTURE: support NTFS symbolic links
            if (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
                r.type = FileType.directory;
            else
                r.type = FileType.regular;
        }
        return r;
    }
    else version(Posix)
    {
        return posix_statusFromPath(path, false);
    }
    else 
        assert(0);
}


/**
    Checks if the given file status or path corresponds to a block 
    special file, as if determined by the POSIX `S_ISBLK`. Examples of 
    block special files are block devices such as `/dev/sda` or 
    `/dev/loop0` on Linux. 
*/
bool isBlockFile(FileStatus s) pure
    => s.type == FileType.block;
///ditto
bool isBlockFile(Path p) // symlinks are followed here
    => isBlockFile(status(p));


/**
    Checks if the given file status or path corresponds to a character
    special file, as if determined by POSIX `S_ISCHR`. Examples of 
    character special files are character devices such as `/dev/null`, 
    `/dev/tty`, `/dev/audio`, or `/dev/nvram` on Linux. 
*/
bool isCharacterFile(FileStatus s) pure
    => s.type == FileType.character;
///ditto
bool isCharacterFile(Path p) // symlinks are followed here
    => isCharacterFile(status(p));


/**
    Checks if the given file status or path corresponds to a 
    directory.
*/
bool isDirectory(FileStatus s) pure
    => s.type == FileType.directory;
///ditto
bool isDirectory(Path p) // symlinks are followed here
    => isDirectory(status(p));


// TODO is_empty checks whether the given path refers to an empty file or directory


/**
    Checks if the given file status or path corresponds to a FIFO or 
    pipe file as if determined by POSIX `S_ISFIFO`. 
*/
bool isFIFO(FileStatus s) pure
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
*/
bool isOther(FileStatus s) pure
    => exists(s) && !isRegularFile(s) && !isDirectory(s) && !isSymlink(s);
///ditto
bool isOther(Path p) // symlinks are followed here
    => isOther(status(p));


/**
    Checks if the given file status or path corresponds to a regular 
    file.
*/
bool isRegularFile(FileStatus s) pure
    => s.type == FileType.regular;
///ditto
bool isRegularFile(Path p) // symlinks are followed here
    => isRegularFile(status(p));


/**
    Checks if the given file status or path corresponds to a named IPC 
    socket, as if determined by the POSIX `S_IFSOCK`.
*/
bool isSocket(FileStatus s) pure
    => s.type == FileType.socket;
///ditto
bool isSocket(Path p) // symlinks are followed here
    => isSocket(status(p));


/**
    Checks if the given file status or path corresponds to a symbolic 
    link, as if determined by the POSIX `S_IFLNK`.

    This function is the only of its kind that doesn't follow 
    symlinks, for obvious reasons.
*/
bool isSymlink(FileStatus s) pure
    => s.type == FileType.socket;
///ditto
bool isSymlink(Path p) // symlinks are NOT followed here
    => isSymlink(symlink_status(p));


/**
    Checks if the given file status is known.

    To get a `FileStatus`, use either `status` or
    `symlinkStatus`.
*/
bool statusKnown(FileStatus s) pure nothrow
    => s.type != FileType.none;


private:


version(Windows)
{
    bool isWindowsSymlink(ref WIN32_FILE_ATTRIBUTE_DATA info) nothrow
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
}

version(Posix)
{
    FileStatus posix_statusFromPath(Path p, bool followIfSymlink) nothrow
    {
        FileStatus r;
        stat buf;
        nstring s = path.native();
        int res;
        if (followIfSymlink)
            res = stat(s.ptr, &buf);
        else
            res = lstat(s.ptr, &buf);

        if (res != 0)
        {
            r.perms = 0;
            int err = errno;
            if (errno == ENOENT)
                r.type = FileType.notFound;
            else
                r.type = FileType.none;
        }
        else
            r = statusFromPosixStat(buf);

        return r;
    }

    FileStatus statusFromPosixStat(ref stat buf) nothrow
    {
        r.perms = cast(FilePerms) (buf.st_mode & FilePerms.mask);
        switch(buf.st_mode & S_IFMT)
        {
            case S_IFREG:  r.type = FileType.regular;
            case S_IFDIR:  r.type = FileType.directory;
            case S_IFLNK:  r.type = FileType.symlink;
            case S_IFBLK:  r.type = FileType.block;
            case S_IFCHR:  r.type = FileType.character; 
            case S_IFIFO:  r.type = FileType.fifo;
            case S_IFSOCK: r.type = FileType.socket;
            default:
                r.type = FileType.unknown;
        }
    }
}


