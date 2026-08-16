module files;

import filesystem;
import nulib;

import core.stdc.stdio;

void nprintf(nstring s)
{
    printf("%20.*s", cast(int) s.length, s.ptr);
}


@("absolute()")
unittest
{
    assert(exists(absolute(Path(".")) / "dub.sdl"));
}

@("copyFile()")
unittest
{
    if (exists(Path("delete-me")))
        remove(Path("delete-me"));

    assert(copyFile(Path("./tests/FileWithSizeTwo"), Path("delete-me")));
    assert(exists(Path("delete-me")));
    assert(fileSize(Path("delete-me")) == 2);
    assert(remove(Path("delete-me")));
    assert(!exists(Path("delete-me")));
}

@("currentPath()")
unittest
{
    assert(exists(currentPath() / "dub.sdl"));
}

@("dirEntries()")
unittest
{
    printf("Current directory contains:\n");
    foreach(entry; dirEntries(Path(".")))
    {
        printf(" - ");
        nprintf(entry.path.lexicallyNormal);
        if (isDirectory(entry.path))
            printf(" <dir>");
        else 
            printf(" %10llu bytes", fileSize(entry.path));
        printf("\n");
    }
}

@("exists()")
unittest
{
    assert(exists(Path("/")));
    assert(exists(Path(".")));
    assert(exists(Path("dub.sdl")));
    assert( ! exists(Path("i/do/not/exist")));
}

@("equivalent()")
unittest
{
    assert(equivalent(Path("."), Path(".")));
    assert(equivalent(Path("dub.sdl"), Path("dub.sdl")));
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