module path;

import filesystem;
import nulib;

import core.stdc.stdio;

void nprintf(nstring s)
{
    printf("%.*s", cast(int) s.length, s.ptr);
}

@(".rootName()")
unittest
{
    assert(Path("").rootName           == "");
    assert(Path(".").rootName          == "");
    assert(Path("..").rootName         == "");
    assert(Path("foo").rootName        == "");
    assert(Path("/").rootName          == "");
    assert(Path("/foo").rootName       == "");
    assert(Path("foo/").rootName       == "");
    assert(Path("/foo/").rootName      == "");
    assert(Path("foo/bar").rootName    == "");
    assert(Path("/foo/bar").rootName   == "");
    assert(Path("///foo/bar").rootName == "");
    version(Windows)
    {
        assert(Path("C:/foo").rootName     == "C:");
        assert(Path("C:\\foo").rootName    == "C:");
        assert(Path("C:foo").rootName      == "C:");
    }
}

@(".rootDirectory()")
unittest
{
    assert(Path("").rootDirectory           == "");
    assert(Path(".").rootDirectory          == "");
    assert(Path("..").rootDirectory         == "");
    assert(Path("foo").rootDirectory        == "");
    assert(Path("/").rootDirectory          == "/");
    assert(Path("/foo").rootDirectory       == "/");
    assert(Path("foo/").rootDirectory       == "");
    assert(Path("/foo/").rootDirectory      == "/");
    assert(Path("foo/bar").rootDirectory    == "");
    assert(Path("/foo/bar").rootDirectory   == "/");
    assert(Path("///foo/bar").rootDirectory == "/");
    version(Windows)
    {
        assert(Path("C:/foo").rootDirectory     == "/");
        assert(Path("C:\\foo").rootDirectory    == "/");
        assert(Path("C:foo").rootDirectory      == "");
    }
}

@(".rootPath()")
unittest
{
    assert(Path("").rootPath() == "");
    assert(Path(".").rootPath() == "");
    assert(Path("..").rootPath() == "");
    assert(Path("foo").rootPath() == "");
    assert(Path("/").rootPath() == "/");
    assert(Path("/foo").rootPath() == "/");
    assert(Path("foo/").rootPath() == "");
    assert(Path("/foo/").rootPath() == "/");
    assert(Path("foo/bar").rootPath() == "");
    assert(Path("/foo/bar").rootPath() == "/");
    assert(Path("///foo/bar").rootPath() == "/");
    assert(Path("C:/foo").rootPath() == "C:/");
    assert(Path("C:\\foo").rootPath() == "C:/");
    assert(Path("C:foo").rootPath() == "C:");
    assert(Path("tests/my/deeply/nested/hierarchy").rootPath() == "");
}

@(".relativePath()")
unittest
{
    assert(Path("").relativePath() == "");
    assert(Path(".").relativePath() == ".");
    assert(Path("..").relativePath() == "..");
    assert(Path("foo").relativePath() == "foo");
    assert(Path("/").relativePath() == "");
    assert(Path("/foo").relativePath() == "foo");
    assert(Path("foo/").relativePath() == "foo/");
    assert(Path("/foo/").relativePath() == "foo/");
    assert(Path("foo/bar").relativePath() == "foo/bar");
    assert(Path("/foo/bar").relativePath() == "foo/bar");
    assert(Path("///foo/bar").relativePath() == "foo/bar");
    version(Windows)
    {
        assert(Path("C:/foo").relativePath() == "foo");
        assert(Path("C:\\foo").relativePath() == "foo");
        assert(Path("C:foo").relativePath() == "foo");
    }
}

@(".parentPath()")
unittest
{
    assert(Path("").parentPath() == "");
    assert(Path(".").parentPath() == "");
    assert(Path("..").parentPath() == "");  // unintuitive but as defined in the standard
    assert(Path("foo").parentPath() == "");
    assert(Path("/").parentPath() == "/");
    assert(Path("/foo").parentPath() == "/");    
    assert(Path("foo/").parentPath() == "foo");
    assert(Path("/foo/").parentPath() == "/foo");
    assert(Path("foo/bar").parentPath() == "foo");
    assert(Path("/foo/bar").parentPath() == "/foo");
    assert(Path("///foo/bar").parentPath() == "/foo");
    version(Windows)
    {
        assert(Path("C:/foo").parentPath() == "C:/");
        assert(Path("C:\\foo").parentPath() == "C:/");
        assert(Path("C:foo").parentPath() == "C:");
    }
}

@(".stem()")
unittest
{
    assert(Path("/foo/bar.txt").stem() == "bar");

    {
        Path p = "foo.bar.baz.tar";
        assert(p.extension() == ".tar");
        p = p.stem();
        assert(p.extension() == ".baz");
        p = p.stem();
        assert(p.extension() == ".bar");
        p = p.stem();
        assert(p == "foo");
    }
    assert(Path("/foo/.profile").stem() == ".profile");
    assert(Path(".bar").stem() == ".bar");
    assert(Path("..bar").stem() == ".");
    version(Windows)
        assert(Path("t:est.txt").stem() == "est");
    else
        assert(Path("t:est.txt").stem() == "t:est");
    assert(Path("/foo/.").stem() == ".");
    assert(Path("/foo/..").stem() == "..");
}

@(".extension()")
unittest
{
    assert(Path("/foo/bar.txt").extension() == ".txt");
    assert(Path("/foo/bar").extension() == "");
    assert(Path("/foo/.profile").extension() == "");
    assert(Path(".bar").extension() == "");
    assert(Path("..bar").extension() == ".bar");
    assert(Path("t:est.txt").extension() == ".txt");
    assert(Path("/foo/.").extension() == "");
    assert(Path("/foo/..").extension() == "");
}

@(".fileName()")
unittest
{
    assert(Path("").filename() == "");
    assert(Path(".").filename() == ".");
    assert(Path("..").filename() == "..");
    assert(Path("foo").filename() == "foo");
    assert(Path("/").filename() == "");
    assert(Path("/foo").filename() == "foo");
    assert(Path("foo/").filename() == "");
    assert(Path("/foo/").filename() == "");
    assert(Path("foo/bar").filename() == "bar");
    assert(Path("/foo/bar").filename() == "bar");
    assert(Path("///foo/bar").filename() == "bar");
    version(Windows)
    {
        assert(Path("C:/foo").filename() == "foo");
        assert(Path("C:\\foo").filename() == "foo");
        assert(Path("C:foo").filename() == "foo");
        assert(Path("t:est.txt").filename() == "est.txt");
    }
    else
    {
        assert(Path("t:est.txt").filename() == "t:est.txt");
    }
}

@(".makePreffered")
unittest
{
    version(Windows)
    {
        assert(Path("foo/bar") == "foo/bar");
        assert(Path("foo/bar").makePreferred() == "foo\\bar");
    }
    else
    {
        assert(Path("foo\\bar") == "foo\\bar");
        assert(Path("foo\\bar").makePreferred() == "foo\\bar"); // should parse as one filename
    }
}

@(".removeFilename()")
unittest
{
    assert(Path("foo/bar").removeFilename() == "foo/");
    assert(Path("foo/").removeFilename() == "foo/");
    assert(Path("/foo").removeFilename() == "/");
    assert(Path("/").removeFilename() == "/");
    version(Windows)
    {
        assert(Path("c:/lol.txt").removeFilename() == "c:/");
        assert(Path("path/diff.").removeFilename() == "path/");
    }
}

@(".replaceFilename()")
unittest
{
    assert(Path("/foo").replaceFilename("bar") == "/bar");
    assert(Path("/").replaceFilename("bar") == "/bar");
    assert(Path("/foo").replaceFilename("b//ar") == "/b/ar");
}

@(".replaceExtension()")
unittest
{
    assert(Path("/foo/bar.txt").replaceExtension("odf") == "/foo/bar.odf");
    assert(Path("/foo/bar.txt").replaceExtension() == "/foo/bar");
    assert(Path("/foo/bar").replaceExtension("odf") == "/foo/bar.odf");
    assert(Path("/foo/bar").replaceExtension(".odf") == "/foo/bar.odf");
    assert(Path("/foo/bar.").replaceExtension(".odf") == "/foo/bar.odf");
    assert(Path("/foo/bar/").replaceExtension("odf") == "/foo/bar/.odf");
}

@(".isAbsolute()")
unittest
{
    assert(! Path("foo/bar").isAbsolute());
    version(Windows)
    {
        assert(! Path("/foo").isAbsolute());
        assert(! Path("c:foo").isAbsolute());
        assert(Path("c:/foo").isAbsolute());
    }
    else
    {
        assert(Path("/foo").isAbsolute());
    }
}

@(".iterate")
unittest
{
    version(Windows)
    {
        Path p = Path(`C:\users\abcdef\AppData\Local\Temp\`);
        string[] correct = 
        [
            "C:", "/", "users", "abcdef", "AppData", "Local", "Temp", ""
        ];
        int n = 0;
        foreach(part; p.iterate())
        {
            assert(part == correct[n++]);
        }
    }
        
    Path p2 = Path(`/home/user/.config/Cppcheck/Cppcheck-GUI.conf`);
    string[] correct2 = 
    [
        "/", "home", "user", ".config", "Cppcheck", "Cppcheck-GUI.conf"
    ];
    int n2 = 0;
    foreach(part; p2.iterate())
    {
        assert(part == correct2[n2++]);
    }

    Path p3 = Path(`/foo/`);
    string[] correct3 = [ "/", "foo", ""];
    int n3 = 0;
    foreach(part; p3.iterate())
    {
        assert(part == correct3[n3++]);
    }
}

@(".append")
unittest
{
    import core.stdc.stdio;
    version(Windows)
    {
        assert(Path("foo") / "c:/bar" == "c:/bar");
        assert(Path("foo") / "c:" == "c:");
        assert(Path("c:") / "" == "c:");        
        assert(Path("c:foo") / "/bar" == `c:/bar`);
        assert(Path("c:foo") / "c:bar" == `c:foo\bar`); // small divergence vs spec, which is also unclear
    }
    else
    {
        assert(Path("foo") / "" == "foo/");
        assert(Path("foo") / "/bar" == "/bar");
    }
    assert(Path("") / "rel" == "rel");
}

@(".lexicallyNormal")
unittest
{
    assert(Path("foo/./bar/..").lexicallyNormal() == "foo/");
    assert(Path("foo/.///bar/../").lexicallyNormal() == "foo/");
    assert(Path("/foo/../..").lexicallyNormal() == "/");
    assert(Path("foo/..").lexicallyNormal() == ".");
    assert(Path("ab/cd/ef/../../qw").lexicallyNormal() == "ab/qw");
    assert(Path("a/b/../../../c").lexicallyNormal() == "../c");

    assert(Path("../").lexicallyNormal() == "..");
    assert(Path("./../foo/../bar").lexicallyNormal() == "../bar");
    assert(Path("./../foo/../../bar").lexicallyNormal() == "../../bar");
    assert(Path("../../foo/../bar").lexicallyNormal() == "../../bar");
    version(Windows)
    {
        assert(Path("\\/\\///\\/").lexicallyNormal() == "\\");
        assert(Path("a/b/../../../c/").lexicallyNormal() == "../c/");
        assert(Path("a/b/..\\//..///\\/../c\\\\/").lexicallyNormal() == "../c/");
        assert(Path("..a/b/..\\//..///\\/../c\\\\/").lexicallyNormal() == "../c/");
        assert(Path("..\\").lexicallyNormal() == "..");
        //assert(Path("//?/UNC/::1/c$/foo").lexically_normal() == R"(\\?\UNC\::1\c$\foo)");

        //assert(Path(`\\?\UNC\a::1\c$\foo`).lexicallyNormal() == `\\?\UNC\a::1\c$\foo`);
        //assert(Path(`\\?\UNC\fe80::1\c$\foo`).lexicallyNormal() == `\\?\UNC\fe80::1\c$\foo`);
        //assert(Path(`\\?\UNC\server\share\foo`).lexicallyNormal() == `\\?\UNC\server\share\foo`);
        //assert(Path(`\\server\share\foo`).lexicallyNormal() == `\\server\share\foo`);
        assert(Path(`C:foo\..\bar`).lexicallyNormal() == `C:bar`);
    }
}

@(".lexicallyRelative")
unittest
{
    assert(Path("/a/d").lexicallyRelative("/a/b/c") == "../../d");
    assert(Path("/a/b/c").lexicallyRelative("/a/d") == "../b/c");
    assert(Path("a/b/c").lexicallyRelative("a") == "b/c");
    assert(Path("a/b/c").lexicallyRelative("a/b/c/x/y") == "../..");
    assert(Path("a/b/c").lexicallyRelative("a/b/c") == ".");
    assert(Path("a/b").lexicallyRelative("c/d") == "../../a/b");
    assert(Path("a/b").lexicallyRelative("/a/b") == "");
    assert(Path("a/b").lexicallyProximate("/a/b") == "a/b");
}

@("currentPath() and absolute()")
unittest
{
    currentPath();
    absolute(".");
}
