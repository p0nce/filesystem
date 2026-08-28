/**
    Getting XDG base directories.
    Note: These functions are defined only on freedesktop systems.

    Reference: 
        https://specifications.freedesktop.org/basedir/latest/

    Authors:
        Roman Chistokhodov <https://github.com/FreeSlave>
 
    Copyright:
        Copyright (c) 2016, Roman Chistokhodov.
        Copyright (c) 2026, Guillaume Piolat.

    License:
        $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
*/

module filesystem.xdgpaths;

import nulib.collections.vector;
import nulib.string;
import nulib.memory;
import nulib.io.stream.file;

import filesystem.types;
import filesystem.freefunc;
import filesystem.path;
import filesystem.internals;
import filesystem.standardpaths;

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

static if (isFreedesktop):
@nogc:


/**
    The ordered set of non-empty base paths to search for :
    data files, config, or cache files, in descending order of 
    preference.
    
    Note: This function does not check if paths actually exist and 
        appear to be directories.

*/
vector!Path xdgDataDirs(string subfolder = null) @trusted
{
    vector!Path r = pathsFromEnv("XDG_DATA_DIRS", ':', nstring(subfolder));
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
    vector!Path r = pathsFromEnv("XDG_CONFIG_DIRS", ':', nstring(subfolder));
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


vector!Path pathsFromEnvValue(const(nstring) envValue, 
                              char separator = ':',
                              nstring subfolder = nstring.init) /* nothrow */
{
    // Note: relative path are filtered out, as per-spec:
    // 
    // "All paths set in these environment variables must be absolute. 
    //  If an implementation encounters a relative path in any of these 
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

vector!Path pathsFromEnv(const(char)[] envName, 
                         char separator = ':',
                         nstring subfolder = nstring.init) 
    => pathsFromEnvValue(getEnvironmentVariable(envName), separator, subfolder);


Path xdgBaseDir(string envvar, 
                string fallback, 
                string subfolder = null, 
                bool shouldCreate = false) @trusted
{
    // First look at hypothetical envvar
    Path dir = Path(getEnvironmentVariable(envvar));

    // Fallback inside ~/<fallback> if no such envvar
    if (dir.empty)
        dir = Path(getEnvironmentVariable(nstring("HOME"))).maybeAppend(fallback);

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
    Path fileName = writablePath(StandardPath.config).maybeAppend("user-dirs.dirs");
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
        // TODO: be more specific
    }

    // Didn't find such a directory in user-dirs.dirs

    if (home.length) 
    {
        try 
        {
            auto path = getFromDefaultDirs(key, home, Path("/etc/xdg/user-dirs.defaults"));
            if (path.length)
                return path;
        } 
        catch (FileSystemException e) 
        {
            // typically: file doesn't exist, or couldn't be accessed
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

// Note: xdgRuntimeDir() left out in 2026, but it is in the original
// standardpaths package.
