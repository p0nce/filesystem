module filesystem.filestream;

// Note: currently using libc

import nulib.io.stream;
import numem;

import filesystem.path;

// TODO: use posix fopen like in Phobos
import cstdio = core.stdc.stdio;

/**
    A stream over a file backed by FILE*.

    FUTURE: eventually move this to POSIX and Win32?

    See_Also:
        $(D nulib.io.stream.rw.StreamReader), 
        $(D nulib.io.stream.rw.StreamWriter)
*/
class FileStream : Stream 
{
private:
@nogc nothrow @safe:
    cstdio.FILE* cfile = null;

public:

    this(Path p, scope const(char)[] mode = "rb")
    {
        assert(0);
    }

    ~this()
    {
        close();
    }

    override @property bool canRead() { return true; } // TODO
    override @property bool canWrite() { return true; } // TODO
    override @property bool canSeek() { return true; }
    override @property bool canTimeout() { return false; }
    override @property bool canFlush() { return true; }

    override @property ptrdiff_t length() 
    {
        assert(0); // TODO
    }

    override @property ptrdiff_t tell() 
    { 
        return cast(ptrdiff_t) cstdio.ftell(cfile);
    }

    override @property int readTimeout() { return 0; }
    override @property int writeTimeout() { return 0; }

    override bool flush()
    {
        return cstdio.fflush(cfile) == 0;
    }

    override long seek(ptrdiff_t offset, SeekOrigin origin)
    {
        assert(0);
    }

    override void close() @trusted
    {
        if (cfile)
        {
            cstdio.fclose(cfile);
            cfile = null;
        }
    }


    override ptrdiff_t read(ubyte[] buffer) 
    {
        assert(0);
    }

    override ptrdiff_t write(ubyte[] buffer) 
    {
        assert(0);
    }

    /**
        Takes ownership of the FILE*. The caller is now
        responsible for freeing it.
    */
    final cstdio.FILE* take() 
    {
        cstdio.FILE* result = cfile;
        cfile = null;
        return result;
    }
}
