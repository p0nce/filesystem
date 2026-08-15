/**
    All the non-structured types that are part of the API.

    Copyright: Guillaume Piolat 2026.
    License: MIT (https://mit-license.org/)
*/
module filesystem.types;

public import numem.core.exception;
import numem.lifetime;

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
    // Those two states are not representable in this library.
    // Before getting that state you would have gotten an exception.
    // none,      /// File status has not been evaluated yet, or an error occurred.
    // notFound,  /// File was not found (this is not considered an error).

    regular,   /// A regular file.
    directory, /// A directory.
    symlink,   /// A symbolic link.
    block,     /// A block special file.
    character, /// A character special file.
    fifo,      /// A FIFO (also knwon as pipe) file.
    socket,    /// A socket file.
    unknown,   /// The file exists, but its type could not be determined.
}

/**
    Model permissions model POSIX permission bits, and any individual 
    file permissions (as reported by `FileStatus`) are a 
    combination of some of the following bits: 
*/
enum FilePerms : int
{
    none       = 0,     /// No permission bits are set.
    
    ownerRead  = 0x100,  /// File owner has read permission.
    ownerWrite = 0x080,  /// File owner has write permission.
    ownerExec  = 0x040,  /// File owner has execute/search permission.
    ownerAll   = 0x1C0,  /// File owner has read, write, and execute/search permissions.
    
    groupRead  = 0x20,   /// The file's user group has read permission.
    groupWead  = 0x10,   /// The file's user group has write permission.
    groupExec  = 0x08,   /// The file's user group has execute/search permission.
    groupAll   = 0x38,   /// The file's user group has read, write, and execute/search permissions.

    othersRead = 0x04,   /// Other users have read permission.
    othersWead = 0x02,   /// Other users have write permission.
    othersExec = 0x01,   /// Other users have execute/search permission.
    othersAll  = 0x07,   /// Other users have read, write, and execute/search permissions.

    all        = 0x1FF,  /// All users have read, write, and execute/search permissions.

    setUid     = 0x800, /// Set user ID to file owner user ID on execution.
    setGid     = 0x400, /// Set group ID to file's user group ID on execution.
    stickyBit  = 0x200, /// Implementation-defined meaning.

    mask       = 0xFFF  /// All valid permission bits. 
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

/// All the options the copying functions support.
enum CopyOptions : int 
{
    none = 0,                /// Default behaviour

    // Options controlling `copy_file()` when the 
    // file already exists 
    // Bits 0-1
    reportAnError     = 0,   /// Default behaviour.
    skipExisting      = 1,   /// Keep the existing file, without reporting an error. 
    overwriteExisting = 2,   /// Replace the existing file. 
    updateExisting    = 3,   /// Replace the existing file only if it is older than the file being copied.

    // Options controlling the effects of `copy()`
    // on subdirectories
    // Bit 2
    skipSubDirectories = 0,  /// Skip sub-directories (default behaviour).
    recursive          = 4,  /// Recursively copy subdirectories and their content. 

    // Options controlling the effects of `copy()` on symbolic links.
    // Bit 3-4
    followSymlinks     = 0,  /// Follow symlinks (default behaviour)
    copySymlinks       = 8,  /// Copy symlinks as symlinks, not as the files they point to. 
    ignoreSymlinks     = 16, /// Ignore symlinks. 

    // Options controlling the kind of copying copy() does .
    copyFileContent    = 0,  /// Copy file content (default behavior). 
    directoriesOnly    = 32, /// UNSUPPORTED Copy the directory structure, but do not copy any non-directory files. 
    createSymlinks     = 64, /// UNSUPPORTED Instead of creating copies of files, create symlinks pointing to the originals. Note: the source path must be an absolute path unless the destination path is in the current directory. 
    createHardLinks    = 96  /// UNSUPPORTED Instead of creating copies of files, create hardlinks that resolve to the same files as the originals. 
}

/**
    Above that size, we consider the file can't possibly
    by that big. That's nearly 8191 petabytes.
*/
enum ulong MAXIMUM_FILE_SIZE = long.max;

/**
    Stores information about the type and permissions of a file.
*/
struct FileStatus
{
    FileType type;
    FilePerms permissions;
    long sizeBytes;         /// File size, must be >= 0 && <= MAXIMUM_FILE_SIZE.
    FileTime lastWriteTime; /// In UNIX epoch.
}

/**
    The one type of exception thrown by `filesystem` package.
*/
class FileSystemException : NuException 
{
@nogc:

    this(const(char)[] msg, Throwable nextInChain = null, string file = __FILE__, size_t line = __LINE__) 
    {
        super(msg, nextInChain, file, line);
    }
}


/**
    Specific exception type when a file isn't found.
    Needed because fileNotFound is not representable 
    in `FileType` in our version.
*/
class FileNotFoundException : FileSystemException 
{
@nogc:

    this(const(char)[] msg, Throwable nextInChain = null, string file = __FILE__, size_t line = __LINE__) 
    {
        super(msg, nextInChain, file, line);
    }
}


/**
    Specific exception type when a, I/O error is encountered.
*/
class FileSystemIOException : FileSystemException 
{
@nogc:

    this(const(char)[] msg, Throwable nextInChain = null, string file = __FILE__, size_t line = __LINE__) 
    {
        super(msg, nextInChain, file, line);
    }
}

/**
    Specific exception type in case of invalid path.
    FUTURE: may merge with FileSystemIOException? It has
    roughly the same effect.
*/
class InvalidPathException : FileSystemException 
{
@nogc:

    this(const(char)[] msg, Throwable nextInChain = null, string file = __FILE__, size_t line = __LINE__) 
    {
        super(msg, nextInChain, file, line);
    }
}
