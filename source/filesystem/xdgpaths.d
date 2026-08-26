/**
 * Getting XDG base directories.
 * Note: These functions are defined only on freedesktop systems.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * Copyright:
 *  Roman Chistokhodov, 2016
 *  Guillaume Piolat, 2026
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * See_Also:
 *  $(LINK2 https://specifications.freedesktop.org/basedir-spec/latest/index.html, XDG Base Directory Specification)
 */

module filesystem.xdgpaths;

import nulib.collections.vector;
import nulib.string;

import filesystem.types;
import filesystem.path;
import filesystem.internals;

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

/+
version(D_Ddoc)
{
    /**
     * Path to runtime user directory.
     * Returns: User's runtime directory determined by $(B XDG_RUNTIME_DIR) environment variable.
     * If directory does not exist it tries to create one with appropriate permissions. On fail returns an empty string.
     */
    @trusted string xdgRuntimeDir() nothrow;

    /**
     * The ordered set of non-empty base paths to search for data files, in descending order of preference.
     * Params:
     *  subfolder = Subfolder which is appended to every path if not null.
     * Returns: Data directories, without user's one and with no duplicates.
     * Note: This function does not check if paths actually exist and appear to be directories.
     * See_Also: $(D xdgAllDataDirs), $(D xdgDataHome)
     */
    @trusted string[] xdgDataDirs(string subfolder = null) nothrow;

    /**
     * The ordered set of non-empty base paths to search for data files, in descending order of preference.
     * Params:
     *  subfolder = Subfolder which is appended to every path if not null.
     * Returns: Data directories, including user's one if could be evaluated.
     * Note: This function does not check if paths actually exist and appear to be directories.
     * See_Also: $(D xdgDataDirs), $(D xdgDataHome)
     */
    @trusted string[] xdgAllDataDirs(string subfolder = null) nothrow;

    /**
     * The ordered set of non-empty base paths to search for configuration files, in descending order of preference.
     * Params:
     *  subfolder = Subfolder which is appended to every path if not null.
     * Returns: Config directories, without user's one and with no duplicates.
     * Note: This function does not check if paths actually exist and appear to be directories.
     * See_Also: $(D xdgAllConfigDirs), $(D xdgConfigHome)
     */
    @trusted string[] xdgConfigDirs(string subfolder = null) nothrow;

    /**
     * The ordered set of non-empty base paths to search for configuration files, in descending order of preference.
     * Params:
     *  subfolder = Subfolder which is appended to every path if not null.
     * Returns: Config directories, including user's one if could be evaluated.
     * Note: This function does not check if paths actually exist and appear to be directories.
     * See_Also: $(D xdgConfigDirs), $(D xdgConfigHome)
     */
    @trusted string[] xdgAllConfigDirs(string subfolder = null) nothrow;

    /**
     * The base directory relative to which user-specific data files should be stored.
     * Returns: Path to user-specific data directory or empty string on error.
     * Params:
     *  subfolder = Subfolder to append to determined path.
     *  shouldCreate = If path does not exist, create directory using 700 permissions (i.e. allow access only for current user).
     * See_Also: $(D xdgAllDataDirs), $(D xdgDataDirs)
     */
    @trusted string xdgDataHome(string subfolder = null, bool shouldCreate = false) nothrow;

    /**
     * The base directory relative to which user-specific configuration files should be stored.
     * Returns: Path to user-specific configuration directory or empty string on error.
     * Params:
     *  subfolder = Subfolder to append to determined path.
     *  shouldCreate = If path does not exist, create directory using 700 permissions (i.e. allow access only for current user).
     * See_Also: $(D xdgAllConfigDirs), $(D xdgConfigDirs)
     */
    @trusted string xdgConfigHome(string subfolder = null, bool shouldCreate = false) nothrow;

    /**
     * The base directory relative to which user-specific non-essential files should be stored.
     * Returns: Path to user-specific cache directory or empty string on error.
     * Params:
     *  subfolder = Subfolder to append to determined path.
     *  shouldCreate = If path does not exist, create directory using 700 permissions (i.e. allow access only for current user).
     */
    @trusted string xdgCacheHome(string subfolder = null, bool shouldCreate = false) nothrow;
}
+/


private FilePerms privateMode = FilePerms.ownerAll;


vector!Path pathsFromEnvValue(const(nstring) envValue, 
                              char separator = ':',
                              nstring subfolder = nstring.init) /* nothrow */
{
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
                    result ~= path;                
            }
            lastSep = n;
        }
    }
    return result;
}

@("pathsFromEnvValue")
unittest
{
    vector!Path v = pathsFromEnvValue(nstring(""));
    assert(v.length == 0);
    v = pathsFromEnvValue(nstring(":"));

    assert(v.length == 0);
    v = pathsFromEnvValue(nstring("::"));
    assert(v.length == 0);

    v = pathsFromEnvValue(nstring("path1:path2"));
    assert(v.length == 2);
    
    assert(v[0] == Path("path1/"));
    assert(v[1] == Path("path2/"));

    v = pathsFromEnvValue(nstring("path2:path1:path2"));
    assert(v.length == 2);
    assert(v[0] == Path("path2/"));
    assert(v[1] == Path("path1/"));
}


vector!Path pathsFromEnv(nstring envName, 
                         char separator = ':',
                         nstring subfolder = nstring.init) 
    => pathsFromEnvValue(getEnvironmentVariable(envName), separator, subfolder);

version(none):

//
bool ensureExists(string dir) nothrow
{
    bool ok;
    try {
        ok = dir.exists;
        if (!ok) {
            mkdirRecurse(dir.dirName);
            ok = mkdir(dir.toStringz, privateMode) == 0;
        } else {
            ok = dir.isDir;
        }
    } catch(Exception e) {
        ok = false;
    }
    return ok;
}


private string xdgBaseDir(string envvar, string fallback, string subfolder = null, bool shouldCreate = false) nothrow 
{
    string dir;
    collectException(environment.get(envvar), dir);
    if (dir.length == 0) {
        string home;
        collectException(environment.get("HOME"), home);
        dir = home.length ? buildPath(home, fallback) : null;
    }

    if (dir.length == 0) {
        return null;
    }

    if (shouldCreate) {
        if (ensureExists(dir)) {
            if (subfolder.length) {
                string path = buildPath(dir, subfolder);
                try {
                    if (!path.exists) {
                        mkdirRecurse(path);
                    }
                    return path;
                } catch(Exception e) {

                }
            } else {
                return dir;
            }
        }
    } else {
        return buildPath(dir, subfolder);
    }
    return null;
}

version(unittest) {
    void testXdgBaseDir(string envVar, string fallback) {
        auto newDataHome = "/home/myuser/data";
        auto dataHomeGuard = EnvGuard(envVar, newDataHome);
        environment[envVar] = newDataHome;
        assert(xdgBaseDir(envVar, fallback) == newDataHome);
        assert(xdgBaseDir(envVar, fallback, "applications") == buildPath(newDataHome, "applications"));

        environment.remove(envVar);
        auto newHome = "/home/myuser";
        auto homeGuard = EnvGuard("HOME", newHome);
        assert(xdgBaseDir(envVar, fallback) == buildPath(newHome, fallback));
        assert(xdgBaseDir(envVar, fallback, "icons") == buildPath(newHome, fallback, "icons"));

        environment.remove("HOME");
        assert(xdgBaseDir(envVar, fallback).empty);
        assert(xdgBaseDir(envVar, fallback, "mime").empty);
    }
}

@trusted string[] xdgDataDirs(string subfolder = null) nothrow
{
    auto result = pathsFromEnv("XDG_DATA_DIRS", subfolder);
    if (result.length) {
        return result;
    } else {
        return [buildPath("/usr/local/share", subfolder), buildPath("/usr/share", subfolder)];
    }
}

///
unittest
{
    auto dataDirsGuard = EnvGuard("XDG_DATA_DIRS", "/usr/local/data:/usr/data:/usr/local/data/:/usr/data/");
    auto newDataDirs = ["/usr/local/data", "/usr/data"];

    assert(xdgDataDirs() == newDataDirs);
    assert(equal(xdgDataDirs("applications"), newDataDirs.map!(p => buildPath(p, "applications"))));

    environment.remove("XDG_DATA_DIRS");
    assert(xdgDataDirs() == ["/usr/local/share", "/usr/share"]);
    assert(equal(xdgDataDirs("icons"), ["/usr/local/share", "/usr/share"].map!(p => buildPath(p, "icons"))));
}

@trusted string[] xdgAllDataDirs(string subfolder = null) nothrow
{
    string dataHome = xdgDataHome(subfolder);
    string[] dataDirs = xdgDataDirs(subfolder);
    if (dataHome.length) {
        return dataHome ~ dataDirs;
    } else {
        return dataDirs;
    }
}

///
unittest
{
    auto newDataHome = "/home/myuser/data";
    auto newDataDirs = ["/usr/local/data", "/usr/data"];

    auto homeGuard = EnvGuard("HOME", "");
    auto dataHomeGuard = EnvGuard("XDG_DATA_HOME", newDataHome);
    auto dataDirsGuard = EnvGuard("XDG_DATA_DIRS", "/usr/local/data:/usr/data");

    assert(xdgAllDataDirs() == newDataHome ~ newDataDirs);

    environment.remove("XDG_DATA_HOME");
    environment.remove("HOME");

    assert(xdgAllDataDirs() == newDataDirs);
}

@trusted string[] xdgConfigDirs(string subfolder = null) nothrow
{
    auto result = pathsFromEnv("XDG_CONFIG_DIRS", subfolder);
    if (result.length) {
        return result;
    } else {
        return [buildPath("/etc/xdg", subfolder)];
    }
}

///
unittest
{
    auto dataConfigGuard = EnvGuard("XDG_CONFIG_DIRS", "/usr/local/config:/usr/config");
    auto newConfigDirs = ["/usr/local/config", "/usr/config"];

    assert(xdgConfigDirs() == newConfigDirs);
    assert(equal(xdgConfigDirs("menus"), newConfigDirs.map!(p => buildPath(p, "menus"))));

    environment.remove("XDG_CONFIG_DIRS");
    assert(xdgConfigDirs() == ["/etc/xdg"]);
    assert(equal(xdgConfigDirs("autostart"), ["/etc/xdg"].map!(p => buildPath(p, "autostart"))));
}

@trusted string[] xdgAllConfigDirs(string subfolder = null) nothrow
{
    string configHome = xdgConfigHome(subfolder);
    string[] configDirs = xdgConfigDirs(subfolder);
    if (configHome.length) {
        return configHome ~ configDirs;
    } else {
        return configDirs;
    }
}

///
unittest
{
    auto newConfigHome = "/home/myuser/data";
    auto newConfigDirs = ["/usr/local/data", "/usr/data"];

    auto homeGuard = EnvGuard("HOME", "");
    auto configHomeGuard = EnvGuard("XDG_CONFIG_HOME", newConfigHome);
    auto configDirsGuard = EnvGuard("XDG_CONFIG_DIRS", "/usr/local/data:/usr/data");

    assert(xdgAllConfigDirs() == newConfigHome ~ newConfigDirs);

    environment.remove("XDG_CONFIG_HOME");
    environment.remove("HOME");

    assert(xdgAllConfigDirs() == newConfigDirs);
}

@trusted string xdgDataHome(string subfolder = null, bool shouldCreate = false) nothrow {
    return xdgBaseDir("XDG_DATA_HOME", ".local/share", subfolder, shouldCreate);
}

unittest
{
    testXdgBaseDir("XDG_DATA_HOME", ".local/share");
}

@trusted string xdgConfigHome(string subfolder = null, bool shouldCreate = false) nothrow {
    return xdgBaseDir("XDG_CONFIG_HOME", ".config", subfolder, shouldCreate);
}

unittest
{
    testXdgBaseDir("XDG_CONFIG_HOME", ".config");
}

@trusted string xdgCacheHome(string subfolder = null, bool shouldCreate = false) nothrow {
    return xdgBaseDir("XDG_CACHE_HOME", ".cache", subfolder, shouldCreate);
}

unittest
{
    testXdgBaseDir("XDG_CACHE_HOME", ".cache");
}

version(XdgPathsRuntimeDebug) {
    private import std.stdio;
}

@trusted string xdgRuntimeDir() nothrow // Do we need it on BSD systems?
{
    import std.exception : assumeUnique;
    import core.sys.posix.pwd;

    try { //one try to rule them all and for compatibility reasons
        const uid_t uid = getuid();
        string runtime;
        collectException(environment.get("XDG_RUNTIME_DIR"), runtime);

        if (!runtime.length) {
            passwd* pw = getpwuid(uid);

            try {
                if (pw && pw.pw_name) {
                    runtime = tempDir() ~ "/runtime-" ~ assumeUnique(fromStringz(pw.pw_name));

                    if (!(runtime.exists && runtime.isDir)) {
                        if (mkdir(runtime.toStringz, privateMode) != 0) {
                            version(XdgPathsRuntimeDebug) stderr.writefln("Failed to create runtime directory %s: %s", runtime, fromStringz(strerror(errno)));
                            return null;
                        }
                    }
                } else {
                    version(XdgPathsRuntimeDebug) stderr.writeln("Failed to get user name to create runtime directory");
                    return null;
                }
            } catch(Exception e) {
                version(XdgPathsRuntimeDebug) collectException(stderr.writefln("Error when creating runtime directory: %s", e.msg));
                return null;
            }
        }
        stat_t statbuf;
        stat(runtime.toStringz, &statbuf);
        if (statbuf.st_uid != uid) {
            version(XdgPathsRuntimeDebug) collectException(stderr.writeln("Wrong ownership of runtime directory %s, %d instead of %d", runtime, statbuf.st_uid, uid));
            return null;
        }
        if ((statbuf.st_mode & octal!777) != privateMode) {
            version(XdgPathsRuntimeDebug) collectException(stderr.writefln("Wrong permissions on runtime directory %s, %o instead of %o", runtime, statbuf.st_mode, privateMode));
            return null;
        }

        return runtime;
    } catch (Exception e) {
        version(XdgPathsRuntimeDebug) collectException(stderr.writeln("Error when getting runtime directory: %s", e.msg));
        return null;
    }
}

