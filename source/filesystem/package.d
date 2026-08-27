/**
    Public API, import this to start using filesystem.

    Copyright: Guillaume Piolat 2026.
    License: MIT (https://mit-license.org/)
*/
module filesystem;

// FileType, FileStatus...
public import filesystem.types;

// Path manipulation without I/O
public import filesystem.path;

// Free functions in the std::filesystem API, file manipulation
public import filesystem.freefunc;

// Structures related to directory search
public import filesystem.direntry;

// Standard directories
public import filesystem.standardpaths;
