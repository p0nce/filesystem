/**
    All the non-structured types that are part of the API.

    Copyright: Guillaume Piolat 2026.
    License: MIT (https://mit-license.org/)
*/
module filesystem.types;

import filesystem.internals;

public import numem.core.exception;
import numem.lifetime;


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
    unknown,   /// The file exists, but its type could not be determined.
}


/**
    Stores information about the type and permissions of a file.

    See_also: `status`, `symlinkStatus`.
*/
struct FileStatus
{
    FileType type;          /// Type of the file.
    FilePerms permissions;  /// Permissions of the file.
    long sizeBytes;         /// File size, must be >= 0 && <= MAXIMUM_FILE_SIZE.
    FileTime lastWriteTime; /// In UNIX epoch.
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

    mask       = 0xFFF, /// All valid permission bits. 

    invalid    = 0x1000 /// An invalid sentinel value. 
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
    directoriesOnly    = 32, /// UNSUPPORTED TODO Copy the directory structure, but do not copy any non-directory files. 
    createSymlinks     = 64, /// UNSUPPORTED TODO Instead of creating copies of files, create symlinks pointing to the originals. Note: the source path must be an absolute path unless the destination path is in the current directory. 
    createHardLinks    = 96  /// UNSUPPORTED TODO Instead of creating copies of files, create hardlinks that resolve to the same files as the originals. 
}


/**
    This type represents available options that control the behavior 
    of the `DirectoryRange` and `RecursiveDirectoryRange`.

    These options can combine as a bitmask.
*/ 
enum DirectoryOptions
{
    /// (default) Skip directory symlinks, "permission denied" is an 
    /// error.
    none = 0, 

    /// Follow rather than skip directory symlinks.
    followDirectorySymlink = 1, // TODO not implemented

    /// Skip directories that would otherwise result in "permission 
    /// denied" errors.
    skipPermissionDenied   = 2,

    /// Spans the directory in depth-first post-order, i.e. the content 
    /// of any subdirectory is spanned before that subdirectory itself. 
    /// Useful e.g. when recursively deleting files.
    ///
    /// When not present, the order is instead breadth first pre-order:
    /// visit the current node, then their children.
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

    /// Free space available to a non-privileged process (may be equal 
    /// or less than free).
    long available;
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

    Catching this is often a way to get out of racey
    situations, since by the times you've listed a 
    directory contents, any of its file could have
    disappeared. And using `exists()` is not a race-free
    fix.
*/
class FileNotFoundException : FileSystemException 
{
@nogc:
    this(const(char)[] path, Throwable nextInChain = null, string file = __FILE__, size_t line = __LINE__)
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
    roughly the same effect, and it always lead to the
    same treatment until now.
*/
class InvalidPathException : FileSystemException 
{
@nogc:

    this(const(char)[] msg, Throwable nextInChain = null, string file = __FILE__, size_t line = __LINE__) 
    {
        super(msg, nextInChain, file, line);
    }
}
