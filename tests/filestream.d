import filesystem;

import numem;
import nulib;

import cstdio = core.stdc.stdio;

@("File write")
unittest
{
    {
        Path path = Path("tests/createTest");
        auto myfile = fileOpenWrite(path);
        ubyte[3] content = [32, 32, 32];
        myfile.write(content);
        myfile.close();
        assert(fileSize(path) == 3);
        remove(path);
    }
}

@("File read")
unittest
{
    Path path = Path("dub.sdl");
    long size = path.fileSize();

    auto myfile = path.fileOpenRead();
    size_t len = myfile.length();
  
    ubyte[] content;
    content.nu_resize(len);
    scope(exit) content.nu_resize(0);

    ptrdiff_t bytes = myfile.read(content);
    assert(bytes == len); // Not a given, fread could theoretically 
                          // return a partial result    
    myfile.close();
    assert(len == size);
}