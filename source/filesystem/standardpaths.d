/**
 * Functions for retrieving standard paths in cross-platform manner.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov 2015-2016
 *  Guillaume Piolat 2026
 */
module filesystem.standardpaths;

import nulib.string;
import nulib.collections.vector;

import filesystem.path;
import filesystem.internals;

version(Windows) 
{
    pragma(lib, "shell32");
    pragma(lib, "ole32");
    import core.sys.windows.winnt;
    import core.sys.windows.basetyps;
} 
else version(Posix) 
{
}
else
    static assert(0);

@nogc:

/**

    Location types that can be passed to `writablePath` and 
    `standardPaths` functions.
 
    Not all these paths are suggested for showing in file managers or 
    file dialogs. Some of them are meant for internal application 
    usage or should be treated in special way.

    On usual circumstances user wants to see Desktop, Documents, 
    Downloads, Pictures, Music and Videos directories.
 
    See_Also: `writablePath`, `standardPaths`.
*/
enum StandardPath 
{    
    /// General location of persisted application data. Every 
    /// application should have its own subdirectory here.
    /// Note: on Windows it's the same as `config` path.
    data,

    /// General location of configuration files. Every application 
    /// should have its own subdirectory here.
    /// Note: on Windows it's the same as `data` path.
    config,

    /// Location of cached data.
    /// Note: Not available on Windows.
    cache,

    /// User's desktop directory.
    desktop,

    /// User's documents.
    documents,

    /// User's pictures.
    pictures,

    ///User's music.
    music,

    /// User's videos (movies).
    videos,

    /// Directory for user's downloaded files.
    downloads,

    /// Location of file templates (e.g. office suite document templates).
    /// Note: Not available on OS X.
    templates,

    /// Public share folder.
    /// Note: Not available on Windows.
    publicShare,

    /// Location of fonts files.
    /// Note: don't rely on this on freedesktop, since it uses 
    /// hardcoded paths there. Better consider using 
    /// http://www.freedesktop.org/wiki/Software/fontconfig/, 
    /// fontconfig library
    fonts,

    /// User's applications. This has different meaning across 
    /// platforms.
    /// - On Windows it's directory where links (.lnk) to programs for 
    ///   Start menu are stored.
    /// - On OS X it's folder where applications are typically put.
    /// - On Freedesktop it's directory where .desktop files are put.
    applications,

    /// Automatically started applications.
    /// - On Windows it's directory where links (.lnk) to autostarted 
    ///   programs are stored.
    /// - On OSX it's not available.
    /// - On Freedesktop it's directory where autostarted .desktop 
    ///   files are stored.
    startup,

    /// Roaming directory that stores a user data which should be 
    /// shared between user profiles on different machines. 
    /// Windows-only.
    roaming,

    /// Common directory for game save files. Windows-only.    
    savedGames
}

/**
    Current user home directory.

    Returns: Path to user home directory, or an empty string if could 
             not determine home directory.
*/
Path homeDir() /* nothrow */ /* @safe */
{
    nstring home;    
    version(Windows)
    {
        //Use GetUserProfileDirectoryW from Userenv.dll?
        home = getEnvironmentVariable(nstring("USERPROFILE"));
        if (home.empty) 
        {
            nstring homeDrive = getEnvironmentVariable("HOMEDRIVE");
            nstring homePath  = getEnvironmentVariable("HOMEPATH");
            if (homeDrive.length && homePath.length) 
            {
                home = homeDrive ~ homePath;
            }
        }
    }
    else
    {
        home = getEnvironmentVariable(nstring("HOME"));
    }
    return Path(home);
}


/**
    Get writable path for a specific location.

    Returns: Path where files of `type` should be written to by 
             current user, or an empty string on failure.

    Params:
        type = Location to lookup.
        params = Union of `FolderFlag`.
 
    Note: This function does not cache its results.

    Example:
    --------------------
    Path appData = writablePath(StandardPath.data);

    enum orgName = "MyCompany";
    enum appName = "MyApplication";

    if (! appData.empty) 
    {
        createDirectories(appData / orgName / appName);
    } 
    else 
    {
        // Could not detect default downloads directory.
    }
    --------------------

    See_Also: `StandardPath`, `standardPaths`.
*/
Path writablePath(StandardPath type) /* nothrow */ @safe
{
    version(Windows)
    {
        final switch(type) 
        {
            case StandardPath.config:
            case StandardPath.data:
                return getKnownFolder(FOLDERID_LocalAppData);
            case StandardPath.cache:
                return Path.init;
            case StandardPath.desktop:
                return getKnownFolder(FOLDERID_Desktop);
            case StandardPath.documents:
                return getKnownFolder(FOLDERID_Documents);
            case StandardPath.pictures:
                return getKnownFolder(FOLDERID_Pictures);
            case StandardPath.music:
                return getKnownFolder(FOLDERID_Music);
            case StandardPath.videos:
                return getKnownFolder(FOLDERID_Videos);
            case StandardPath.downloads:
                return getKnownFolder(FOLDERID_Downloads);
            case StandardPath.templates:
                return getKnownFolder(FOLDERID_Templates);
            case StandardPath.publicShare:
                return Path.init;
            case StandardPath.fonts:
                return Path.init;
            case StandardPath.applications:
                return getKnownFolder(FOLDERID_Programs);
            case StandardPath.startup:
                return getKnownFolder(FOLDERID_Startup);
            case StandardPath.roaming:
                return getKnownFolder(FOLDERID_RoamingAppData);
            case StandardPath.savedGames:
                return getKnownFolder(FOLDERID_SavedGames);
        }
    }
    else 
    {
        return null;
    }
}


/**
   Get paths for various locations.

   Returns: Array of paths where files of `type` belong including one 
   returned by `writablePath`, or an empty array if no paths are 
   defined for `type`.

   Returned list of pathes are not  required to be unique, accessible, 
   or even exists.

   Note: This function does not cache its results.
   It may cause performance impact to call this function often since retrieving some paths can be relatively expensive operation.

   See_Also: `StandardPath`, `writablePath`.
*/
vector!Path standardPaths(StandardPath type) @safe
{
    Path commonPath;

    switch(type) 
    {
        case StandardPath.config:
        case StandardPath.data:
            commonPath = getKnownFolder(FOLDERID_ProgramData);
            break;
        case StandardPath.desktop:
            commonPath = getKnownFolder(FOLDERID_PublicDesktop);
            break;
        case StandardPath.documents:
            commonPath = getKnownFolder(FOLDERID_PublicDocuments);
            break;
        case StandardPath.pictures:
            commonPath = getKnownFolder(FOLDERID_PublicPictures);
            break;
        case StandardPath.music:
            commonPath = getKnownFolder(FOLDERID_PublicMusic);
            break;
        case StandardPath.videos:
            commonPath = getKnownFolder(FOLDERID_PublicVideos);
            break;
        case StandardPath.downloads:
            commonPath = getKnownFolder(FOLDERID_PublicDownloads);
            break;
        case StandardPath.templates:
            commonPath = getKnownFolder(FOLDERID_CommonTemplates);
            break;
        case StandardPath.fonts:
            commonPath = getKnownFolder(FOLDERID_Fonts);
            break;
        case StandardPath.applications:
            commonPath = getKnownFolder(FOLDERID_CommonPrograms);
            break;
        case StandardPath.startup:
            commonPath = getKnownFolder(FOLDERID_CommonStartup);
            break;
        default:
            break;
    }

    // TODO userPath

    vector!Path paths;
    Path userPath = writablePath(type);
    if (userPath.length)
        paths ~= userPath;
    if (commonPath.length)
        paths ~= commonPath;
    return paths;
    return paths;
}


/+
else version(OSX) {
    private {
        import std.string : fromStringz;
        version(StandardPathsCocoa) {
            import core.attribute : selector;

            alias size_t NSUInteger;

            enum objectiveC_declarations = q{
                extern (Objective-C)
                interface NSString
                {
                    NSString initWithUTF8String(in char* str) @selector("initWithUTF8String:");
                    const(char)* UTF8String() @selector("UTF8String");
                    void release() @selector("release");
                }

                extern(Objective-C)
                interface NSArray
                {
                    NSString objectAtIndex(size_t) @selector("objectAtIndex:");
                    NSString firstObject() @selector("firstObject");
                    NSUInteger count() @selector("count");
                    void release() @selector("release");
                }

                extern(Objective-C)
                interface NSURL
                {
                    NSString absoluteString() @selector("absoluteString");
                    void release() @selector("release");
                }

                extern(Objective-C)
                interface NSError
                {

                }

                extern (C) NSFileManager objc_lookUpClass(in char* name);

                extern(Objective-C)
                interface NSFileManager
                {
                    NSFileManager defaultManager() @selector("defaultManager");
                    NSURL URLForDirectory(NSSearchPathDirectory, NSSearchPathDomainMask domain, NSURL url, int shouldCreate, NSError* error) @selector("URLForDirectory:inDomain:appropriateForURL:create:error:");
                }
            };

            mixin(objectiveC_declarations);

            enum : NSUInteger {
               NSApplicationDirectory = 1,
               NSDemoApplicationDirectory,
               NSDeveloperApplicationDirectory,
               NSAdminApplicationDirectory,
               NSLibraryDirectory,
               NSDeveloperDirectory,
               NSUserDirectory,
               NSDocumentationDirectory,
               NSDocumentDirectory,
               NSCoreServiceDirectory,
               NSAutosavedInformationDirectory = 11,
               NSDesktopDirectory = 12,
               NSCachesDirectory = 13,
               NSApplicationSupportDirectory = 14,
               NSDownloadsDirectory = 15,
               NSInputMethodsDirectory = 16,
               NSMoviesDirectory = 17,
               NSMusicDirectory = 18,
               NSPicturesDirectory = 19,
               NSPrinterDescriptionDirectory = 20,
               NSSharedPublicDirectory = 21,
               NSPreferencePanesDirectory = 22,
               NSItemReplacementDirectory = 99,
               NSAllApplicationsDirectory = 100,
               NSAllLibrariesDirectory = 101,
            };

            alias NSUInteger NSSearchPathDirectory;

            enum : NSUInteger {
               NSUserDomainMask = 1,
               NSLocalDomainMask = 2,
               NSNetworkDomainMask = 4,
               NSSystemDomainMask = 8,
               NSAllDomainsMask = 0x0ffff,
            };

            alias NSUInteger NSSearchPathDomainMask;

            string domainDir(NSSearchPathDirectory dir, NSSearchPathDomainMask domain, bool shouldCreate = false) nothrow @trusted
            {
                import std.uri;
                import std.algorithm : startsWith;

                try {
                    auto managerInterface = objc_lookUpClass("NSFileManager");
                    if (!managerInterface) {
                        return null;
                    }

                    auto manager = managerInterface.defaultManager();
                    if (!manager) {
                        return null;
                    }

                    NSURL url = manager.URLForDirectory(dir, domain, null, shouldCreate, null);
                    if (!url) {
                        return null;
                    }
                    scope(exit) url.release();
                    NSString nsstr = url.absoluteString();
                    scope(exit) nsstr.release();

                    string str = fromStringz(nsstr.UTF8String()).idup;

                    enum fileProtocol = "file://";
                    if (str.startsWith(fileProtocol)) {
                        str = str.decode()[fileProtocol.length..$];
                        if (str.length > 1 && str[$-1] == '/') {
                            return str[0..$-1];
                        } else {
                            return str;
                        }
                    }
                } catch(Exception e) {

                }
                return null;
            }
        } else {
            private enum : short {
                kOnSystemDisk                 = -32768L, /* previously was 0x8000 but that is an unsigned value whereas vRefNum is signed*/
                kOnAppropriateDisk            = -32767, /* Generally, the same as kOnSystemDisk, but it's clearer that this isn't always the 'boot' disk.*/
                                                        /* Folder Domains - Carbon only.  The constants above can continue to be used, but the folder/volume returned will*/
                                                        /* be from one of the domains below.*/
                kSystemDomain                 = -32766, /* Read-only system hierarchy.*/
                kLocalDomain                  = -32765, /* All users of a single machine have access to these resources.*/
                kNetworkDomain                = -32764, /* All users configured to use a common network server has access to these resources.*/
                kUserDomain                   = -32763, /* Read/write. Resources that are private to the user.*/
                kClassicDomain                = -32762, /* Domain referring to the currently configured Classic System Folder.  Not supported in Mac OS X Leopard and later.*/
                kFolderManagerLastDomain      = -32760
            }

            private @nogc int k(string s) nothrow {
                return s[0] << 24 | s[1] << 16 | s[2] << 8 | s[3];
            }

            private enum {
                kDesktopFolderType            = k("desk"), /* the desktop folder; objects in this folder show on the desktop. */
                kTrashFolderType              = k("trsh"), /* the trash folder; objects in this folder show up in the trash */
                kWhereToEmptyTrashFolderType  = k("empt"), /* the "empty trash" folder; Finder starts empty from here down */
                kFontsFolderType              = k("font"), /* Fonts go here */
                kPreferencesFolderType        = k("pref"), /* preferences for applications go here */
                kSystemPreferencesFolderType  = k("sprf"), /* the PreferencePanes folder, where Mac OS X Preference Panes go */
                kTemporaryFolderType          = k("temp"), /*    On Mac OS X, each user has their own temporary items folder, and the Folder Manager attempts to set permissions of these*/
                                                        /*    folders such that other users can not access the data inside.  On Mac OS X 10.4 and later the data inside the temporary*/
                                                        /*    items folder is deleted at logout and at boot, but not otherwise.  Earlier version of Mac OS X would delete items inside*/
                                                        /*    the temporary items folder after a period of inaccess.  You can ask for a temporary item in a specific domain or on a */
                                                        /*    particular volume by FSVolumeRefNum.  If you want a location for temporary items for a short time, then use either*/
                                                        /*    ( kUserDomain, kkTemporaryFolderType ) or ( kSystemDomain, kTemporaryFolderType ).  The kUserDomain varient will always be*/
                                                        /*    on the same volume as the user's home folder, while the kSystemDomain version will be on the same volume as /var/tmp/ ( and*/
                                                        /*    will probably be on the local hard drive in case the user's home is a network volume ).  If you want a location for a temporary*/
                                                        /*    file or folder to use for saving a document, especially if you want to use FSpExchangeFile() to implement a safe-save, then*/
                                                        /*    ask for the temporary items folder on the same volume as the file you are safe saving.*/
                                                        /*    However, be prepared for a failure to find a temporary folder in any domain or on any volume.  Some volumes may not have*/
                                                        /*    a location for a temporary folder, or the permissions of the volume may be such that the Folder Manager can not return*/
                                                        /*    a temporary folder for the volume.*/
                                                        /*    If your application creates an item in a temporary items older you should delete that item as soon as it is not needed,*/
                                                        /*    and certainly before your application exits, since otherwise the item is consuming disk space until the user logs out or*/
                                                        /*    restarts.  Any items left inside a temporary items folder should be moved into a folder inside the Trash folder on the disk*/
                                                        /*    when the user logs in, inside a folder named "Recovered items", in case there is anything useful to the end user.*/
                kChewableItemsFolderType      = k("flnt"), /* similar to kTemporaryItemsFolderType, except items in this folder are deleted at boot or when the disk is unmounted */
                kTemporaryItemsInCacheDataFolderType = k("vtmp"), /* A folder inside the kCachedDataFolderType for the given domain which can be used for transient data*/
                kApplicationsFolderType       = k("apps"), /*    Applications on Mac OS X are typically put in this folder ( or a subfolder ).*/
                kVolumeRootFolderType         = k("root"), /* root folder of a volume or domain */
                kDomainTopLevelFolderType     = k("dtop"), /* The top-level of a Folder domain, e.g. "/System"*/
                kDomainLibraryFolderType      = k("dlib"), /* the Library subfolder of a particular domain*/
                kUsersFolderType              = k("usrs"), /* "Users" folder, usually contains one folder for each user. */
                kCurrentUserFolderType        = k("cusr"), /* The folder for the currently logged on user; domain passed in is ignored. */
                kSharedUserDataFolderType     = k("sdat"), /* A Shared folder, readable & writeable by all users */
                kCachedDataFolderType         = k("cach"), /* Contains various cache files for different clients*/
                kDownloadsFolderType          = k("down"), /* Refers to the ~/Downloads folder*/
                kApplicationSupportFolderType = k("asup"), /* third-party items and folders */


                kDocumentsFolderType          = k("docs"), /*    User documents are typically put in this folder ( or a subfolder ).*/
                kPictureDocumentsFolderType   = k("pdoc"), /* Refers to the "Pictures" folder in a users home directory*/
                kMovieDocumentsFolderType     = k("mdoc"), /* Refers to the "Movies" folder in a users home directory*/
                kMusicDocumentsFolderType     = 0xB5646F63/*'µdoc'*/, /* Refers to the "Music" folder in a users home directory*/
                kInternetSitesFolderType      = k("site"), /* Refers to the "Sites" folder in a users home directory*/
                kPublicFolderType             = k("pubb"), /* Refers to the "Public" folder in a users home directory*/

                kDropBoxFolderType            = k("drop") /* Refers to the "Drop Box" folder inside the user's home directory*/
            };

            struct FSRef {
              char[80] hidden;    /* private to File Manager*/
            };

            alias ubyte Boolean;
            alias int OSType;
            alias short OSErr;
            alias int OSStatus;

            extern(C) @nogc @system OSErr _dummy_FSFindFolder(short, OSType, Boolean, FSRef*) nothrow { return 0; }
            extern(C) @nogc @system OSStatus _dummy_FSRefMakePath(const(FSRef)*, char*, uint) nothrow { return 0; }

            __gshared typeof(&_dummy_FSFindFolder) ptrFSFindFolder = null;
            __gshared typeof(&_dummy_FSRefMakePath) ptrFSRefMakePath = null;
        }
    }

    version(StandardPathsCocoa) {

    } else {
        shared static this()
        {
            enum carbonPath = "CoreServices.framework/Versions/A/CoreServices\0";

            // This one still work as of macOS 15.1, it was used in Dplug for a good while
            enum carbonPath2 = "/System/Library/Frameworks/CoreServices.framework/CoreServices\0";

            import core.sys.posix.dlfcn;

            void* handle = dlopen(carbonPath.ptr, RTLD_NOW | RTLD_LOCAL);
            if (!handle)
                handle = dlopen(carbonPath2.ptr, RTLD_NOW | RTLD_LOCAL);

            if (handle) {
                ptrFSFindFolder = cast(typeof(ptrFSFindFolder))dlsym(handle, "FSFindFolder");
                ptrFSRefMakePath = cast(typeof(ptrFSRefMakePath))dlsym(handle, "FSRefMakePath");
            }
            if (ptrFSFindFolder == null || ptrFSRefMakePath == null) {
                debug collectException(stderr.writeln("Could not load carbon functions"));
                if (handle) dlclose(handle);
            }
        }

        private @nogc @trusted bool isCarbonLoaded() nothrow
        {
            return ptrFSFindFolder != null && ptrFSRefMakePath != null;
        }

        private enum OSErr noErr = 0;

        private string fsPath(short domain, OSType type, bool shouldCreate = false) nothrow @trusted
        {
            import std.stdio;
            FSRef fsref;
            if (isCarbonLoaded() && ptrFSFindFolder(domain, type, shouldCreate, &fsref) == noErr) {

                char[2048] buf;
                char* path = buf.ptr;
                if (ptrFSRefMakePath(&fsref, path, buf.sizeof) == noErr) {
                    try {
                        return fromStringz(path).idup;
                    }
                    catch(Exception e) {

                    }
                }
            }
            return null;
        }
    }

    private string writablePathImpl(StandardPath type, bool shouldCreate = false) nothrow @safe
    {
        version(StandardPathsCocoa) {
            final switch(type) {
                case StandardPath.config:
                    return domainDir(NSLibraryDirectory, NSUserDomainMask, shouldCreate).maybeBuild("Preferences").createIfNeeded(shouldCreate);
                case StandardPath.cache:
                    return domainDir(NSCachesDirectory, NSUserDomainMask, shouldCreate);
                case StandardPath.data:
                    return domainDir(NSApplicationSupportDirectory, NSUserDomainMask, shouldCreate);
                case StandardPath.desktop:
                    return domainDir(NSDesktopDirectory, NSUserDomainMask, shouldCreate);
                case StandardPath.documents:
                    return domainDir(NSDocumentDirectory, NSUserDomainMask, shouldCreate);
                case StandardPath.pictures:
                    return domainDir(NSPicturesDirectory, NSUserDomainMask, shouldCreate);
                case StandardPath.music:
                    return domainDir(NSMusicDirectory, NSUserDomainMask, shouldCreate);
                case StandardPath.videos:
                    return domainDir(NSMoviesDirectory, NSUserDomainMask, shouldCreate);
                case StandardPath.downloads:
                    return domainDir(NSDownloadsDirectory, NSUserDomainMask, shouldCreate);
                case StandardPath.templates:
                    return null;
                case StandardPath.publicShare:
                    return domainDir(NSSharedPublicDirectory, NSUserDomainMask, shouldCreate);
                case StandardPath.fonts:
                    return domainDir(NSLibraryDirectory, NSUserDomainMask, shouldCreate).maybeBuild("Fonts").createIfNeeded(shouldCreate);
                case StandardPath.applications:
                    return domainDir(NSApplicationDirectory, NSUserDomainMask, shouldCreate);
                case StandardPath.startup:
                    return null;
                case StandardPath.roaming:
                    return null;
                case StandardPath.savedGames:
                    return null;
            }
        } else {
            final switch(type) {
                case StandardPath.config:
                    return fsPath(kUserDomain, kPreferencesFolderType, shouldCreate);
                case StandardPath.cache:
                    return fsPath(kUserDomain, kCachedDataFolderType, shouldCreate);
                case StandardPath.data:
                    return fsPath(kUserDomain, kApplicationSupportFolderType, shouldCreate);
                case StandardPath.desktop:
                    return fsPath(kUserDomain, kDesktopFolderType, shouldCreate);
                case StandardPath.documents:
                    return fsPath(kUserDomain, kDocumentsFolderType, shouldCreate);
                case StandardPath.pictures:
                    return fsPath(kUserDomain, kPictureDocumentsFolderType, shouldCreate);
                case StandardPath.music:
                    return fsPath(kUserDomain, kMusicDocumentsFolderType, shouldCreate);
                case StandardPath.videos:
                    return fsPath(kUserDomain, kMovieDocumentsFolderType, shouldCreate);
                case StandardPath.downloads:
                    return fsPath(kUserDomain, kDownloadsFolderType, shouldCreate);
                case StandardPath.templates:
                    return null;
                case StandardPath.publicShare:
                    return fsPath(kUserDomain, kPublicFolderType, shouldCreate);
                case StandardPath.fonts:
                    return fsPath(kUserDomain, kFontsFolderType, shouldCreate);
                case StandardPath.applications:
                    return fsPath(kUserDomain, kApplicationsFolderType, shouldCreate);
                case StandardPath.startup:
                    return null;
                case StandardPath.roaming:
                    return null;
                case StandardPath.savedGames:
                    return null;
            }
        }
    }

    string writablePath(StandardPath type, FolderFlag params = FolderFlag.none) nothrow @safe
    {
        const bool shouldCreate = (params & FolderFlag.create) != 0;
        const bool shouldVerify = (params & FolderFlag.verify) != 0;
        return writablePathImpl(type, shouldCreate).verifyIfNeeded(shouldVerify);
    }

    string[] standardPaths(StandardPath type) nothrow @safe
    {
        string commonPath;

        version(StandardPathsCocoa) {
            switch(type) {
                case StandardPath.fonts:
                    commonPath = domainDir(NSLibraryDirectory, NSSystemDomainMask).maybeBuild("Fonts");
                    break;
                case StandardPath.applications:
                    commonPath = domainDir(NSApplicationDirectory, NSSystemDomainMask);
                    break;
                case StandardPath.data:
                    commonPath = domainDir(NSApplicationSupportDirectory, NSSystemDomainMask);
                    break;
                case StandardPath.cache:
                    commonPath = domainDir(NSCachesDirectory, NSSystemDomainMask);
                    break;
                default:
                    break;
            }
        } else {
            switch(type) {
                case StandardPath.fonts:
                    commonPath = fsPath(kOnAppropriateDisk, kFontsFolderType);
                    break;
                case StandardPath.applications:
                    commonPath = fsPath(kOnAppropriateDisk, kApplicationsFolderType);
                    break;
                case StandardPath.data:
                    commonPath = fsPath(kOnAppropriateDisk, kApplicationSupportFolderType);
                    break;
                case StandardPath.cache:
                    commonPath = fsPath(kOnAppropriateDisk, kCachedDataFolderType);
                    break;
                default:
                    break;
            }
        }

        string[] paths;
        string userPath = writablePath(type);
        if (userPath.length)
            paths ~= userPath;
        if (commonPath.length)
            paths ~= commonPath;
        return paths;
    }

} else {

    static if (!isFreedesktop) {
        static assert(false, "Unsupported platform");
    } else {
        public import xdgpaths;

        private {
            import std.stdio : File;
            import std.algorithm : startsWith;
            import std.string;
            import std.traits;
        }

        unittest
        {
            assert(maybeConcat(null, "path") == string.init);
            assert(maybeConcat("path", "/file") == "path/file");
        }

        private @trusted string getFromUserDirs(Range)(string xdgdir, string home, Range range) if (isInputRange!Range && isSomeString!(ElementType!Range))
        {
            foreach(line; range) {
                line = strip(line);
                auto index = xdgdir.length;
                if (line.startsWith(xdgdir) && line.length > index && line[index] == '=') {
                    line = line[index+1..$];
                    if (line.length > 2 && line[0] == '"' && line[$-1] == '"')
                    {
                        line = line[1..$-1];

                        if (line.startsWith("$HOME")) {
                            return maybeConcat(home, assumeUnique(line[5..$]));
                        }
                        if (line.length == 0 || line[0] != '/') {
                            continue;
                        }
                        return assumeUnique(line);
                    }
                }
            }
            return null;
        }


        unittest
        {
            string content =
`# Comment

XDG_DOCUMENTS_DIR="$HOME/My Documents"
XDG_MUSIC_DIR="/data/Music"
XDG_VIDEOS_DIR="data/Video"
`;
            string home = "/home/user";

            assert(getFromUserDirs("XDG_DOCUMENTS_DIR", home, content.splitLines) == "/home/user/My Documents");
            assert(getFromUserDirs("XDG_MUSIC_DIR", home, content.splitLines) == "/data/Music");
            assert(getFromUserDirs("XDG_DOWNLOAD_DIR", home, content.splitLines).empty);
            assert(getFromUserDirs("XDG_VIDEOS_DIR", home, content.splitLines).empty);
        }

        private @trusted string getFromDefaultDirs(Range)(string key, string home, Range range) if (isInputRange!Range && isSomeString!(ElementType!Range))
        {
            foreach(line; range) {
                line = strip(line);
                auto index = key.length;
                if (line.startsWith(key) && line.length > index && line[index] == '=')
                {
                    line = line[index+1..$];
                    return home ~ "/" ~ assumeUnique(line);
                }
            }
            return null;
        }

        unittest
        {
            string content =
`# Comment

DOCUMENTS=MyDocuments
PICTURES=Images
`;
            string home = "/home/user";
            assert(getFromDefaultDirs("DOCUMENTS", home, content.splitLines) == "/home/user/MyDocuments");
            assert(getFromDefaultDirs("PICTURES", home, content.splitLines) == "/home/user/Images");
            assert(getFromDefaultDirs("VIDEOS", home, content.splitLines).empty);
        }

        private string xdgUserDir(string key, string fallback = null) nothrow @trusted {
            string fileName = maybeConcat(writablePath(StandardPath.config), "/user-dirs.dirs");
            string home = homeDir();
            try {
                auto f = File(fileName, "r");
                auto xdgdir = "XDG_" ~ key ~ "_DIR";
                auto path = getFromUserDirs(xdgdir, home, f.byLine());
                if (path.length) {
                    return path;
                }
            } catch(Exception e) {

            }

            if (home.length) {
                try {
                    auto f = File("/etc/xdg/user-dirs.defaults", "r");
                    auto path = getFromDefaultDirs(key, home, f.byLine());
                    if (path.length) {
                        return path;
                    }
                } catch (Exception e) {

                }
                if (fallback.length) {
                    return home ~ fallback;
                }
            }
            return null;
        }

        private string homeFontsPath() nothrow @trusted {
            return maybeConcat(homeDir(), "/.fonts");
        }

        private string[] fontPaths() nothrow @trusted
        {
            enum localShare = "/usr/local/share/fonts";
            enum share = "/usr/share/fonts";

            string homeFonts = homeFontsPath();
            if (homeFonts.length) {
                return [homeFonts, localShare, share];
            } else {
                return [localShare, share];
            }
        }

        private string writablePathImpl(StandardPath type, bool shouldCreate) nothrow @safe
        {
            final switch(type) {
                case StandardPath.config:
                    return xdgConfigHome(null, shouldCreate);
                case StandardPath.cache:
                    return xdgCacheHome(null, shouldCreate);
                case StandardPath.data:
                    return xdgDataHome(null, shouldCreate);
                case StandardPath.desktop:
                    return xdgUserDir("DESKTOP", "/Desktop").createIfNeeded(shouldCreate);
                case StandardPath.documents:
                    return xdgUserDir("DOCUMENTS").createIfNeeded(shouldCreate);
                case StandardPath.pictures:
                    return xdgUserDir("PICTURES").createIfNeeded(shouldCreate);
                case StandardPath.music:
                    return xdgUserDir("MUSIC").createIfNeeded(shouldCreate);
                case StandardPath.videos:
                    return xdgUserDir("VIDEOS").createIfNeeded(shouldCreate);
                case StandardPath.downloads:
                    return xdgUserDir("DOWNLOAD").createIfNeeded(shouldCreate);
                case StandardPath.templates:
                    return xdgUserDir("TEMPLATES", "/Templates").createIfNeeded(shouldCreate);
                case StandardPath.publicShare:
                    return xdgUserDir("PUBLICSHARE", "/Public").createIfNeeded(shouldCreate);
                case StandardPath.fonts:
                    return homeFontsPath().createIfNeeded(shouldCreate);
                case StandardPath.applications:
                    return xdgDataHome("applications", shouldCreate);
                case StandardPath.startup:
                    return xdgConfigHome("autostart", shouldCreate);
                case StandardPath.roaming:
                    return null;
                case StandardPath.savedGames:
                    return null;
            }
        }

        string writablePath(StandardPath type, FolderFlag params = FolderFlag.none) nothrow @safe
        {
            const bool shouldCreate = (params & FolderFlag.create) != 0;
            const bool shouldVerify = (params & FolderFlag.verify) != 0;
            return writablePathImpl(type, shouldCreate).verifyIfNeeded(shouldVerify);
        }

        string[] standardPaths(StandardPath type) nothrow @safe
        {
            string[] paths;

            switch(type) {
                case StandardPath.data:
                    return xdgAllDataDirs();
                case StandardPath.config:
                    return xdgAllConfigDirs();
                case StandardPath.applications:
                    return xdgAllDataDirs("applications");
                case StandardPath.startup:
                    return xdgAllConfigDirs("autostart");
                case StandardPath.fonts:
                    return fontPaths();
                default:
                    break;
            }

            string userPath = writablePath(type);
            if (userPath.length) {
                return [userPath];
            }
            return null;
        }
    }
}
+/

private:


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


//
// Windows-specific internals
//


version(Windows) 
{
    enum 
    {
        CSIDL_DESKTOP            =  0,
        CSIDL_INTERNET,
        CSIDL_PROGRAMS,
        CSIDL_CONTROLS,
        CSIDL_PRINTERS,
        CSIDL_PERSONAL,
        CSIDL_FAVORITES,
        CSIDL_STARTUP,
        CSIDL_RECENT,
        CSIDL_SENDTO,
        CSIDL_BITBUCKET,
        CSIDL_STARTMENU,      // = 11
        CSIDL_MYMUSIC            = 13,
        CSIDL_MYVIDEO,        // = 14
        CSIDL_DESKTOPDIRECTORY   = 16,
        CSIDL_DRIVES,
        CSIDL_NETWORK,
        CSIDL_NETHOOD,
        CSIDL_FONTS,
        CSIDL_TEMPLATES,
        CSIDL_COMMON_STARTMENU,
        CSIDL_COMMON_PROGRAMS,
        CSIDL_COMMON_STARTUP,
        CSIDL_COMMON_DESKTOPDIRECTORY,
        CSIDL_APPDATA,
        CSIDL_PRINTHOOD,
        CSIDL_LOCAL_APPDATA,
        CSIDL_ALTSTARTUP,
        CSIDL_COMMON_ALTSTARTUP,
        CSIDL_COMMON_FAVORITES,
        CSIDL_INTERNET_CACHE,
        CSIDL_COOKIES,
        CSIDL_HISTORY,
        CSIDL_COMMON_APPDATA,
        CSIDL_WINDOWS,
        CSIDL_SYSTEM,
        CSIDL_PROGRAM_FILES,
        CSIDL_MYPICTURES,
        CSIDL_PROFILE,
        CSIDL_SYSTEMX86,
        CSIDL_PROGRAM_FILESX86,
        CSIDL_PROGRAM_FILES_COMMON,
        CSIDL_PROGRAM_FILES_COMMONX86,
        CSIDL_COMMON_TEMPLATES,
        CSIDL_COMMON_DOCUMENTS,
        CSIDL_COMMON_ADMINTOOLS,
        CSIDL_ADMINTOOLS,
        CSIDL_CONNECTIONS,  // = 49
        CSIDL_COMMON_MUSIC     = 53,
        CSIDL_COMMON_PICTURES,
        CSIDL_COMMON_VIDEO,
        CSIDL_RESOURCES,
        CSIDL_RESOURCES_LOCALIZED,
        CSIDL_COMMON_OEM_LINKS,
        CSIDL_CDBURN_AREA,  // = 59
        CSIDL_COMPUTERSNEARME  = 61,
        CSIDL_FLAG_DONT_VERIFY = 0x4000,
        CSIDL_FLAG_CREATE      = 0x8000,
        CSIDL_FLAG_MASK        = 0xFF00
    }

    enum 
    {
        KF_FLAG_SIMPLE_IDLIST                = 0x00000100,
        KF_FLAG_NOT_PARENT_RELATIVE          = 0x00000200,
        KF_FLAG_DEFAULT_PATH                 = 0x00000400,
        KF_FLAG_INIT                         = 0x00000800,
        KF_FLAG_NO_ALIAS                     = 0x00001000,
        KF_FLAG_DONT_UNEXPAND                = 0x00002000,
        KF_FLAG_DONT_VERIFY                  = 0x00004000,
        KF_FLAG_CREATE                       = 0x00008000,
        KF_FLAG_NO_APPCONTAINER_REDIRECTION  = 0x00010000,
        KF_FLAG_ALIAS_ONLY                   = 0x80000000
    }

    alias GUID KNOWNFOLDERID;

    enum KNOWNFOLDERID FOLDERID_LocalAppData = {0xf1b32785, 0x6fba, 0x4fcf, [0x9d,0x55,0x7b,0x8e,0x7f,0x15,0x70,0x91]};
    enum KNOWNFOLDERID FOLDERID_RoamingAppData = {0x3eb685db, 0x65f9, 0x4cf6, [0xa0,0x3a,0xe3,0xef,0x65,0x72,0x9f,0x3d]};

    enum KNOWNFOLDERID FOLDERID_Desktop = {0xb4bfcc3a, 0xdb2c, 0x424c, [0xb0,0x29,0x7f,0xe9,0x9a,0x87,0xc6,0x41]};
    enum KNOWNFOLDERID FOLDERID_Documents = {0xfdd39ad0, 0x238f, 0x46af, [0xad,0xb4,0x6c,0x85,0x48,0x3,0x69,0xc7]};
    enum KNOWNFOLDERID FOLDERID_Downloads = {0x374de290, 0x123f, 0x4565, [0x91,0x64,0x39,0xc4,0x92,0x5e,0x46,0x7b]};
    enum KNOWNFOLDERID FOLDERID_Favorites = {0x1777f761, 0x68ad, 0x4d8a, [0x87,0xbd,0x30,0xb7,0x59,0xfa,0x33,0xdd]};
    enum KNOWNFOLDERID FOLDERID_Links = {0xbfb9d5e0, 0xc6a9, 0x404c, [0xb2,0xb2,0xae,0x6d,0xb6,0xaf,0x49,0x68]};
    enum KNOWNFOLDERID FOLDERID_Music = {0x4bd8d571, 0x6d19, 0x48d3, [0xbe,0x97,0x42,0x22,0x20,0x8,0xe,0x43]};
    enum KNOWNFOLDERID FOLDERID_Pictures = {0x33e28130, 0x4e1e, 0x4676, [0x83,0x5a,0x98,0x39,0x5c,0x3b,0xc3,0xbb]};
    enum KNOWNFOLDERID FOLDERID_Programs = {0xa77f5d77, 0x2e2b, 0x44c3, [0xa6,0xa2,0xab,0xa6,0x1,0x5,0x4a,0x51]};
    enum KNOWNFOLDERID FOLDERID_SavedGames = {0x4c5c32ff, 0xbb9d, 0x43b0, [0xb5,0xb4,0x2d,0x72,0xe5,0x4e,0xaa,0xa4]};
    enum KNOWNFOLDERID FOLDERID_Startup = {0xb97d20bb, 0xf46a, 0x4c97, [0xba,0x10,0x5e,0x36,0x8,0x43,0x8,0x54]};
    enum KNOWNFOLDERID FOLDERID_Templates = {0xa63293e8, 0x664e, 0x48db, [0xa0,0x79,0xdf,0x75,0x9e,0x5,0x9,0xf7]};
    enum KNOWNFOLDERID FOLDERID_Videos = {0x18989b1d, 0x99b5, 0x455b, [0x84,0x1c,0xab,0x7c,0x74,0xe4,0xdd,0xfc]};

    enum KNOWNFOLDERID FOLDERID_Fonts = {0xfd228cb7, 0xae11, 0x4ae3, [0x86,0x4c,0x16,0xf3,0x91,0xa,0xb8,0xfe]};
    enum KNOWNFOLDERID FOLDERID_ProgramData = {0x62ab5d82, 0xfdc1, 0x4dc3, [0xa9,0xdd,0x7,0xd,0x1d,0x49,0x5d,0x97]};
    enum KNOWNFOLDERID FOLDERID_CommonPrograms = {0x139d44e, 0x6afe, 0x49f2, [0x86,0x90,0x3d,0xaf,0xca,0xe6,0xff,0xb8]};
    enum KNOWNFOLDERID FOLDERID_CommonStartup = {0x82a5ea35, 0xd9cd, 0x47c5, [0x96,0x29,0xe1,0x5d,0x2f,0x71,0x4e,0x6e]};
    enum KNOWNFOLDERID FOLDERID_CommonTemplates = {0xb94237e7, 0x57ac, 0x4347, [0x91,0x51,0xb0,0x8c,0x6c,0x32,0xd1,0xf7]};

    enum KNOWNFOLDERID FOLDERID_PublicDesktop = {0xc4aa340d, 0xf20f, 0x4863, [0xaf,0xef,0xf8,0x7e,0xf2,0xe6,0xba,0x25]};
    enum KNOWNFOLDERID FOLDERID_PublicDocuments = {0xed4824af, 0xdce4, 0x45a8, [0x81,0xe2,0xfc,0x79,0x65,0x8,0x36,0x34]};
    enum KNOWNFOLDERID FOLDERID_PublicDownloads = {0x3d644c9b, 0x1fb8, 0x4f30, [0x9b,0x45,0xf6,0x70,0x23,0x5f,0x79,0xc0]};
    enum KNOWNFOLDERID FOLDERID_PublicMusic = {0x3214fab5, 0x9757, 0x4298, [0xbb,0x61,0x92,0xa9,0xde,0xaa,0x44,0xff]};
    enum KNOWNFOLDERID FOLDERID_PublicPictures = {0xb6ebfb86, 0x6907, 0x413c, [0x9a,0xf7,0x4f,0xc2,0xab,0xf0,0x7c,0xc5]};
    enum KNOWNFOLDERID FOLDERID_PublicVideos = {0x2400183a, 0x6185, 0x49fb, [0xa2,0xd8,0x4a,0x39,0x2a,0x60,0x2b,0xa3]};

    extern(Windows) 
    {
        HRESULT SHGetKnownFolderPath(KNOWNFOLDERID* rfid,
                                     DWORD          dwFlags,
                                     HANDLE         hToken,
                                     PWSTR         *ppszPath);

        void CoTaskMemFree(void* pv);
    }

    // Get a known path, or "" if not possible.
    Path getKnownFolder(const(KNOWNFOLDERID) folder) @trusted /* nothrow */
    {
        wchar* str;

        // Don't verify taht the folder exists, don't create it either.
        DWORD flags = KF_FLAG_DONT_VERIFY;

        if (SHGetKnownFolderPath(cast(KNOWNFOLDERID*)&folder, flags, null, &str) == S_OK) 
        {
            scope(exit) CoTaskMemFree(str);
            nwstring s = str[0..fs_wstrlen(str)];
            return Path(s.toUTF8OrEmpty());
        }
        return Path.init;
    }
}