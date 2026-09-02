## TODO before release

- [ ] One "True" Brace Style
- [ ] 70 columns where sensible

- [ ] I think we only need this exception hierarchy:
    FileSystemException (any I/O and API usage error)
      |_ InvalidPathException (just for the message, never need 
      |  special treatment)
      |_ FileNotFoundException (often caught)

    FileSystemIOException and InvalidPathException have very little
    point since you never need to do something different if a path is
    wrong vs an I/O error vs an API error.