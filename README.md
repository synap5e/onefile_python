# onefile_python

Run python from a single exe (without needing to extract anything to disk).

This project uses reflective dll loading and nim's `staticRead` to load the python runtime from the executable itself.
Custom (python) import hooks are installed to support loading modules (both native python (.pyc) and extension modules (.pyd)) from the embedded standard library.

## HOWTO

0. Set up nim
1. Download `python-3.10.1-embed-amd64.zip` to the project directory
2. `nimble build`
3. Run `onefile_python.exe`

## TODO

Currently the exe just drops to an interactive loop. Modification to run a script or embed a file/module should be trivial. 

- [ ] Build option for embedding a python file/module and running that on launch
- [ ] Support other versions of python than `3.10.1` (autodetect?)

## Similar projects

- [py2exe](https://www.py2exe.org/index.cgi/FrontPage)
- [PyInstaller](https://pyinstaller.readthedocs.io/en/stable/index.html)

Both projects are better suited for bundling an application (and all its dependencies) to end users. They both support some form of dependency resolution so modules not required by the bundled don't get installed, while this project includes the entire standard library.

PyInstaller supports single exe mode, but this just extracts the runtime to a temporary directory.
py2exe supports a diskless/"bundle" mode.

Both these projects are *much* more complex than this one and support lots of extra features, but sometimes you don't need that...

This project is (maybe) better if you want a single exe that can run any python script, or just want an exe that gives a python REPL.
Being simpler, this project should be easier to hack on or learn from.


## How it works

There's not much to it...

0. Use nim's [staticRead](https://nim-lang.org/docs/system.html#staticRead%2Cstring) to include `python-*-embedded.zip` and `bootstrap.py` inside compiled exe itself.
1. Use [zippy](https://github.com/guzba/zippy) to access the contents of the archive at runtime.
2. Use [memlib](https://github.com/khchen/memlib) to perform reflective dll loading of the embedded `python*.dll`. Reflective dll loading allows for loading the dll from memory rather than from disk. Hook `LdrLoadDll` and `K32EnumProcessModules` so other code using the dll can find it. n.b. currently using a fork until https://github.com/khchen/memlib/pull/3 is merged.
3. Call various functions in the (reflectively) loaded dll to partially initialize python. Configure python to not try to load anything from disk (not absolutely required, but prevents conflicts and means the exe doesn't run any code in the current directory)
4. Use [nimpy](https://github.com/yglukhov/nimpy) to initialize a python extension exporting some nim functions that can read data out of the `python*.zip` standard library (contained within the `...-embedded.zip`).
5. Run the embedded `bootsrap.py` code to install an import hook. This import hook uses the functions from (4) to support importing python modules. If a `.pyc` can be found that matches an import, a loader that returns the unmarshalled `.pyc` is provided. If a `.pyd` can be found, the returned loader reflectively loads the `.pyd` and calls the module's initialization routine.
6. Now that python's standard library can be imported, finish initializing python.
6. Reflectively load other `.dlls` inside the `...-embedded.zip`. This is required so extension modules that depend on these dlls work e.g. `ctypes` needs `_ctypes.pyd` which requires `libffi.dll`.
7. Run python code / REPL

## Is this a virus

No.

It uses reflective DLL loading, which is a technique some malware uses so that might upset particularly sensitive AVs.
Like python itself, it could be used to run a malicious script.