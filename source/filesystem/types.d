/**
    Types that are part of the`API.

    Copyright: Guillaume Piolat 2026.
    License: MIT (https://mit-license.org/)
*/
module filesystem.types;

import filesystem.internals;

public import numem.core.exception;
import numem.lifetime;

/*
    Here are the exceptions that the `filesystem` package can throw:

    FileSystemException (any I/O and API usage error)
          |
          |
          |----- InvalidPathException  (a path is deemed invalid)
          |
           ----- FileNotFoundException (a file is not found)

    The only exception that need some special user treatment is 
    `FileNotFoundException`, otherwise there is little reason to 
    catch `InvalidPathException` since it's indistinguishable from an
    I/O error.
*/

/**
    The one type of exception thrown by this package.
*/
class FileSystemException : NuException 
{
@nogc:

    this(const(char)[] msg, Throwable nextInChain = null, 
        string file = __FILE__, size_t line = __LINE__) 
    {
        super(msg, nextInChain, file, line);
    }
}

/**
    Specific exception type when a file isn't found.
*/
class FileNotFoundException : FileSystemException 
{
@nogc:
    this(const(char)[] path, Throwable nextInChain = null, 
        string file = __FILE__, size_t line = __LINE__)
    {
        size_t P = path.length;
        size_t L = kStrFileNotFound.length;
        char[] msg;
        msg.nu_resize(L+P+1);
        msg[0..L] = kStrFileNotFound[];
        msg[L..L+P] = path[];
        msg[L+P] = '`';
        scope(exit) msg.nu_resize(0);
        super(msg, nextInChain, file, line);
    }
}

/**
    Specific exception type in case of invalid path.

    Because there is little reason to ever catch this, it isn't 
    specifically mentionned in function that throws these, as they
    can always be treated as `FileSystemException`. It's more to have
    the right error message.
*/
class InvalidPathException : FileSystemException 
{
@nogc:

    this(const(char)[] path, Throwable nextInChain = null, 
        string file = __FILE__, size_t line = __LINE__) 
    {
        size_t P = path.length;
        size_t L = kStrInvalidPath.length;
        char[] msg;
        msg.nu_resize(L+P+1);
        msg[0..L] = kStrInvalidPath[];
        msg[L..L+P] = path[];
        msg[L+P] = '`';
        scope(exit) msg.nu_resize(0);
        super(msg, nextInChain, file, line);
    }
}


/**
    Time used for modification dates. 
    Number of seconds since UNIX epoch.
*/
alias FileTime = long;

/**
    Type of file.

    See_also: `status`, `FileStatus`.

    eg: A directory is a file of type `FileType.directory`.
*/
enum FileType
{
    regular,   /// A regular file.
    directory, /// A directory.
    symlink,   /// A symbolic link.
    block,     /// A block special file.
    character, /// A character special file.
    fifo,      /// A FIFO (also knwon as pipe) file.
    socket,    /// A socket file.
    unknown,   /// File exists, but its type could not be determined.
}


/**
    Stores information about the type and permissions of a file.

    Note: permissions and lastWriteTime are only meaningful for
        regular files on Windows. FUTURE clarify that.

    See_also: `status`, `symlinkStatus`.
*/
struct FileStatus
{
    /// Type of the file.
    FileType type;          

    /// File size, must be >= 0 && <= MAXIMUM_FILE_SIZE.
    long sizeBytes;         

    /// Permissions of the file.    
    FilePerms permissions;

    /// Last write time, in UNIX epoch.
    FileTime lastWriteTime; 
}


/**
    Model permissions model POSIX permission bits, and any individual 
    file permissions (as reported by `FileStatus`) are a 
    combination of some of the following bits: 
*/
enum FilePerms : int
{
    /// No permission bits are set.
    none       = 0,

    /// File owner has read permission.
    ownerRead  = 0x100,
    /// File owner has write permission.
    ownerWrite = 0x080,
    /// File owner has execute/search permission.
    ownerExec  = 0x040,
    /// File owner has read, write, and execute/search permissions.
    ownerAll   = 0x1C0,

    /// User group has read permission.
    groupRead  = 0x20,
    /// User group has write permission.
    groupWead  = 0x10,
    /// User group has execute/search permission.
    groupExec  = 0x08,
    /// User group has read, write, and execute/search permissions.
    groupAll   = 0x38,

    /// Other users have read permission.
    othersRead = 0x04,
    /// Other users have write permission.
    othersWead = 0x02,
    /// Other users have execute/search permission.
    othersExec = 0x01,
    /// Other users have read, write, and execute/search permissions.
    othersAll  = 0x07,

    /// All users have read, write, and execute/search permissions.
    all        = 0x1FF,

    /// Set user ID to file owner user ID on execution.
    setUid     = 0x800,
    /// Set group ID to file's user group ID on execution.
    setGid     = 0x400,
    /// Implementation-defined meaning.
    stickyBit  = 0x200,

    /// All valid permission bits. 
    mask       = 0xFFF,
    /// An invalid sentinel value, used internally.
    invalid    = 0x1000 
}


enum PermOptions : int
{
    // Bit 0-1 = mode
    /// Replace by the argument to `permissions()` (default behavior).
    replace   = 0,
    /// Bitwise OR with current permissions.
    add       = 1,
    /// Bitwise AND of the negated argument and current permissions.
    remove    = 2,

    // Bit 2  = no follow bit.
    /// Permissions will be changed on the symlink itself, rather 
    /// than on the file it resolves to.    
    nofollow  = 4,
}


/**
    All the options the copying functions support.

    See_also: `copyFile`, `copy`.
*/
enum CopyOptions : int 
{
    none = 0,                /// Default behaviour

    // Bits 0-1
    // Options controlling `copy_file()` when the file already exists.

    /// Report an error (default)
    reportAnError      = 0,
    /// Keep the existing file, without reporting an error.
    skipExisting       = 1,
    /// Replace the existing file.
    overwriteExisting  = 2,
    /// Replace the existing file only if it is older than the file 
    /// being copied.
    updateExisting     = 3,

    // Bit 2
    // Options controlling the effects of `copy()` on subdirectories.

    /// Skip sub-directories (default).
    skipSubDirectories = 0,
    /// Recursively copy subdirectories and their content.
    recursive          = 4,

    // Bits 3-4
    // Options controlling the effects of `copy()` on symbolic links.

    /// Follow symlinks (default)
    followSymlinks     = 0,
    /// Copy symlinks as symlinks, not as the files they point to.
    copySymlinks       = 8,
    /// Ignore symlinks.
    ignoreSymlinks     = 16,

    // Bits 5-6
    // Options controlling the kind of copying copy() does.

    /// Copy file content (default).
    copyFileContent    = 0,
    /// Copy the directory structure, but do not copy any
    /// non-directory files.
    directoriesOnly    = 32,
    /// Instead of creating copies of files, create symlinks pointing
    /// to the originals. Note: the source path must be an absolute
    /// path unless the destination path is in the current directory.
    createSymlinks     = 64, 

    // internal use
    inRecursiveCopy    = 256
}


/**
    This type represents available options that control the behavior
    of the `dirEntries` and `dirEntriesRecursive` calls.
    These options can combine as a bitmask.

    See_also: `dirEntries`, `dirEntriesRecursive`.
*/ 
enum DirectoryOptions
{
    /// (default) Skip directory symlinks, "permission denied" is an 
    /// error.
    none = 0,

    /// Follow rather than skip directory symlinks.
    followDirectorySymlink = 1,

    /// Skip directories that would otherwise result in "permission
    /// denied" errors.
    skipPermissionDenied   = 2,

    /// Spans directory in depth-first post-order, i.e. the content 
    /// of any subdirectory is spanned before subdirectory itself. 
    /// Useful e.g. when recursively deleting files.
    spanDepthFirst         = 4
}


/**
    Represents the filesystem information as determined by `space()`.

    See_also: `space()`.
*/
struct SpaceInfo
{
    /// Total size of the filesystem, in bytes.
    long capacity;

    /// Free space on the filesystem, in bytes.
    ///
    /// Warning: As it's not the space available to the caller, there
    /// is little reason to use that normally.
    long freeTheoretical;

    /// Free space available to a non-privileged process, in bytes
    /// (may be equal or less than free).
    long available;
}


