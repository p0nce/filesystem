import filesystem;

import numem;
import nulib;

import core.stdc.stdio;

import filesystem.internals;
import filesystem.path;
import filesystem.freefunc;

void nprintf(nstring s)
{
    printf("%.*s", cast(int) s.length, s.ptr);
}

void display(vector!Path paths)
{
    foreach(p; paths)
    {
        printf(" - ");
        nprintf(p);
        printf("\n");
    }
}

@("getFromDefaultDirs")
unittest
{
    Path conf = Path("tests/test.conf");
    Path home = Path("/home/user");
    assert(getFromDefaultDirs("DOCUMENTS", home, conf) == "/home/user/MyDocuments");
    assert(getFromDefaultDirs("PICTURES", home, conf) == "/home/user/Images");
    assert(getFromDefaultDirs("VIDEOS", home, conf).empty);
}


@("getFromUserDirs")
unittest
{
    Path conf = Path("tests/test2.conf");
    Path home = Path("/home/user");
    assert(getFromUserDirs("XDG_DOCUMENTS_DIR", home, conf) == "/home/user/My Documents");
    assert(getFromUserDirs("XDG_MUSIC_DIR", home, conf) == "/data/Music");
    assert(getFromUserDirs("XDG_DOWNLOAD_DIR", home, conf).empty);
    assert(getFromUserDirs("XDG_VIDEOS_DIR", home, conf).empty);
}

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


@("Standard paths")
unittest
{


    printf("Home dir is:\n");
    printf(" - ");
    nprintf(homeDir());
    printf("\n");
    
    printf("Config dir is:\n");
    display(standardPaths(StandardPath.config));

    printf("App data dir is:\n");
    display(standardPaths(StandardPath.data));

    printf("Desktop dir is:\n");
    display(standardPaths(StandardPath.desktop));

    printf("Documents dir is:\n");
    display(standardPaths(StandardPath.documents));

    printf("Pictures dir is:\n");
    display(standardPaths(StandardPath.pictures));

    printf("Music dir is:\n");
    display(standardPaths(StandardPath.music));

    printf("Videos dir is:\n");
    display(standardPaths(StandardPath.videos));

    printf("Downloads dir is:\n");
    display(standardPaths(StandardPath.downloads));

    printf("Fonts dir is:\n");
    display(standardPaths(StandardPath.fonts));

    printf("Applications dir is:\n");
    display(standardPaths(StandardPath.applications));

    printf("Startup dir is:\n");
    display(standardPaths(StandardPath.startup));

    version(Windows)
    {
        printf("Roaming dir is:\n");
        display(standardPaths(StandardPath.roaming));

        printf("Game save files dir is:\n");
        display(standardPaths(StandardPath.savedGames));
    }
}
