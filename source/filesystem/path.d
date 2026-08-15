/**
    Path manipulation

    Copyright: Guillaume Piolat 2026.
    License: MIT (https://mit-license.org/)
*/
module filesystem.path;

import numem;
import nulib;
import nulib.collections.vector;

@nogc:

/**
    Objects of type path represent paths on a filesystem. Only 
    syntactic aspects of paths are handled: the pathname may represent
    a non-existing path or even one that is not allowed to exist on 
    the current file system or OS.

    See the free functions in package.d if you need access to the OS
    (eg: current directory, absolute path without a base...).

    A path is mostly like a string, that could be valid or not, 
    in a native-compatible format or not.

    `std::filesystem` speaks of a generic format (subset of both
    POSIX and Windows valid path), which is to be preferred when 
    unsure.

    In our case we choose to detect a preferred directory separator
    from input and use that in further operations. A native-compatible
    path can be obtained with `.native()` which can be NOT still 
    be used in `fopen` since `fopen` doesn't accept UTF-8 on Windows.

    On POSIX systems, the generic format is the native format and 
    there is no need to distinguish or convert between them. 
*/
struct Path
{
public:
@nogc:


    nstring str;
    alias this = str;

    this(const(char)[] source) pure
    {
        str = source;
    }
    this(const(nstring) source) pure
    {
        str = source;
    }

    //
    // DECOMPOSITION
    //

    /**
        Returns the root name of the path. If the path does not include root name, returns ""
    */
    Path rootName() pure const
    {
        PathParser parser;
        parser.initialize(str[]);
        const(char)[] rootName;
        parser.parseRootName(rootName);
        return Path(rootName);
    }

    /**
        Returns the root directory of the path. If the path does not include root directory, returns ""
    */
    Path rootDirectory() pure const
    {
        PathParser parser;
        parser.initialize(str[]);
        const(char)[] rootDir;
        parser.parseRootName(rootDir);
        parser.parseRootDir(rootDir);
        return Path(rootDir);
    }

    /**
        Returns the root path of the path, if present.
    */
    Path rootPath() => rootName / rootDirectory;

    /**
        Returns path relative to root-path, that is, a pathname 
        composed of every generic-format component of this after 
        root-path. If this is an empty path, returns an empty path. 

    */
    Path relativePath() pure const
    {
        PathParser parser;
        parser.initialize(str[]);
        const(char)[] dummy;
        parser.parseRootName(dummy);
        parser.parseRootDir(dummy);
        const(char)[] name;
        nstring r;
        bool sep;
        while (parser.parseFilename(name, sep))
        {
            r ~= name;
            if (sep) r ~= "/"; // TODO this is wrong should be preferred char
        }
        return Path(r);
    }

    /**
        Returns the path to the parent directory.

        If `hasRelativePath()` returns false, the result is a copy 
        of this. Otherwise, the result is a path whose generic format 
        pathname is the longest prefix of the generic format pathname 
        of this that produces one fewer element in its iteration.

        Warning: this is up to spec, but the spec function looks a bit
                 weird... parent path of "my/path/" is "my/path" since
                 the last separator is returned by the iterator.
    */
    Path parentPath() pure const
    {
        if (!hasRelativePath())
            return Path(str);
        auto range = iterate();
        int skipSlash = 1;
        if (range.hasRootName) skipSlash++;
        if (range.hasRootDir) skipSlash++;
        size_t lastLen;
        nstring r;
        foreach(item; range)
        {
            lastLen = r.length;
            if (skipSlash > 0)
                skipSlash--;
            else
                r ~= "/";
            r ~= item;
        }
        return Path(r.ptr[0..lastLen]);
    }

    /**
        Based upon the content of this path, what directory separator
        should be used?
    */
    SepPreference detectSeparator() pure
    {
        PathParser parser;
        parser.initialize(str[]);
        const(char)[] dummy;
        parser.parseRootName(dummy);
        parser.parseRootDir(dummy);
        bool sep;
        while (parser.parseFilename(dummy, sep))
        {
        }
        if (parser.errored)
            return SepPreference.preferUnknown;
        return parser.sepPreference;
    }

    char detectSeparatorOrDefault() pure => prefToChar(detectSeparator);  

    /**
        Returns the generic-format filename component of the path.
    */
    Path filename() pure const
    {
        if (!hasRelativePath)
            return Path();
        const(char)[] r = "";
        foreach(item; iterate())
        {
            r = item;
        }
        return Path(r);
    }

    /**
        Returns the filename identified by the generic-format path 
        stripped of its extension. 
    */
    Path stem() pure const
    {
        Path fn = filename();
        int dotpos = extensionDotPos(fn);
        if (dotpos == -1)
            return Path(fn);
        return Path(fn.ptr[0..dotpos]);
    }

    Path extension() pure const
    {
        Path fn = filename();
        int dotpos = extensionDotPos(fn);
        if (dotpos == -1)
            return Path();
        size_t len = fn.length;
        return Path(fn.ptr[dotpos..len]);
    }   

    /**
        Returns the internal pathname in native UTF-8 pathname format.
    */
    nstring native() pure const
    {
        // TODO: in Windows paths, disallow to finish by a '.'
        // TODO: check for MAX_PATH, or add \\?\ and check for longer length
        // validate if a native path, use throwInvalidPath if invalid.

        version(Windows)
            return replaceCharStr(str, '/', '\\');
        else
            return str;
    }

    /**
        Returns the internal pathname in generic pathname format.
    */
    nstring generic() pure const
    {
        version(Windows)
            return replaceCharStr(str, '\\', '/');
        else
            return str;
    }

    //
    // ITERATION
    //

    /**
        Break down path in parts.

        c:\Users\toto    => ["c:", "\", "Users", "toto"]
        a/relative/path/ => ["a", "relative", "path", ""]

        Returns: an `InputRange` of `const(char)[]`.
    */
    PathRange iterate() pure const
    {
        PathRange r;
        r.initialize(str);
        return r;
    }

    /**
        Break down path in parts, but skip the root path.

        c:\Users\toto    => ["Users", "toto"]
        a/relative/path/ => ["a", "relative", "path", ""]

        Returns: an `InputRange` of `const(char)[]`.
    */
    PathRange iterateWithoutRootPath()
    {
        PathRange range = iterate();
        int skipSlash = 1;
        if (range.hasRootName) range.popFront();
        if (range.hasRootDir) range.popFront();
        return range;
    }

    //
    // QUERIES
    //

    /// Check if the path is empty.
    bool empty()            pure const => str             == "";
    bool hasRootName()      pure const => rootName()      != "";
    bool hasRootDirectory() pure const => rootDirectory() != "";
    bool hasRelativePath()  pure const => relativePath()  != "";
    bool hasParentPath()    pure const => parentPath()    != "";
    bool hasFilename()      pure const => filename()      != "";
    bool hasStem()          pure const => stem()          != "";
    bool hasExtension()     pure const => extension()     != "";

    /**
        Checks whether the path is absolute or relative. An absolute 
        path is a path that unambiguously identifies the location of 
        a file without reference to an additional starting location.
    */
    bool isAbsolute() pure
    {
        version(Windows)
            return hasRootName() && hasRootDirectory();
        else
            return hasRootDirectory();        
    }

    //ditto
    bool isRelative() pure => ! isAbsolute();


    //
    // MODIFIERS
    //
    void clear() pure
    {
        str.clear();
    }

    /**
        Converts all directory separators in the generic-format view 
        of the path to the preferred directory separator. 
    */
    ref Path makePreferred() pure
    {
        str = native();
        return this;
    }

    ref Path removeFilename() pure
    {
        if (hasFilename()) 
        {
            size_t newLen = str.length() - filename().length();
            resize(newLen);
        }
        return this;
    }

    /**
        Replaces a single filename component with replacement. 
    */
    ref Path replaceFilename(const Path replacement) /* pure */
    {
        removeFilename(); 
        return this /= replacement;
    }
    ///ditto
    ref Path replaceFilename(const(char)[] replacement) /* pure */
        => replaceFilename(Path(replacement));

    /**
        Replaces extension (eg: ".png"). 
    */
    ref Path replaceExtension(Path replacement) /* pure */
    {
        Path f = stem();
        if (replacement.length > 0 && replacement[0] != '.')
            f.concat(".");
        f.concat(replacement);
        return replaceFilename(f);
    }
    ///ditto
    ref Path replaceExtension(const(char)[] replacement = "") /* pure */
        => replaceExtension(Path(replacement));

    // 
    // Generation
    //

    /**
        These conversions are purely lexical. They do not check that 
        the paths exist, do not follow symlinks, and do not access the 
        filesystem at all. For symlink-following counterparts of 
        `lexicallyNormal` and `lexicallyRelative`, see `relative` and 
        `proximate`. 
    */
    Path lexicallyNormal() /* pure */ /* const */
        => Path(normalForm());
        
    /**
        Relative form of the path, given a base.
    */
    Path lexicallyRelative(Path base) /* pure */ /* const */
    {
        if (rootName != base.rootName())
            return Path();
        if (isAbsolute() != base.isAbsolute())
            return Path();
        if (!hasRootDirectory() && base.hasRootDirectory())
            return Path();

        char prefSep = detectSeparatorOrDefault();

        // TODO
        //or any filename in relative_path() or base.relative_path() can be interpreted as a root-name, 

        // Note: it seems possible this has a root directory, and base 
        // doesn't and neither are absolute on Windows.
        // eg: this = "\directory" and base = "dir2"

        PathRange iterThis = iterate();
        PathRange iterBase = base.iterate();

        // Pull parts of the paths
        vector!nstring vthis; // PERF: vector of const(char)[]
        vector!nstring vbase;
        foreach (item; iterate())
            vthis ~= nstring(item);
        foreach (item; base.iterate())
            vbase ~= nstring(item);

        // Otherwise, first determines the first mismatched element of
        // this and base.
        size_t n = 0;
        while (n < vthis.length && n < vbase.length)
        {
            // TODO unicode lowercase compare here for Windows
            if (vthis[n] != vbase[n])
                break;
            ++n;
        }
        if (n == vthis.length && n == vbase.length)
            return Path(".");

        // Otherwise, define N as the number of nonempty filename 
        // elements that are neither dot nor dot-dot in vbase[n .. $]
        int N = 0;
        for (size_t i = n; i < vbase.length; ++i)
        {
            bool isDot    = vbase[i] == ".";
            bool isDotDot = vbase[i] == "..";
            if (isDotDot)    N -= 1;
            else if (!isDot) N += 1;
        }

        if (N < 0) return Path("");
        if (N == 0 && ((n == vthis.length) || vthis[n] == FINAL_DIR_SEP))
            return Path(".");
        
        Path result;

        // In order to preserve the preferred directory separator,
        // add a fake rootDir to result, only to remove it afterwards.
        result.str ~= prefSep;


        for (int i = 0; i < N; ++i)
            result.append("..");

        for (size_t i = n; i < vthis.length; ++i)
            result.append(vthis[i]);

        assert(result.str[0] == '/' || result.str[0] == '\\');
        result = Path(result.str[1..$]); // waiting for the nulib string opAssign fix
        return result;
    }
    //ditto
    Path lexicallyRelative(const(char)[] base) /* pure */ /* const */
        => lexicallyRelative(Path(base));

    /**
        Return `lexicallyRelative(base)` if not an empty path, else
        return this.
    */
    Path lexicallyProximate(Path base) /* pure */ /* const */
    {
        Path relative = lexicallyRelative(base);
        if (relative.empty) 
            return this;
        else
            return relative;
    }
    //ditto
    Path lexicallyProximate(const(char)[] base) /* pure */ /* const */
        => lexicallyProximate(Path(base));

    //
    // Concatenation and appending
    //

    /**
        Appends elements to the path with a directory separator (if needed).    
    */
    ref Path append(const(char)[] p) /* pure */
    {        
        return append(Path(p));
    }
    //ditto
    ref Path append(Path p) /* pure */
    {
        if (p.empty)
            return this;

        // First we try to find the right separator for this append.
        // If both have an idea, prefers left path idea.
        SepPreference leftPref = detectSeparator();
        SepPreference rightPref = p.detectSeparator();
        if (leftPref == SepPreference.preferUnknown) leftPref = rightPref;
        char prefferedSep = prefToChar(leftPref);

        if (p.isAbsolute() || (p.hasRootName() && p.rootName() != rootName()))
        {
            str = p;
            return this;
        }

        // Appending a root directory replaces relative path.
        // but keep it's eventual rootname.
        if (p.hasRootDirectory())
        {
            str = rootName() ~ p.rootDirectory() ~ p.relativePath();
            return this;
        }

        // Spec says:
        // "Appends path::preferred_separator to pathname unless:
        //  - an added separator would be redundant, or
        //  - would change a relative path (eg: "") to an absolute path
        //  - p.empty()
        //  - p has a root-directory 
        assert(!p.empty && !p.hasRootDirectory() && !p.isAbsolute());

        // p is of form "a/b" or "c:a/b", with optional rootName
        assert(p.hasFilename());
        // Do not change relative path into absolute path
        // This would happen for: "c:" => "c:\"
        bool needSep = true;

        if (hasRootName() && !hasRootDirectory() && !hasFilename())
            needSep = false;

        // Would change "" to an absolute path
        if (str == "")
            needSep = false;

        // Would a separator be redundant? This would happen
        // for: "c:\" or "/"
        if (hasRootDirectory() && !hasFilename())
            needSep = false;


        // "c:foo" / "c:bar" doit ajout /
        if (needSep)
            str ~= prefferedSep;

        str ~= Path(p.native()).relativePath();

        return this;
    }
    ///ditto
    ref Path opOpAssign(string op : "/")(Path p) /* pure */
    {
        append(p);
        return this;
    }
    ///ditto
    ref Path opOpAssign(string op : "/")(const(char)[] p) /* pure */
    {
        append(p);
        return this;
    }
    ///ditto
    Path opBinary(string op : "/")(Path p) /* pure */ const
    {
        Path r = str;
        r.append(p);
        return r;
    }
    ///ditto
    Path opBinary(string op : "/")(const(char)[] p) /* pure */ const
    {
        Path r = str;
        r.append(p);
        return r;
    }

    /**
        Concatenates the current path and the argument.
    */
    ref Path concat(Path p) /* pure */
    {
        str ~= p.native();
        return this;
    }
    ///ditto
    ref Path concat(const(char)[] p) /* pure */
        => concat(Path(p));

    


private:

    // How the final directory separator is represented
    enum const(char)[] FINAL_DIR_SEP = "";

    static int extensionDotPos(const(char)[] filename) pure
    {
        if (filename == "." || filename == "..")
            return -1;

        // Try to find the last '.'
        // Can't be the first char of filename.
        int dotPos = -1;
        for (int n = 1; n < filename.length; ++n)
            if (filename[n] == '.')
                dotPos = n;
        return dotPos;
    }

    // Return same string with one char replaced
    static nstring replaceChar(const(char)[] s, char needle, char replacement) pure
    {
        if (s is null)
            return nstring();

        if (needle == replacement)
            return nstring(s);

        char[] r;
        r.nu_resize(s.length);
        scope(exit) r.nu_resize(0);

        foreach(i; 0..s.length)
            if (s[i] == needle)
                r[i] = replacement;
            else
                r[i] = s[i];

        return nstring(r);
    }
    static nstring replaceCharStr(string s, char needle, char replacement) pure
    {
        if (s is null)
            return nstring();
        return replaceChar(s.ptr[0..s.length], needle, replacement);
    }

    nstring normalForm() /* const */
    {
        // Note: making this function pure is blocked by vector!nstring 
        // not being pure.

        // 1. Empty path is already normalized.
        if (str.empty) return nstring();

        // Because in the test suite, some path keeps their forward 
        // slash on Windows! Not possible to follow the spec in this case.
        char prefSep = detectSeparatorOrDefault();

        PathParser parser;
        parser.initialize(str[]);
        const(char)[] root_name, root_dir;
        parser.parseRootName(root_name);
        parser.parseRootDir(root_dir);
        const(char)[] name;

        // Extract whole path except root-name and root-dir
        vector!nstring parts;
        {
            bool sep;
            bool lastSep;
            while (parser.parseFilename(name, sep))
            {
                parts ~= replaceChar(name, '/', prefSep);
                lastSep = sep;
            }
            if (lastSep)
                parts ~= nstring(FINAL_DIR_SEP);
        }

        // 2. "Replace each directory-separator (which may consist of 
        // multiple slashes) with a single preferred separator."
        // => happens implicitely

        // 3. "Replace each slash character in the root-name with 
        // preferred separator". Note: we also do it for root-dir.
        nstring sroot_name = replaceChar(root_name, '/', prefSep);
        nstring sroot_dir  = replaceChar(root_dir, '/', prefSep);

        // 4. "Remove each dot and any immediately following 
        // directory-separator."
        // This removes all single dots.
        {
            size_t i = 0;
            for (i = 0; i < parts.length; )
            {
                if (parts[i] == ".")
                {
                    parts.removeAt(i);

                    // remove final / if path is ending in ./ 
                    if (i < parts.length && parts[i] == FINAL_DIR_SEP)
                        parts.removeAt(i);
                }
                else
                    ++i;
            }
        }
 
        // 5. "Remove each non-dot-dot filename immediately followed 
        // by a directory-separator and a dot-dot, along with any 
        // immediately following directory-separator."
        // What the spec doesn't say is that this must be done as a 
        // fixed point.
        {
            size_t i = 0;
            for (; i + 1 < parts.length; )
            {
                // Tricky since "a/b/../"  => "a/"
                //              "a/../"    => ""
                //              "a/b/.."   => "a/"
                //              "a/b/../c" => "a/c"

                if ((parts[i] != "..") && (parts[i + 1] == ".."))
                {
                    parts.removeAt(i);
                    parts.removeAt(i);

                    bool hasFilenameBefore = i > 0;
                    bool dotdotWasFollowedByFinalSep = i < parts.length && parts[i] == FINAL_DIR_SEP;
                    bool shouldHaveFinalSep = hasFilenameBefore;
                    if (i < parts.length && parts[i] != FINAL_DIR_SEP)
                        shouldHaveFinalSep = false;

                    if (dotdotWasFollowedByFinalSep && !shouldHaveFinalSep)
                        parts.removeAt(i);
                    if (!dotdotWasFollowedByFinalSep && shouldHaveFinalSep)
                        parts ~= nstring(FINAL_DIR_SEP);
                    
                    if (i > 0) i -= 1; // step back in case .. chain
                }
                else
                    i++;
            }
        }


        // 6. "If there is root-directory, remove all dot-dots and any 
        // directory-separators immediately following them."
        if (sroot_dir != "")
        {
            while (parts.length > 0 && parts[0] == "..")
                parts.removeAt(0);
            if (parts.length > 0 && parts[0] == FINAL_DIR_SEP)
                parts.removeAt(0);

        }

        // 7. "If the last filename is dot-dot, remove any trailing 
        // directory-separator."
        if (parts.length >= 2 && parts[$-2] == ".." && parts[$-1] == FINAL_DIR_SEP)
            parts.removeAt(parts.length - 1);

        // Build result
        nstring result;
        result ~= sroot_name;
        result ~= sroot_dir;
        for (size_t i = 0; i < parts.length; ++i)
        {
            if (i > 0)
                result ~= prefSep;
            result ~= parts[i];
        }

        // "8. If the path is empty, add a dot"
        if (result == "")
            result ~= '.';

        return result;
    }
}


// A parser iterator that correspond to the std::filesystem iterator.
// Returns successively: 
// 1. root-name if any, 
// 2. root-dir if any, 
// 3. then a list of filename
// 4. then an empty item "" if the path was terminated with a separator
static struct PathRange
{
nothrow:
@nogc:
pure:

    PathParser parser;
    const(char)[] rootName;
    const(char)[] rootDir;
    const(char)[] current;
    bool lastSep;
    bool hasRootName; // useful to skip a number of slash when
    bool hasRootDir;  // recreating a path

    void initialize(const(char)[] str)
    {
        parser.initialize(str);
        parser.parseRootName(rootName);
        hasRootName = rootName !is null;
        parser.parseRootDir(rootDir);
        hasRootDir = rootDir !is null;
        lastSep = false;
        popIntoCurrent(); // fetch first item in current
    }

    const(char)[] front()
    {
        return current;
    }

    void popFront()
    {
        popIntoCurrent();
    }

    bool empty()
    {
        return current is null;
    }

    // progress state, fetch next item in current
    void popIntoCurrent()
    {
        if (rootName !is null)
        {
            current = rootName;
            rootName = null;
            return;
        }

        if (rootDir !is null)
        {
            current = rootDir;
            rootDir = null;
            return;
        }

        // save previous / presence, in case it was the last
        bool oldLastSep = lastSep;
        bool success = parser.parseFilename(current, lastSep);
        if (success)
        {
            return;
        }

        if (!success && oldLastSep)
        {
            current = Path.FINAL_DIR_SEP;
            return;
        }
        current = null;
    }
}

// Grammar of path.
// PATH := [ROOT-NAME][ROOT-DIRECTORY](FILE-NAME | DIRECTORY-SEPARATOR)
// Reference: https://en.cppreference.com/cpp/filesystem/path
struct PathParser
{
nothrow:
@nogc:
pure:

    // Once initialized, call parseRootName, parseRootDir, and enumerate path parts.
    void initialize(const(char)[] input)
    {
        errored = false;
        lexer.initialize(input);
    }

    // return null if not root name
    void parseRootName(out const(char)[] rootName)
    {
        Token tok;
        if (lexer.consume(Token.type.rootName, tok))
            rootName = tok.payload;
        else
            rootName = null;
    }

    // return null if not root dir
    void parseRootDir(out const(char)[] rootDir)
    {
        Token tok;
        if (lexer.consume(Token.type.rootDir, tok))
            rootDir = "/"; // Note: payload ignored, it could be /// or `\\`.
        else
            rootDir = null;
    }

    // Return the next filename in the path.
    // eg: /my/path will return "my", "path", then false.
    // Return false in case of end of sequence or error.
    // Can only be called once parseRootName and parseRootDir were
    // called.
    bool parseFilename(out const(char)[] filename, out bool followedBySep)
    {
        followedBySep = false;
        Token tok = lexer.peek();
        final switch (tok.type)
        {
            case Token.type.rootName: 
            case Token.type.rootDir: 
            case Token.type.invalid:                
                assert(0); // this is impossible

            case Token.type.separator: // Weird separator location
                errored = true;
                return false;

            case Token.type.poison: // error encountered
                errored = true;
                return false;

            case Token.type.eof: // no more input
                return false;

            case Token.type.filename: // no more input
                filename = tok.payload;
                lexer.popFront();
        }

        // MUST consume either a separator, or EOF.

        tok = lexer.peek();
        final switch (tok.type)
        {
            case Token.type.rootName: 
            case Token.type.rootDir: 
            case Token.type.invalid:
                assert(0); // this is impossible

            case Token.type.eof: // no more input
                return true;

            case Token.type.filename: 
                // this should be impossible, through I'm not sure
                errored = true;                
                return false;

            case Token.type.poison: // error encountered
                errored = true;
                return false;

            case Token.type.separator: // Regular separator location
                lexer.popFront();
                followedBySep = true;
                return true;
        }
    }


    bool errored;
    SepPreference sepPreference() const => lexer.sepPreference();


    PathLexer lexer;

}


struct Token
{
nothrow @nogc:
    enum Type
    {
        rootName,  // 0. eg: "C:", "//server/share"
        rootDir,   // 1. the first / or \. Not sure if it should be return as separate token from separator...
        separator, // 2. a separator such as in my/dir
        filename,  // 3. normal folder or file segment, ., or ..
        eof,       // 4. end of input, no payload
        poison,    // 5. Error while parsing, no payload
        invalid,   // 6. Used for lexer initialization, no payload
    }

    Type type             = Type.invalid;
    const(char)[] payload = null; // extent of this token in input string
}



struct PathLexer
{
pure:
public:
nothrow @nogc:

    // Note: lexer is, for now, only used in 

    enum
    {
        // First two bits is parse mode
        parsePOSIX       = 1, // only accept POSIX-style paths
        parseWindows     = 2, // only accept windows-style paths
        parseAutodetect  = 3, // support **both** until unambiguous, 
                              // when it can
    }



    // Safari doesn't accept a longer URL than that.
    enum int MAX_PATH_PATH = 80_000; 

    void initialize(const(char)[] input)
    {   
        version(Windows)
        {
            options = parseWindows;
            _sepPreference = SepPreference.preferUnknown;
        }
        else
        {
            options = parsePOSIX;
            _sepPreference = SepPreference.preferSlash;
        }

        this.idx = 0;
        _token = Token.init;
        if (input.length > MAX_PATH_PATH)
            state = State.error; // error, too long path, this is unlikely
        this.len = cast(int) input.length;
        this.input = input;
        this.options = options;
        state = State.beforeRootName;
    }

    // peek current token. When you see Token.Type.eof or Token.Type.poison, it is over.
    Token peek()
    {
        if (_token.type == Token.Type.invalid)
            popFront();
        return _token;
    }

    bool consume(Token.Type type, out Token tok)
    {
        tok = peek();
        if (tok.type == type)
        {
            popFront();
            return true;
        }
        else
            return false;
    }

    void popFront()
    {
        _token = nextToken();
    }

    SepPreference sepPreference() const
    {
        return _sepPreference;
    }    

private:

    
    SepPreference _sepPreference = SepPreference.preferUnknown;

    static int findCharInString(char needle, const(char)[] chars)
    {
        for (int i = 0; i < cast(int) chars.length; ++i)
            if (chars[i] == needle)
                return i;
        return -1;
    }

    static bool isCharInString(char needle, const(char)[] chars)
        => findCharInString(needle, chars) != -1;

    bool charCanBeASeparator(char ch)
        => ch == '/' || (supportsBackSlash() && ch == '\\');

    static bool charCanBeWindowsFilename(char ch)
    {
        return ! isCharInString(ch, "<>:\"/\\|?*\0"); // FUTURE: ':' is allowed with "data streams"
    }

    static bool charCanBePOSIXFilename(char ch)
    {
        return ch != '\0' && ch != '/';
    }

    // Return: number of successive identical separator chars, such as "///" => 3
    // 0 if no separator.
    int parseSeparator()
    {        
        char ch = peekChar();
        if (! charCanBeASeparator(ch))
            return 0;
        next();
        if (ch == '\\') 
        {
            if (_sepPreference == SepPreference.preferUnknown)
                _sepPreference = SepPreference.preferBackslash;
        }
        else
        {
            assert(ch == '/');
            if (_sepPreference == SepPreference.preferUnknown)
                _sepPreference = SepPreference.preferSlash;
        }

        // Parse mixed separators such as "\\//\\", as one separator
        int r = 1;
        while (charCanBeASeparator(peekChar()))
        {
            r++;
            next();
        }
        return r;
    }

    Token nextToken()
    {
        if (state == State.error)
            return Token(Token.Type.poison);
        
        // detect optional root name
        if (state == State.beforeRootName)
        {
            state = State.beforeRootDir; // move on the state whatever happens
            char ch = peekChar();
            char chp1 = peekAhead();            
            if (supportsRootName() && (chp1 == ':') && isDriveLetter(ch))
            {
                next();
                next();
                windowsPathDetected();
                return Token(Token.Type.rootName, input[0..2]);
            }
            // TODO: more rootname in Windows, such as //server/share and //?\
        }

        // detect optional root dir / or \
        if (state == State.beforeRootDir)
        {
            state = State.restOfPath; // move on the state whatever happens

            // length of the separator, if any.
            int before = idx;
            int len = parseSeparator();
            if (len > 0)
            {
                return Token(Token.Type.rootDir, input[before..before+len]);
            }
        }

        assert(state == State.restOfPath);

        int start = idx;

        // First deal with the separator case and '\0'
        char ch = peekChar();
        if (ch == '\0')
            return Token(Token.Type.eof);

        bool isSep = charCanBeASeparator(ch);

        if (isSep)
        {
            int len = parseSeparator();
            assert(len > 0);
            return Token(Token.Type.separator, input[start..start+len]);
        }        

        bool isWin   = charCanBeWindowsFilename(ch);
        bool isPosix = charCanBePOSIXFilename(ch);

        if (!isWin && !isPosix)
        {
        fail:
            state = State.error;
            return Token(Token.Type.poison);
        }

        next();

        int end = start + 1;
        

        while (true)
        {
            ch = peekChar();
            isSep   = charCanBeASeparator(ch);
            isWin   = charCanBeWindowsFilename(ch);
            isPosix = charCanBePOSIXFilename(ch);

            // exit parse of file-name
            if (isSep || ch == '\0' || (!isWin && !isPosix))
                break;

            if (isWindowsOnly() && !isWin) goto fail;
            if (isPOSIXOnly()   && !isPosix) goto fail;
            if (isAutodetect())
            {
                if (!isPosix) windowsPathDetected();
                if (!isWin) posixPathDetected();
            }
            next;
            end++;
        }
        return Token(Token.Type.filename, input[start..end]);    
    }

private:

    Token _token;

    char peekChar() const
    {
        if (idx >= len) return '\0';
        return input[idx];
    }

    char peekAhead() const
    {
        if (idx + 1 >= len) return '\0';
        return input[idx + 1];
    }

    bool consumeChar(char ch)
    {
        char c = peekChar();
        if (c == ch) 
        {
            next();
            return true;
        }
        else
            return false;
    }

    void next() { idx += 1; }

    const(char)[] input;
    int idx;
    int len;
    int options;

    enum State
    {
        beforeRootName,
        beforeRootDir,
        restOfPath,    // normal parts and separator
        error,         // only output poison now.
    }

    State state;

    alias supportsBackSlash = supportsWindows;
    alias supportsRootName = supportsWindows;
    bool supportsWindows()  => (options & parseWindows) != 0;
    bool supportsPOSIX()    => (options & parsePOSIX) != 0;
    bool isWindowsOnly()    => (options == parseWindows);
    bool isPOSIXOnly()      => (options == parsePOSIX);
    bool isAutodetect()     => (options == parsePOSIX + parseWindows);

    void windowsPathDetected()
    {
        options = options & ~parsePOSIX; // change parse to WIndows-only
    }

    void posixPathDetected()
    {
        options = options & ~parseWindows; // change parse to POSIX-only
    }

    static bool isDriveLetter(char ch) => (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');

}

private:

enum SepPreference
{
    preferSlash      = 1,  // path earliest separator is /
    preferBackslash  = 2,  // path earliest separator is \ (impossible on POSIX)
    preferUnknown    = 3,  // path preferred separator is unknown... suggests taking Path.preferredSeparator
}


version(Windows)
    enum char OS_PREFERRED_SEPARATOR = '\\';
else
    enum char OS_PREFERRED_SEPARATOR = '/';

char prefToChar(SepPreference pref) pure
{
    switch(pref)
    {
        case SepPreference.preferSlash:     return '/';
        case SepPreference.preferBackslash: return '\\';
        case SepPreference.preferUnknown:   return OS_PREFERRED_SEPARATOR;
        default:
            assert(0);
    }
}

/*

Appendix: The scary world of pathnames.

It's a nice mental model that all path on your system are UTF-8 or 
UTF-16, but this isn't strictly true.

- Windows: when using fopen or open (POSIX), the pathnames are expected 
  to be in the active codepage. Hence, no libc or POSIX call should be 
  used when on Windows in this library.
  Similarly to Linux, the UTF-16 can be invalid, have unpaired surrogates,
  etc. Which is rather bad, because the unpaired surrogate have no UTF-8
  equivalent. https://github.com/rust-lang/rust/issues/12056

- Linux: the first Linux using UTF-8 as the default encoding was RedHat 
  in 2002. Nothing actually forces path to be UTF-8, they could be
  malformed UTF-8.
  As long as you're using '/' and '\0' the path can contain anything.

- macOS: a bit of the same as Linux.


*/