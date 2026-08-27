module filesystem.filestream;

// Note: currently using libc

import nulib.io.stream;
import nulib.string;
import nulib.text.unicode;
import nulib.memory;

import numem;


import filesystem.path;
import filesystem.internals;

import cstdio = core.stdc.stdio;
import cconfig = core.stdc.config;

version(Posix)
    import pstdio = core.sys.posix.stdio;

version (CRuntime_Microsoft)
{
    // This is necessary so that we can open file with Unicode paths, regular fopen would instead
    // asks for the current codepage.
    extern (C) nothrow @nogc cstdio.FILE* _wfopen(scope const wchar* filename, scope const wchar* mode);
}

@nogc:

/**
    Open file and return a stream to it.

    `fileOpen` lets you choose the libc access mode (eg: "wb+"),
    while `fileOpenRead` and `fileOpenWrite` are for the common cases.
*/
unique_ptr!FileStream fileOpen(Path path, scope const(char)[] accessMode = "rb")
{
    return unique_new!FileStream(path, accessMode);
}
///ditto
unique_ptr!FileStream fileOpenRead(Path path) => fileOpen(path, "rb");
///ditto
unique_ptr!FileStream fileOpenWrite(Path path) => fileOpen(path, "wb");

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
@nogc @safe:
    cstdio.FILE* cfile = null;
    Flags flags;

public:

    /**
        Constructor. This is the only function that may throw.

        Throws: `FileSystemIOException`,
                `InvalidPathException`.

        Params:
            path = A UTF-8 file path.
            mode = Can be "r", "w", "a", "r+", "w+", "a+"...

        Warning: Do not forget "b" access mode. In text mode,
            MSVC runtime will mess with the file bytes.
    */
    this(Path path, scope const(char)[] accessMode = "rb") @trusted
    {
        nstring mode = accessMode;
        nstring npath;

        try
        {
            npath = path.native(); // .native isn't nothrow yet
        }
        catch(NuException e)
        {
            throw e;
        }
        catch(Exception e)
        {
            assert(0);
        }

        version(CRuntime_Microsoft)
        {
            nwstring wmode, wpath;
            try
            {
                wmode = mode.toUTF16(); // toUTF16 isn't nothrow
                wpath = path.toUTF16();
            }
            catch(Exception e)
            {
                assert(0);
            }
            cfile = _wfopen(wpath.ptr, wmode.ptr);
        }
        else version(Posix)
        {
            // Phobos does this, with a convincing explanation.
            cfile = pstdio.fopen(npath.ptr, mode.ptr);
        }
        else
        {
            cfile = cstdio.fopen(npath.ptr, mode.ptr);
        }

        if (cfile is null)
            throwIO(kStrErrOpenFileFailed);

        flags = parseAccessMode(accessMode);
    }
    ///ditto
    this(const(char)[] path, scope const(char)[] accessMode = "rb") @trusted
        => this(Path(path), accessMode);

nothrow:

    /**
        Destructor.
    */
    ~this()
    {
        close();
    }

    /**
        Whether the stream can be read from.

        Returns:
        $(D true) if you can read data from the stream,
        $(D false) otherwise.
    */
    override @property bool canRead() => (flags & Flags.read) != 0;

    /**
        Whether the stream can be written to.

        Returns:
        $(D true) if you can write data to the stream,
        $(D false) otherwise.
    */
    override @property bool canWrite() => (flags & Flags.write) != 0;

    /**
        Whether the stream can be seeked.

        Returns:
        $(D true) if you can seek through the stream,
        $(D false) otherwise.
    */
    override @property bool canSeek() => true;

    /**
        Whether the stream can timeout during operations.

        Returns:
        $(D true) if the stream may time out during operations,
        $(D false) otherwise.
    */
    override @property bool canTimeout() => false;

    /**
        Whether the stream can be flushed to disk.

        Returns:
        $(D true) if the stream may be flushed,
        $(D false) otherwise.
    */
    override @property bool canFlush() => true;

    /**
        Length of the stream.

        Returns:
        Length of the stream, or $(D -1) if the length is unknown.
    */
    override @property ptrdiff_t length() 
    {
        ptrdiff_t oldpos = tell();
        if (oldpos < 0)
            return -1;

        // Note: if we get a fseek() failure, then
        // the stream is now invalid, but no way to
        // tell the user.

        long size = seek(0, SeekOrigin.end);
        if (size < 0)
            return -1;

        long r = seek(oldpos, SeekOrigin.start);
        if (r < 0)
            return -1; 

        return cast(ptrdiff_t) size;
    }

    /**
        Position in stream.

        Returns:
            Position in the stream, or $(D -1) if the position is unknown.
    */    
    override @property ptrdiff_t tell() 
    { 
        return cast(ptrdiff_t) cstdio.ftell(cfile);
    }

    /**
        Timeout in milliseconds before a read operation will fail.

        Returns:
            A timeout in milliseconds, or $(D 0) if there's no timeout.
    */
    override @property int readTimeout() { return 0; }

    /**
        Timeout in milliseconds before a write operation will fail.

        Returns:
            A timeout in milliseconds, or $(D 0) if there's no timeout.
    */
    override @property int writeTimeout() { return 0; }

    /**
        Clears all buffers of the stream and causes data to be written to the underlying device.

        Returns:
            $(D true) if the flush operation succeeded,
            $(D false) otherwise.
    */
    override bool flush()
    {
        return cstdio.fflush(cfile) == 0;
    }

    /**
        Sets the reading position within the stream

        Returns:
            The new position in the stream, or a $(D StreamError) if the 
            seek operation failed.

        See_Also:
            $(D StreamError)
    */
    override long seek(ptrdiff_t offset, SeekOrigin origin)
    {
        int res = cstdio.fseek(cfile, cast(cconfig.c_long) offset, cast(int) origin);
        if (res == -1)
            return STREAM_ERROR_INVALID_STATE;
        long cur = cstdio.ftell(cfile);
        if (cur == -1)
            return STREAM_ERROR_INVALID_STATE;
        return cur;
    }

    /**
        Closes the stream.
    */
    override void close() @trusted
    {
        if (cfile)
        {
            cstdio.fclose(cfile);
            cfile = null;
        }
    }

    /**
        Reads bytes from the specified stream in to the specified buffer.

        Notes:
            The position and length to read is specified by the slice of `buffer`.  
            Use slicing operation to specify a range to read to.

        Returns:
            The amount of bytes read from the stream, 
            or a $(D StreamError).

        See_Also:
            $(D StreamError)
    */
    override ptrdiff_t read(ubyte[] buffer) @trusted
    {
        assert(buffer.length > 0);
        size_t res = cstdio.fread(&buffer[0], 1, buffer.length, cfile);
        if (cstdio.ferror(cfile))
            return STREAM_ERROR_INVALID_STATE;
        return res;
    }

    /**
        Writes bytes from the specified buffer in to the stream

        Notes:
            The position and length to write is specified by the slice of `buffer`.  
            Use slicing operation to specify a range to write from.

        Returns:
            The amount of bytes written to the stream, 
            or a $(D StreamError).

        See_Also:
            $(D StreamError)
    */
    override ptrdiff_t write(ubyte[] buffer) @trusted
    {
        assert(buffer.length > 0);
        size_t res = cstdio.fwrite(&buffer[0], 1, buffer.length, cfile);
        if (cstdio.ferror(cfile))
            return STREAM_ERROR_INVALID_STATE;
        return res;
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

private:

    enum Flags
    {
        read      = 1, // read enabled
        write     = 2, // write enabled
    }

    Flags parseAccessMode(scope const(char)[] accessMode)
    {
        int r = 0;
        foreach(char ch; accessMode)
        {
            switch(ch)
            {
                case 'r': 
                    r |= Flags.read; 
                    break;
                case 'a':
                case 'w': 
                    r |= Flags.write; 
                    break;
                case '+':
                    r |= (Flags.read | Flags.write);
                    break;
                default:
            }
        }
        return cast(Flags) r;
    }
}
