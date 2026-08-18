module files;

import filesystem;
import nulib;

import core.stdc.stdio;

void nprintf(nstring s)
{
    printf("%20.*s", cast(int) s.length, s.ptr);
}

/+
@("absolute()")
unittest
{
    assert(exists(absolute(Path(".")) / "dub.sdl"));
}

@("copyFile()")
unittest
{
    // Isolate the test so that it doesn't interfere with directory 
    // listing test
    createDirectories(Path("tests/copyFile/"));

    Path tempFile = Path("tests/copyFile/delete-me");

    if (exists(tempFile))
        remove(tempFile);

    assert(copyFile(Path("./tests/FileWithSizeTwo"), tempFile));
    assert(exists(tempFile));
    assert(fileSize(tempFile) == 2);
    assert(remove(tempFile));
    assert(!exists(tempFile));
}

@("createDirectories()")
unittest
{
    createDirectories(Path("tests/createDir/my/deeply/nested/hierarchy"));
    createDirectories(Path("tests/createDir/my/deeply/../../our/hierarchy"));

    // Exist, we created it before
    assert(false == createDirectories(Path("tests/createDir/my/deeply/")));

    // .. exist, but didn't need to create it
    assert(false == createDirectories(Path("..")));

    assert(remove(Path("tests/createDir/my/deeply/nested/hierarchy")));
    assert(remove(Path("tests/createDir/my/deeply/nested")));
    assert(remove(Path("tests/createDir/my/deeply")));
    assert(remove(Path("tests/createDir/my")));
    assert(remove(Path("tests/createDir/our/hierarchy")));
    assert(remove(Path("tests/createDir/our")));
    assert(remove(Path("tests/createDir")));
}

@("currentPath()")
unittest
{
    assert(exists(currentPath() / "dub.sdl"));
}


@("dirEntries()")
unittest
{
    // iterate project dir
    foreach(entry; dirEntries(Path(".")))
    {
    }
}
+/
@("dirEntriesRecursive()")
unittest
{
    {
        int items = 0;
        // iterate project dir
        foreach(entry; dirEntriesRecursive(Path("tests/testRecursive"), DirectoryOptions.none))
        {
            ++items;
        }
        assert(items == 3);
    }

    {
        int items = 0;
        foreach(entry; dirEntriesRecursive(Path("tests/testRecursive"), DirectoryOptions.spanDepthFirst))
        {
            ++items;
        }
        assert(items == 3);
    }
    {
        int items = 0;
        foreach(entry; dirEntriesRecursive(Path("tests/testRecursive2")))
        {
            if (items == 0) assert(entry.path == "tests/testRecursive2/a");
            if (items == 1) assert(entry.path == "tests/testRecursive2/a/b");
            if (items == 2) assert(entry.path == "tests/testRecursive2/a/b/c");
            if (items == 3) assert(entry.path == "tests/testRecursive2/a/b/c/file");
            ++items;
        }
        assert(items == 4);
    }
    {
        int items = 0;
        foreach(entry; dirEntriesRecursive(Path("tests/testRecursive2"), DirectoryOptions.spanDepthFirst))
        {
            printf("***"); nprintf(entry.path);printf("\n");
            if (items == 0) assert(entry.path == "tests/testRecursive2/a/b/c/file");
            if (items == 1) assert(entry.path == "tests/testRecursive2/a/b/c");
            
            if (items == 2) assert(entry.path == "tests/testRecursive2/a/b");
            if (items == 3) assert(entry.path == "tests/testRecursive2/a");
            ++items;
        }
        assert(items == 4);
    }
}
/+
@("equivalent()")
unittest
{
    assert(equivalent(Path("."), Path(".")));
    assert(equivalent(Path("dub.sdl"), Path("dub.sdl")));
}

@("exists()")
unittest
{
    assert(exists(Path("/")));
    assert(exists(Path(".")));
    assert(exists(Path("dub.sdl")));
    assert( ! exists(Path("i/do/not/exist")));
}

@("FileNotFoundException")
unittest
{
    try
    {
        status(Path("i-do-not-exist"));
        assert(0);
    }
    catch(FileNotFoundException e)
    {
        assert(e.msg == "File not found: `i-do-not-exist`");
        e.free();
    }
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



+/