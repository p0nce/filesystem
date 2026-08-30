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

@("canonical()")
static if (0)
unittest
{
    try
    {
        canonical(Path(""));
        assert(0);
    }
    catch(FileSystemException e)
    {
        e.free;
    }

    assert(canonical(currentPath()) == currentPath());
    assert(canonical(Path(".")) == currentPath());
    assert(canonical(Path(".")) == currentPath().parentPath);
    assert(canonical(Path("/")) == currentPath().rootPath);

    try
    {
        canonical(Path("foo"));
        assert(0);
    }
    catch(FileSystemException e)
    {
        e.free;
    }
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
    removeAll(Path("tests/createDir"));
}

@("currentPath()")
unittest
{
    assert(exists(currentPath() / "dub.sdl"));
}

@("dirEntries()")
unittest
{
    // iterate non-empty dir
    {
        int items = 0;
        foreach(entry; dirEntries(Path("tests/testRecursive")))
        {
            ++items;
        }
        assert(items == 2);
    }

    // iterate empty dir
    {
        createDirectories(Path("tests/empty-dir"));
        assert(isEmpty(Path("tests/empty-dir")));
        auto range = dirEntries(Path("tests/empty-dir"));
        assert(range.empty);
        remove(Path("tests/empty-dir"));
    }
}

@("dirEntriesRecursive()")
unittest
{
    try
    {
        removeAll(Path("tests/empty-dir2"));
        removeAll(Path("tests/empty-dir3"));
    }
    catch(FileSystemException e)
    {
        e.free();
    }

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
            if (items == 0) assert(entry.path == "tests/testRecursive2/a/b/c/file");
            if (items == 1) assert(entry.path == "tests/testRecursive2/a/b/c");
            
            if (items == 2) assert(entry.path == "tests/testRecursive2/a/b");
            if (items == 3) assert(entry.path == "tests/testRecursive2/a");
            ++items;
        }
        assert(items == 4);
    }

    // empty dir
    {
        createDirectories(Path("tests/empty-dir2"));
        auto range = dirEntriesRecursive(Path("tests/empty-dir2"));
        assert(range.empty);

        auto range2 = dirEntriesRecursive(Path("tests/empty-dir2"), DirectoryOptions.spanDepthFirst);
        assert(range2.empty);
        assert(1 == removeAll(Path("tests/empty-dir2")));
    }

    // Create an empty dir inside this empty dir
    {
        createDirectories(Path("tests/empty-dir3/empty-again"));
     
        auto range = dirEntriesRecursive(Path("tests/empty-dir3"));
        assert( ! range.empty);
        DirectoryEntry de = range.front();
        assert(de.path == "tests/empty-dir3/empty-again");
        range.popFront();
        assert(range.empty);

        auto range2 = dirEntriesRecursive(Path("tests/empty-dir3"), DirectoryOptions.spanDepthFirst);
        assert( ! range2.empty);
        DirectoryEntry de2 = range2.front();
        assert(de2.path == "tests/empty-dir3/empty-again");
        range2.popFront();
        assert(range2.empty);

        remove(Path("tests/empty-dir3/empty-again"));
        remove(Path("tests/empty-dir3"));
    }
}

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

@("readSymlink()")
unittest
{
    /*version(Posix)
    {
        // TEMP
        Path target = readSymlink(Path("/usr/bin/xzcat"));
        nprintf(target);

    }*/
}

@("removeAll()")
unittest
{
    if (exists(Path("tests/remove-all-test")))
         removeAll(Path("tests/remove-all-test"));

    createDirectories(Path("tests/remove-all-test/a/b/c/d/e/f"));
    assert(7 == removeAll(Path("tests/remove-all-test")));
    //removeAll(Path("tests/remove-all-test"));
    assert(! exists(Path("tests/remove-all-test")));
}

@("space()")
unittest
{
    SpaceInfo si;
    try
    {
        si = space(currentPath());
    }
    catch(FileSystemException e)
    {
        e.free();
        assert(0);
    }
    assert(si.capacity > 1024 * 1024);
    assert(si.capacity > si.freeTheoretical);
    assert(si.freeTheoretical >= si.available);
}

