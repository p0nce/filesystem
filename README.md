# `filesystem`

The `filesystem` package is a @nogc D library for use in context where you can't use Phobos. It is a `nulib`-based, DUB package that provides a ranges of services related to filesystem:
- [x] Path manipulation with the `Path` type. **DONE**
- [x] File type, size, and last write time. **DONE**
- [ ] File and directories creation and deletion. **TODO**
- [ ] Directory search. **TODO**
- [ ] Disc usage **TODO**


Its design is largely related to the `std::filesystem`, who did a lot of semantic work, only most of the API was D-ified and will for example expose ranges instead of iterators.


## Dependencies:

- libc (bindings in druntime)
- POSIX (bindings in druntime)
- Win32 (bindings in druntime)
- numem and nulib