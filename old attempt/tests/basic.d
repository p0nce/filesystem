import core.stdc.stdio;
import nulib;
import nupath;
import nuenv;

@("path_get_absolute (UNIX)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_UNIX);

    assert( path_get_absolute(nstring("/foo/bar"), nstring("some/file"),  ) == "/foo/bar/some/file");
    assert( path_get_absolute(nstring("/foo/bar"), nstring("../file"),    ) == "/foo/file");
    assert( path_get_absolute(nstring("/foo/bar"), nstring("/some/file"), ) == "/some/file");

    path_set_style(old);
}

@("path_get_absolute (Windows)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_WINDOWS);

    assert( path_get_absolute(nstring("/foo/bar"), nstring("some/file"),  ) == "\\foo\\bar\\some\\file");
    assert( path_get_absolute(nstring("/foo/bar"), nstring("../file"),    ) == "\\foo\\file");
    assert( path_get_absolute(nstring("/foo/bar"), nstring("/some/file"), ) == "\\some\\file");

    path_set_style(old);
}

@("path_get_relative (UNIX)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_UNIX);

    assert(path_get_relative(nstring("/"),            nstring("/foo"))          == "foo");
    assert(path_get_relative(nstring("/foo/bar"),     nstring("/foo/bar"))      == ".");
    assert(path_get_relative(nstring("/foo/baz"),     nstring("/foo/bar"))      == "../bar");
    assert(path_get_relative(nstring("/foo/woo/wee"), nstring("/foo/bar/baz"))  == "../../bar/baz");
    assert(path_get_relative(nstring("/foo/bar"),     nstring("/foo/bar/baz"))  == "baz");

    path_set_style(old);
}

@("path_get_relative (Windows)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_WINDOWS);

    assert(path_get_relative(nstring(`c:\`), nstring(`c:\foo`)));
    assert(path_get_relative(nstring(`c:\foo\bar`), nstring(`c:\foo\bar`)) == ".");
    assert(path_get_relative(nstring( `c:\foo\baz`), nstring(`c:\foo\bar`))  == `..\bar`);
    assert(path_get_relative(nstring(`c:\foo\woo\wee`), nstring(`c:\foo\bar\baz`))  == `..\..\bar\baz`);
    assert(path_get_relative(nstring(`c:\foo\`), nstring(`c:\foo\baz`))  == "baz");
    assert(path_get_relative(nstring(`c:\foo`), nstring(`c:\foo\baz`))  == "baz");

    path_set_style(old);
}

@("path_join (UNIX)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_UNIX);

    assert(path_join(nstring("foo"),   nstring("bar"))     == "foo/bar");
    assert(path_join(nstring("/foo/"), nstring("bar/baz")) == "/foo/bar/baz");
    

    // Different behaviour from Phobos, which will take an absolute path as erasing former path.
    //assert(path_join(nstring("/foo"),  nstring("/bar"))    == "/bar");

    path_set_style(old);
}

@("path_join (Windows)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_WINDOWS);

    assert(path_join(nstring("foo")   , nstring("bar")) == `foo\bar`);
    assert(path_join(nstring(`c:\foo`), nstring(`bar\baz`)) == `c:\foo\bar\baz`);

    // Different behaviour from Phobos, which will take an absolute path as erasing former path.
    //assert(path_join(nstring("foo")   , nstring(`d:\bar`)) == `d:\bar`);
    //assert(path_join(nstring("foo")   , nstring(`\bar`)) == `\bar`);
    //assert(path_join(nstring(`c:\foo`), nstring(`\bar`)) == `c:\bar`);

    path_set_style(old);
}


@("path_dirname (UNIX)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_UNIX);

    assert(path_dirname(nstring("/my/path.txt")) == "/my/");
    assert(path_dirname(nstring("/one/two/three.txt")) == "/one/two/");

    assert(path_dirname(nstring("/file")) == "/"); // "/"

    // IMPORTANT: Phobos would return "." here, for some reason...
    // the Phobos function always return a _directory_, while cwalk
    // return the _part_ of the input path that is a "dirname".
    assert(path_dirname(nstring("file")) == ""); 
    assert(path_dirname(nstring("dir/")) == "");
    //assert(path_dirname(nstring("file")) == "."); 
    //assert(path_dirname(nstring("dir/")) == ".");

    assert(path_dirname(nstring("/many-slashes/////")) == "/");
    
    assert(path_dirname(nstring("dir//file")) == "dir//");
    assert(path_dirname(nstring("dir/subdir/")) == "dir/");    
    assert(path_dirname(nstring("/")) == ""); // Note: Phobos would return "/" here.

    path_set_style(old);
}

@("path_dirname (Windows)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_WINDOWS);

    assert(path_dirname(nstring(`dir\`))        == "");
    assert(path_dirname(nstring(`dir\\\`))      == "");
    assert(path_dirname(nstring(`dir\file`))    == `dir\`);
    assert(path_dirname(nstring(`dir\\\file`))  == `dir\\\`);
    assert(path_dirname(nstring(`dir\subdir\`)) == `dir\`);
    assert(path_dirname(nstring(`\dir\file`))   == `\dir\`);
    assert(path_dirname(nstring(`\file`))       == `\`);
    assert(path_dirname(nstring(`\`))           == ``);    // Phobos would return `\`    
    assert(path_dirname(nstring(`\\\`))         == ``);    // Phobos would return `\`
    assert(path_dirname(nstring(`d:`))          == "");    // Phobos would return `d:`
    assert(path_dirname(nstring(`d:file`))      == "d:");
    assert(path_dirname(nstring(`d:\`))         == "");    // Phobos would return `d:\`
    assert(path_dirname(nstring(`d:\file`))     == `d:\`);
    assert(path_dirname(nstring(`d:\dir\file`)) == `d:\dir\`);
    assert(path_dirname(nstring(`\\server\share\dir\file`)) == `\\server\share\dir\`);
    assert(path_dirname(nstring(`\\server\share`)) == ""); // Phobos would return `\\server\share`

    path_set_style(old);
}

@("path_basename (UNIX)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_UNIX);

    assert(path_basename(nstring("dir/file.ext")) == "file.ext");
    assert(path_basename(nstring("dir/filename")) == "filename");
    assert(path_basename(nstring("dir/subdir/"))  == "subdir"); 
    assert(path_basename(nstring("dir/subdir"))  == "subdir");

    path_set_style(old);
}

@("path_basename (Windows)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_WINDOWS);

    assert(path_basename(nstring("d:file.ext"))      == "file.ext");
    assert(path_basename(nstring(`d:\dir\file.ext`)) == "file.ext");
    assert(path_basename(nstring(`hello\dir\subdir\`))  == `subdir`);

    path_set_style(old);
}

@("path_get_extension")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_UNIX);

    assert(path_extension(nstring("file")) == "");
    assert(path_extension(nstring("file.")) == ".");
    assert(path_extension(nstring("file.ext")) == ".ext");
    assert(path_extension(nstring("file.ext1.ext2")) == ".ext2");
    
    assert(path_extension(nstring(".foo")) == ".foo"); // Phobos would rightly return "" here...
    //assert(path_extension(nstring(".foo")) == ""); 


    assert(path_extension(nstring(".foo.ext")) == ".ext");
    assert(path_extension(nstring("path/to/file")) == "");
    assert(path_extension(nstring("path/to/file.ext")) == ".ext");

    path_set_style(old);
}

@("path_has_extension")
unittest
{
    assert(path_has_extension("path/to/file.ext"));
    assert(path_has_extension("path/to/file.")); // '.' alone is also an extension, kinda
    assert( ! path_has_extension("path/to/file"));
    assert( ! path_has_extension("path/to/dir/"));
    
}


@("path_normalize (UNIX)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_UNIX);

    assert(path_normalize(nstring("/foo/./bar/..//baz/"))  == "/foo/baz");
    assert(path_normalize(nstring("../foo/."))             == "../foo");
    assert(path_normalize(nstring("/foo/bar/baz/"))        == "/foo/bar/baz");
    assert(path_normalize(nstring("/foo/./bar/../../baz")) == "/baz");
    
    path_set_style(old);
}

@("path_normalize (Windows)")
unittest
{
    int old = path_get_style();
    path_set_style(NU_PATH_STYLE_WINDOWS);

    assert(path_normalize(nstring(`c:\foo\.\bar/..\\baz\`))     == `c:\foo\baz`);
    assert(path_normalize(nstring(`..\foo\.`))                  == `..\foo`);
    assert(path_normalize(nstring(`c:\foo\bar\baz\`))           == `c:\foo\bar\baz`);
    assert(path_normalize(nstring(`c:\foo\bar/..`))             == `c:\foo`);
    assert(path_normalize(nstring(`\\server\share\foo\..\bar`)) == `\\server\share\bar`);
    
    path_set_style(old);
}


@("nu_env_get")
unittest
{
    assert(nu_env_get(nstring("__NOT_FOUND__")) == "");
    assert(nu_env_get(nstring("__NOT_FOUND__")) == null);
    assert(nu_env_get(nstring("PATH")) != "");
}

@("nu_env_set")
unittest
{
    nstring save = nu_env_get(nstring("PATH"));
    assert(true == nu_env_set(nstring("PATH"), nstring("LOL67")));
    nstring en = nu_env_get(nstring("PATH"));
    assert(nu_env_get(nstring("PATH")) == "LOL67");
    nu_env_set(nstring("PATH"), save);
}

