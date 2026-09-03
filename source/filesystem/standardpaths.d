/*
    Functions for retrieving standard paths in cross-platform manner.

    Also: getting XDG base directories.
    Note: These functions are defined only on freedesktop systems.

    Reference: 
        https://specifications.freedesktop.org/basedir/latest/

    Authors:
        Roman Chistokhodov <https://github.com/FreeSlave>

    Copyright:
        Copyright (c) 2015 - 2016, Roman Chistokhodov.
        Copyright (c) 2026, Guillaume Piolat.

    License:
        $(LINK2 http://www.boost.org/LICENSE_1_0.txt, BSL-1.0).
*/
module filesystem.standardpaths;

import numem;
import nulib.string;
import nulib.memory;
import nulib.collections.vector;
import nulib.io.stream.file;

import filesystem.internals;
import filesystem.types;
import filesystem.path;
import filesystem.freefunc;
import filesystem.standardpaths;


version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;
else version (VisionOS)
    version = Darwin;

version(Windows) 
{
    pragma(lib, "shell32");
    pragma(lib, "ole32");
    import core.sys.windows.winnt;
    import core.sys.windows.basetyps;
} 
else version(Darwin) 
{
    version(D_ObjectiveC){}
    else
        static assert(0, "Need a compiler with D_ObjectiveC support");

    import objc;
    import foundation;
    import core.attribute : selector;
} else static if (isFreedesktop)
{
}
else
    static assert(0, "Unrecognized OS");

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

    /// Location of file templates (e.g. office document templates).
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
        createIfMissing = Create the directory if not existing.
 
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
Path writablePath(StandardPath type, bool createIfMissing = false) 
    /* nothrow */ @trusted
{
    alias create = createIfMissing;
    version(Windows)
    {
        final switch(type) 
        {
        case StandardPath.config:
        case StandardPath.data:
            return getKnownFolder(FOLDERID_LocalAppData, create);
        case StandardPath.cache:
            return Path.init;
        case StandardPath.desktop:
            return getKnownFolder(FOLDERID_Desktop, create);
        case StandardPath.documents:
            return getKnownFolder(FOLDERID_Documents, create);
        case StandardPath.pictures:
            return getKnownFolder(FOLDERID_Pictures, create);
        case StandardPath.music:
            return getKnownFolder(FOLDERID_Music, create);
        case StandardPath.videos:
            return getKnownFolder(FOLDERID_Videos, create);
        case StandardPath.downloads:
            return getKnownFolder(FOLDERID_Downloads, create);
        case StandardPath.templates:
            return getKnownFolder(FOLDERID_Templates, create);
        case StandardPath.publicShare:
            return Path.init;
        case StandardPath.fonts:
            return Path.init;
        case StandardPath.applications:
            return getKnownFolder(FOLDERID_Programs, create);
        case StandardPath.startup:
            return getKnownFolder(FOLDERID_Startup, create);
        case StandardPath.roaming:
            return getKnownFolder(FOLDERID_RoamingAppData, create);
        case StandardPath.savedGames:
            return getKnownFolder(FOLDERID_SavedGames, create);
        }
    }
    else version(Darwin)
    {
        auto user = NSUserDomainMask;
        final switch(type) 
        {
        case StandardPath.config:
            return domainDir(NSLibraryDirectory, user, create)
                  .maybeAppend("Preferences");
        case StandardPath.cache:
            return domainDir(NSCachesDirectory, user, create);
        case StandardPath.data:
            return domainDir(NSApplicationSupportDirectory, user, 
                             create);
        case StandardPath.desktop:
            return domainDir(NSDesktopDirectory, user, create);
        case StandardPath.documents:
            return domainDir(NSDocumentDirectory, user, create);
        case StandardPath.pictures:
            return domainDir(NSPicturesDirectory, user, create);
        case StandardPath.music:
            return domainDir(NSMusicDirectory, user, create);
        case StandardPath.videos:
            return domainDir(NSMoviesDirectory, user, create);
        case StandardPath.downloads:
            return domainDir(NSDownloadsDirectory, user, create);
        case StandardPath.templates:
            return Path.init;
        case StandardPath.publicShare:
            return domainDir(NSSharedPublicDirectory, user, create);
        case StandardPath.fonts:
            return domainDir(NSLibraryDirectory, user, create)
                  .maybeAppend("Fonts");
        case StandardPath.applications:
            return domainDir(NSApplicationDirectory, user, create);
        case StandardPath.startup:
            return Path.init;
        case StandardPath.roaming:
            return Path.init;
        case StandardPath.savedGames:
            return Path.init;
        }
    }
    else static if (isFreedesktop)
    {
        final switch(type) 
        {
        case StandardPath.config:
            return xdgConfigHome(null, create);
        case StandardPath.cache:
            return xdgCacheHome(null, create);
        case StandardPath.data:
            return xdgDataHome(null, create);
        case StandardPath.desktop:
            Path desktopDir = xdgUserDir("DESKTOP", "/Desktop");
            return createIfNeeded(desktopDir, create);
        case StandardPath.documents:
            return createIfNeeded(xdgUserDir("DOCUMENTS"), create);
        case StandardPath.pictures:
            return createIfNeeded(xdgUserDir("PICTURES"), create);
        case StandardPath.music:
            return createIfNeeded(xdgUserDir("MUSIC"), create);
        case StandardPath.videos:
            return createIfNeeded(xdgUserDir("VIDEOS"), create);
        case StandardPath.downloads:
            return createIfNeeded(xdgUserDir("DOWNLOAD"), create);
        case StandardPath.templates:
            Path templatesDir = xdgUserDir("TEMPLATES", "/Templates");
            return createIfNeeded(templatesDir, create);
        case StandardPath.publicShare:
            Path publicShare = xdgUserDir("PUBLICSHARE", "/Public");
            return createIfNeeded(publicShare, create);
        case StandardPath.fonts:
            return createIfNeeded(homeFontsPath(), create);
        case StandardPath.applications:
            return xdgDataHome("applications", create);
        case StandardPath.startup:
            return xdgConfigHome("autostart", create);
        case StandardPath.roaming:
            return Path.init;
        case StandardPath.savedGames:
            return Path.init;
        }
    }
    else 
    {
        return Path.init;
    }
}


/**
   Get paths for various locations.

   Returns: Array of paths where files of `type` belong including one 
   returned by `writablePath`, or an empty array if no paths are 
   defined for `type`.

   Returned paths in the list are not required to be unique, 
   accessible, or even exists.

   Note: This function does not cache its results.
   It may cause performance impact to call this function often since 
   retrieving some paths can be relatively expensive operation.

   See_Also: `StandardPath`, `writablePath`.
*/
vector!Path standardPaths(StandardPath type) @safe
{
    vector!Path paths;
    Path common;
    vector!Path commonPaths;

    version(Windows)
    {     
        switch(type) 
        {
            case StandardPath.config:
            case StandardPath.data:
                common = getKnownFolder(FOLDERID_ProgramData);
                break;
            case StandardPath.desktop:
                common = getKnownFolder(FOLDERID_PublicDesktop);
                break;
            case StandardPath.documents:
                common = getKnownFolder(FOLDERID_PublicDocuments);
                break;
            case StandardPath.pictures:
                common = getKnownFolder(FOLDERID_PublicPictures);
                break;
            case StandardPath.music:
                common = getKnownFolder(FOLDERID_PublicMusic);
                break;
            case StandardPath.videos:
                common = getKnownFolder(FOLDERID_PublicVideos);
                break;
            case StandardPath.downloads:
                common = getKnownFolder(FOLDERID_PublicDownloads);
                break;
            case StandardPath.templates:
                common = getKnownFolder(FOLDERID_CommonTemplates);
                break;
            case StandardPath.fonts:
                common = getKnownFolder(FOLDERID_Fonts);
                break;
            case StandardPath.applications:
                common = getKnownFolder(FOLDERID_CommonPrograms);
                break;
            case StandardPath.startup:
                common = getKnownFolder(FOLDERID_CommonStartup);
                break;
            default:
                break;
        }
    }
    else version(Darwin)
    {
        auto system = NSSystemDomainMask;
        switch(type) 
        {
            case StandardPath.fonts:
                common = domainDir(NSLibraryDirectory, system)
                        .maybeAppend("Fonts");
                break;
            case StandardPath.applications:
                common = domainDir(NSApplicationDirectory, system);
                break;
            case StandardPath.data:
                common = domainDir(NSApplicationSupportDirectory, system);
                break;
            case StandardPath.cache:
                common = domainDir(NSCachesDirectory, system);
                break;
            default:
                break;
        }
    }
    else static if (isFreedesktop)
    {
        switch(type) {
            case StandardPath.data:
                commonPaths = xdgAllDataDirs();
                break;
            case StandardPath.config:
                commonPaths = xdgAllConfigDirs();
                break;
            case StandardPath.applications:
                commonPaths = xdgAllDataDirs("applications");
                break;
            case StandardPath.startup:
                commonPaths = xdgAllConfigDirs("autostart");
                break;
            case StandardPath.fonts:
                commonPaths = fontPaths();
                break;
            default:
                break;
        }
    }
    else
        static assert(0);

    Path userPath = writablePath(type);
    if (userPath.length)
        paths ~= userPath;
    if (commonPath.length)
        paths ~= commonPath;
    foreach (p; commonPaths)
    {
        if (paths.find(p) == -1)
            paths ~= p;
    }
    return paths;
}





private:







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
    Path getKnownFolder(const(KNOWNFOLDERID) folder, 
        bool createIfMissing = false) @trusted /* nothrow */
    {
        wchar* str;

        // Don't verify that the folder exists, nor create it
        DWORD flags = KF_FLAG_DONT_VERIFY;
        if (createIfMissing) flags |= KF_FLAG_CREATE;

        if (SHGetKnownFolderPath(cast(KNOWNFOLDERID*)&folder, flags, 
            null, &str) == S_OK) 
        {
            scope(exit) CoTaskMemFree(str);
            nwstring s = str[0..fs_wstrlen(str)];
            return Path(s.toUTF8OrEmpty());
        }
        return Path.init;
    }
}


//
// Darwin-specific internals
//

version(Darwin) 
{
    alias NSSearchPathDirectory = NSUInteger;
    enum : NSSearchPathDirectory 
    {
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

    alias NSSearchPathDomainMask = NSUInteger;

    enum : NSSearchPathDomainMask 
    {
        NSUserDomainMask = 1,
        NSLocalDomainMask = 2,
        NSNetworkDomainMask = 4,
        NSSystemDomainMask = 8,
        NSAllDomainsMask = 0x0ffff,
    };

    extern(Objective-C)
    extern class NSFileManager : NSObject 
    {
    @nogc nothrow:
    protected:
        static NSFileManager defaultManager() @selector("defaultManager");
        NSURL URLForDirectory(NSSearchPathDirectory dir, NSSearchPathDomainMask domain, NSURL url, int shouldCreate, NSError* error) @selector("URLForDirectory:inDomain:appropriateForURL:create:error:");
    }

    Path domainDir(NSSearchPathDirectory dir, NSSearchPathDomainMask domain, bool shouldCreate) nothrow @trusted
    {
        try 
        {
            NSFileManager manager = NSFileManager.defaultManager();
            if (!manager)
                return Path.init;
            NSURL url = manager.URLForDirectory(dir, domain, null, shouldCreate, null);
            if (!url) {
                return Path.init;
            }
            scope(exit) url.release();
            NSString nsstr = url.absoluteString();
            scope(exit) nsstr.release();

            nstring str = nstring(fromStringz(nsstr.ptr)); // calls UTF8String
            nstring fileProtocol = nstring("file://");
            if (startsWith(str, fileProtocol)) 
            {
                str = str[7..$];
                if (str.length > 1 && str[$-1] == '/') 
                {
                    return Path(str[0..$-1]);
                } 
                else 
                {
                    return Path(str);
                }
            }
        }
        catch(NuException e)
        {
            e.freeNoThrow;
        } 
        catch(Exception e) 
        {
        }
        return Path.init;
    }
}


//
// Free desktop specifics (partial port of xdgpaths package by same 
// author)
//

static if (isFreedesktop)
{

    /**
    The ordered set of non-empty base paths to search for :
    data files, config, or cache files, in descending order of 
    preference.

    Note: This function does not check if paths actually exist and 
    appear to be directories.

    */
    vector!Path xdgDataDirs(string subfolder = null) @trusted
    {
        nstring nsub = nstring(subfolder);
        vector!Path r = pathsFromEnv("XDG_DATA_DIRS", ':', nsub);
        if (r.empty)
        {
            r ~= Path("/usr/local/share") / subfolder;
            r ~= Path("/usr/share") / subfolder;
        }
        return r;
    }
    ///ditto
    vector!Path xdgConfigDirs(string subfolder = null) @trusted
    {
        nstring nsub = nstring(subfolder);
        vector!Path r = pathsFromEnv("XDG_CONFIG_DIRS", ':', nsub);
        if (r.empty)
            r ~= Path("/etc/xdg") / subfolder;
        return r;
    }


    /**
    The base directory relative to which user-specific 
    data, state, config or cache files should be stored.

    Returns: 
    Path to user-specific data directory or empty string on error.

    Params:
    subfolder = Subfolder to append to determined path.
    shouldCreate = If path does not exist, create directory using 
    700 permissions (i.e. allow access only for current user).
    */
    Path xdgDataHome(string subfolder = null, bool shouldCreate = false) @safe
        => xdgBaseDir("XDG_DATA_HOME", ".local/share", subfolder, shouldCreate);
    ///ditto
    Path xdgStateHome(string subfolder = null, bool shouldCreate = false) @safe
        => xdgBaseDir("XDG_STATE_HOME", ".local/state", subfolder, shouldCreate);
    ///ditto
    Path xdgConfigHome(string subfolder = null, bool shouldCreate = false) @safe
        => xdgBaseDir("XDG_CONFIG_HOME", ".config", subfolder, shouldCreate);
    ///ditto
    Path xdgCacheHome(string subfolder = null, bool shouldCreate = false) @safe
        => xdgBaseDir("XDG_CACHE_HOME", ".cache", subfolder, shouldCreate);


    /**
    The ordered set of non-empty base paths to search for data files, 
    or config files, in descending order of preference.

    The user data/config directory takes precedence, and is thus 
    ordered first if it exists.

    Returns: 
    Data directories, including user's one if could be evaluated.

    Note: This function does not check if paths actually exist and 
    appear to be directories.
    */
    vector!Path xdgAllDataDirs(string subfolder = null) @safe
    {
        vector!Path r;
        Path user = xdgDataHome(subfolder);
        if (! user.empty) r ~= user;
        r ~= xdgDataDirs(subfolder)[];
        return r;
    }
    ///ditto
    vector!Path xdgAllConfigDirs(string subfolder = null) @safe
    {
        vector!Path r;
        Path user = xdgConfigHome(subfolder);
        if (! user.empty) r ~= user;
        r ~= xdgConfigDirs(subfolder)[];
        return r;
    }

    enum FilePerms privateMode = FilePerms.ownerAll;


    vector!Path pathsFromEnv(const(char)[] envName, 
                             char separator = ':',
                             nstring subfolder = nstring.init) 
        => pathsFromEnvValue(getEnvironmentVariable(envName), 
                             separator, subfolder);


    Path xdgBaseDir(string envvar, 
                    string fallback, 
                    string subfolder = null, 
                    bool shouldCreate = false) @trusted
    {
        // First look at hypothetical envvar
        Path dir = Path(getEnvironmentVariable(envvar));

        // Fallback inside ~/<fallback> if no such envvar
        if (dir.empty)
            dir = Path(getEnvironmentVariable(nstring("HOME")))
                  .maybeAppend(fallback);

        if (dir.empty)
            return dir;

        dir.maybeAppend(subfolder);

        if (shouldCreate) 
        {
            if (! ensureExists(dir, privateMode)) 
                return Path.init;
        }
        return dir;
    }

    Path xdgUserDir(const(char)[] key, string fallback = null) @trusted
    {
        Path fileName = writablePath(StandardPath.config)
                        .maybeAppend("user-dirs.dirs");
        Path home = homeDir();

        try 
        {
            nstring xdgdir = nstring("XDG_") ~ key ~ "_DIR";
            Path path = getFromUserDirs(xdgdir, home, fileName);
            if (path.length)
                return path;
        } 
        catch(Exception e) 
        {
        }

        // Didn't find such a directory in user-dirs.dirs

        if (home.length) 
        {
            try 
            {
                auto path = getFromDefaultDirs(key, home, 
                    Path("/etc/xdg/user-dirs.defaults"));
                if (path.length)
                    return path;
            } 
            catch (FileSystemException e) 
            {
                // typically: file doesn't exist, or no access
                e.free();
            }
        }

        if (fallback !is null)
            return home / fallback;

        return Path.init;
    }

    Path homeFontsPath() => homeDir() / "/.fonts";

    vector!Path fontPaths() @trusted
    {    
        vector!Path r;
        Path homeFonts = homeFontsPath();
        if (!homeFonts.empty)
            r ~= homeFonts;
        r ~= Path("/usr/local/share/fonts");
        r ~= Path("/usr/share/fonts");
        return r;
    }

    // Note: xdgRuntimeDir() left out in 2026, but it is in the 
    // original `standardpaths` package.
}