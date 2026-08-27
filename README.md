# `filesystem`

**DO NOT USE, THIS IS UNFINISHED BUSINESS.**

The `filesystem` package is a @nogc D library for use in context where you can't use Phobos. It is a `nulib`-based, DUB package that provides a ranges of services related to filesystem:

Its design is 95% the one in `std::filesystem`, who did a lot of 
semantic work, only most of the API was D-ified and will for example 
expose ranges instead of iterators.


## Licence

MIT + BSL-1.0.

## Features

- `@nogc`
- POSIX, macOS, Windows.
- Path manipulation with the `Path` struct type.
    * `Path.native().toUTF16()` can be used in Win32 functions.
    * `Path.native()` can be used in POSIX functions that
      accept UTF-8.
- File type.
- File size, in bytes.
- File last write time, in seconds.
- File copy, rename, and removal.
- Recursive directory creation, listing and deletion.
- Disc usage information.
- `FileStream` implements nulib's `Stream`, is a bit like `std.stdio.File`.
- Getting standard paths, such as app data, XDG config (fork of `standardpaths` and `xdgpaths` and `isfreedesktop`).

## Documentation

See the `std::filesystem` documentation here: https://en.cppreference.com/cpp/filesystem

## Bugs and limitations

- This is **WIP**.
- Windows UNC path, `\\?\` and `\\.\` root pathes aren't yet supported.
  Windows path can't exceed `MAX_PATH` yet.
- Very little support for symlinks.


## Dependencies

- libc (bindings in druntime)
- POSIX (bindings in druntime)
- Win32 (bindings in druntime)
- DUB packages `numem` and `nulib`

