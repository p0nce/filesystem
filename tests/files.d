module files;

import filesystem;
import nulib;

import core.stdc.stdio;

void nprintf(nstring s)
{
    printf("%.*s", cast(int) s.length, s.ptr);
}


@("absolute()")
unittest
{
    assert(exists(absolute(Path(".")) / "dub.sdl"));
}

@("currentPath()")
unittest
{
    assert(exists(currentPath() / "dub.sdl"));
}

@("exists()")
unittest
{
    assert(exists(Path("/")));
    assert(exists(Path(".")));
    assert(exists(Path("dub.sdl")));
    assert( ! exists(Path("i/do/not/exist")));
}

@("fileSize()")
unittest
{
    assert(fileSize(Path("./tests/FileWithZeroSize")) == 0);
    assert(fileSize(Path("./tests/FileWithSizeTwo")) == 2);
}

@("lastWriteTime()")
unittest
{
    long time0 = lastWriteTime(Path("./tests/FileWithZeroSize"));
    long timeHere = lastWriteTime(Path("."));
}

@("createDirectories()")
unittest
{
    assert(true == createDirectories(Path("temp/my/deeply/nested/hierarchy")));
    assert(true == createDirectories(Path("temp/my/deeply/../../our/hierarchy")));

    // Exist, we created it before
    assert(false == createDirectories(Path("./temp/my/deeply/")));

    // .. exist, but didn't need to create it
    assert(false == createDirectories(Path("..")));

    assert(remove(Path("./temp/my/deeply/nested/hierarchy")));
    assert(remove(Path("./temp/my/deeply/nested")));
    assert(remove(Path("./temp/my/deeply")));
    assert(remove(Path("./temp/my")));
    assert(remove(Path("./temp/our/hierarchy")));
    assert(remove(Path("./temp/our")));
    assert(remove(Path("./temp")));
}