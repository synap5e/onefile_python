import std/os
import std/strformat
import std/streams
import std/tables
import std/strutils

import zippy/ziparchives
import winim/lean
import memlib
import nimpy
import nimpy/py_types
import argparse

import cpython_types


const DEBUG = defined(debug)  # Print debug messages (in nim code, and in python loaders)
const EMBED_DLL = not defined(dont_embedd_dll)  # Use the .dll embedded in the zip archive. If false, will require python310.dll to be in the PATH. If true, debugging may be harder as the dll is reflectively loaded

const PYTHON_EMBEDDED_FILE = "python-3.10.1-embed-amd64.zip"
when defined(staged):
    const PYTHON_EMBEDDED_URL = "https://www.python.org/ftp/python/3.10.1"


let arg_parser = newParser("onefile_python"):
  help("{prog}")
  flag("-V", "--version")
  option("-c", "--command", help="Program; passed in as string")
  arg("file", default=some(""), help="Program; read from script file/URL ('-' or empty for interactive)")
  arg("arg", nargs=(-1), help="Arguments passed to program in sys.argv[1:]")
  when defined(staged):
    option("-d", "--download", help=fmt"Download `{PYTHON_EMBEDDED_FILE}` from this url", default=some(PYTHON_EMBEDDED_URL))
when defined(staged):
    const extra_help = fmt"Alternatively specify the download URL in the app filename e.g. `blabla(10.0.0.1)foobar.exe` means download from `https://10.0.0.1/{PYTHON_EMBEDDED_FILE}`."
else:
    const extra_help = ""


template `//`(a, b: untyped) : untyped = a div b

converter falsey(i: int): bool = i != 0

func bytes(str: string): seq[byte] {.inline.} =
  ## Copy ``string`` memory into an immutable``seq[byte]``.
  let length = str.len
  if length > 0:
    result = newSeq[byte](length)
    copyMem(result[0].unsafeAddr, str[0].unsafeAddr, length)


proc parse_args: auto =
    try:
        return arg_parser.parse(commandLineParams())
    except ShortCircuit as e:
        if e.flag == "argparse_help":
            echo arg_parser.help
            echo extra_help
            quit(1)
    except UsageError:
        stderr.writeLine getCurrentExceptionMsg()
        quit(1)

var opts = parse_args()

when not defined(staged):
    const python_310_embedded_zip = staticRead(PYTHON_EMBEDDED_FILE)
else:
    var downloadUrl = opts.download & "/" & PYTHON_EMBEDDED_FILE
    let appFileName = getAppFilename().splitPath().tail
    if appFileName.count("(") == 1 and appFileName.count(")") == 1 and appFileName.find(")") > appFileName.find("("):
        downloadUrl = "http://" & appFileName.substr(appFileName.find("(") + 1, appFileName.find(")") - 1) & "/" & PYTHON_EMBEDDED_FILE

    import puppy
    echo fmt"Downloading from '{downloadUrl}'..."
    let python_310_embedded_zip = fetch(downloadUrl)
    echo "\tDone"

var python_embedded = ZipArchive()
python_embedded.open(newStringStream(python_310_embedded_zip))

var python_stdlib = ZipArchive()
python_stdlib.open(newStringStream(python_embedded.contents["python310.zip"].contents))  # TODO: detect what version

const dll_name = "python310.dll"


when EMBED_DLL:
    let python = checkedLoadLib(python_embedded.contents[dll_name].contents.bytes)
    python.hook(dll_name)  # TODO: detect what version
else:
    let python = dll_name
# proc PyPreConfig_InitPythonConfig(preconfig: ptr PyPreConfig): void {. memlib: python, importc: "PyPreConfig_InitPythonConfig" .}
proc PyPreConfig_InitIsolatedConfig(preconfig: ptr PyPreConfig): void {. memlib: python, importc: "PyPreConfig_InitIsolatedConfig", cdecl .}
proc Py_PreInitialize(r: PyStatus, preconfig: ptr PyPreConfig): ptr PyStatus {. memlib: python, importc: "Py_PreInitialize", cdecl .}
proc Py_DecodeLocale(arg: cstring, size: pointer): pointer {. memlib: python, importc: "Py_DecodeLocale", cdecl .}
proc Py_SetProgramName(name: pointer): void {. memlib: python, importc: "Py_SetProgramName", cdecl .}
proc Py_SetPath(path: pointer): void {. memlib: python, importc: "Py_SetPath", cdecl .}
proc PyConfig_InitIsolatedConfig(config: ptr PyConfig): void {. memlib: python, importc: "PyConfig_InitIsolatedConfig", cdecl .}
proc PyConfig_SetArgv(r: PyStatus, config: ptr PyConfig, argc: int, argv: pointer): ptr PyStatus {. memlib: python, importc: "PyConfig_SetArgv", cdecl .}
proc Py_InitializeFromConfig(r: PyStatus, config: ptr PyConfig): ptr PyStatus {. memlib: python, importc: "Py_InitializeFromConfig", cdecl .}
proc PyUnicode_AsUTF8AndSize(obj: pointer, size: pointer): cstring {. memlib: python, importc: "PyUnicode_AsUTF8AndSize", cdecl .}
proc PyUnicode_FromString(str: cstring): PPyObject {. memlib: python, importc: "PyUnicode_FromString", cdecl .}
proc PyImport_GetModuleDict(): PPyObject {. memlib: python, importc: "PyImport_GetModuleDict", cdecl .}
proc PyImport_FixupExtensionObject(module: PPyObject, name: PPyObject, filename: PPyObject, modules: PPyObject): int {. memlib: python, importc: "_PyImport_FixupExtensionObject", cdecl .}
proc PyModule_FromDefAndSpec2(def: PPyObject, spec: PPyObject, module: int): PPyObject {. memlib: python, importc: "PyModule_FromDefAndSpec2", cdecl .}

proc Py_BuildValue(v1: cstring, v2: cstring): pointer {. memlib: python, importc: "Py_BuildValue", cdecl .}
proc Py_fopen_obj(path: pointer, mode: cstring): pointer {. memlib: python, importc: "_Py_fopen_obj", cdecl .}
proc PyRun_SimpleFile(fp: pointer, filename: cstring): cint {. memlib: python, importc: "PyRun_SimpleFile", cdecl .}

proc Py_GetVersion(): cstring {. memlib: python, importc: "Py_GetVersion", cdecl .}

proc PyRun_SimpleString(code: cstring): int {. memlib: python, importc: "PyRun_SimpleString", cdecl .}
proc PyRun_InteractiveLoop(file: pointer, filename: cstring): int {. memlib: python, importc: "PyRun_InteractiveLoop", cdecl .}
proc PyObject_Repr(obj: pointer): cstring {. memlib: python, importc: "PyObject_Repr", cdecl .}
proc Py_InitializeMain(r: ptr PyStatus): ptr PyStatus {. memlib: python, importc: "_Py_InitializeMain", cdecl .}
proc PyStatus_Exception(status: ptr PyStatus): int {. memlib: python, importc: "PyStatus_Exception", cdecl .}
proc Py_ExitStatusException(status: ptr PyStatus): void {. memlib: python, importc: "Py_ExitStatusException", cdecl .}

let python_dll_handle = LoadLibraryA(dll_name)

# echo "python dll loaded"
# discard readLine(stdin)

when DEBUG:
    proc repr(obj: pointer): string =
        return $PyUnicode_AsUTF8AndSize(PyObject_Repr(obj), nil)

    proc debug(s: string): void =
        echo s
    
else:
    proc debug(s: string): void = discard

type
    PyInit = proc (): PPyObject {.stdcall.}


proc load_dlls(): void {. exportpy .} = 
    # TODO: foreach .dll in archive rather than hardcode
    for dllname in [ "libffi-7.dll", "libcrypto-1_1.dll", "libssl-1_1.dll", "sqlite3.dll"]:
        let lib = checkedLoadLib(python_embedded.contents[dllname].contents.bytes)
        lib.hook(dllname)
        debug(fmt"Loaded {dllname} => 0x{LoadLibraryA(dllname):x}")

proc pyzip_has_pyd(name: string): bool {. exportpy .} =
    return python_embedded.contents.contains(name)

proc pyzip_load_pyd(filename: string, modulename: string, spec: PPyObject): PPyObject {. exportpy .} =
    debug(fmt"onefile_python.nim   pyd_load('{filename}', '{modulename}', {repr(spec)})")
    let moduleContent = python_embedded.contents[filename].contents.bytes
    let module = checkedLoadLib(moduleContent)
    debug(fmt"                     loaded library in memory from {moduleContent.len} bytes")
    let s: string = fmt"PyInit_{modulename}"
    var init_func = module.symAddr(s)
    debug(fmt"                     {s} = 0x{cast[int](init_func):x}")
    var py_module = cast[PyInit](init_func)()
    debug(fmt"onefile_python.nim   PyInit_{modulename}() => {repr(py_module)}")
    # As per https://www.python.org/dev/peps/pep-0489/, modules can return either a module or a moduledef.
    # Multi-phase initialization (https://docs.python.org/3/c-api/module.html#low-level-module-creation-functions) requires that we call
    # `PyModule_FromDefAndSpec`

    # This is a hacky way to check if we are single or multi-phase, but `PyModule_Check` is a macro... 
    # could be better to read the struct property for type and work out something to comapre it to
    let r = PyUnicode_AsUTF8AndSize(PyObject_Repr(cast[pointer](py_module)), nil)  # memory leak?
    if ($r).startsWith("<moduledef"):  # PyObject_TypeCheck(py_module, &PyModuleDef_Type)
        debug(fmt"                     multi-phase init...")
        py_module = PyModule_FromDefAndSpec2(py_module, spec, 1013)
        debug(fmt"                     PyModule_FromDefAndSpec2(...) => {repr(py_module)}")
    else:
        debug(fmt"                     single-phase init...")
        if PyImport_FixupExtensionObject(
            py_module,
            PyUnicode_FromString(modulename),
            PyUnicode_FromString(fmt"<memory: {modulename} - {moduleContent.len} bytes>".cstring),
            PyImport_GetModuleDict(),
        ) < 0:
            echo fmt"PyImport_FixupExtensionObject failed!"
            return nil
        debug(fmt"                     PyImport_FixupExtensionObject(...) => {repr(py_module)}")
    return py_module

proc pyzip_stdlib_has(name: string): bool {. exportpy .} =
    return python_stdlib.contents.contains(name)

proc pyzip_stdlib_read(name: string): string {. exportpy .} =
    # nimpy seems to automatically decide whether this should be bytes or string. Hopefully it never decides string...
    return python_stdlib.contents[name].contents

type PyMemoryModule = ref object of PyNimObjectExperimental
    module: MemoryModule

proc loadlib(data: seq[byte]): PyMemoryModule {. exportpy .} =
    return PyMemoryModule(module: checkedLoadLib(data))

proc hook(self: PyMemoryModule, name: string): void {. exportpy .} =
    self.module.hook(name)

proc unhook(self: PyMemoryModule): void {. exportpy .} =
    self.module.unhook()


# Init this exe as a python module
proc PyInit_onefile_python(): PPyObject {. stdcall, importc: "PyInit_onefile_python" .}


const bootstrap_py = staticRead("bootstrap.py")


proc main = 
    var r: PyStatus
    var status: ptr PyStatus
    var res: int

    # Initial configuration - ignore argv, env vars (PYTHONHOME), any files, etc.
    var preconfig: PyPreConfig
    PyPreConfig_InitIsolatedConfig(preconfig)
    preconfig.parse_argv = 0
    preconfig.use_environment = 0
    preconfig.utf8_mode = 1
    when DEBUG:
        echo fmt"Py_PreInitialize({preconfig})"
    status = Py_PreInitialize(r, preconfig)
    if PyStatus_Exception(status):
        Py_ExitStatusException(status)
        return
    Py_SetProgramName(Py_DecodeLocale("main", NULL))  # TODO: what should this name be?
    Py_SetPath(Py_DecodeLocale("NUL", NULL))  # Use the NUL file to prevent loading files from ANYWHERE

    # Use `init_main = 0` to avoid full python initiliation while the standard library is not available
    var config: PyConfig
    PyConfig_InitIsolatedConfig(config)
    config.init_main = 0
    when DEBUG:
        echo fmt"Py_InitializeFromConfig({config})"

    var argv: array[256, pointer]
    var argc = 0
    if opts.file != "":
        argv[argc] = Py_DecodeLocale(opts.file.cstring, NULL)
        argc += 1
    for arg in opts.arg:
        argv[argc] = Py_DecodeLocale(arg.cstring, NULL)
        argc += 1
        if argc >= 256:
            break
    discard PyConfig_SetArgv(r, config, argc, argv.addr)

    status = Py_InitializeFromConfig(r, config)
    if PyStatus_Exception(status):
        Py_ExitStatusException(status)
        return

    if opts.version:
        echo $Py_GetVersion()
        quit()

    # Required to let ctypes.pythonapi point to pythonX.dll instead of onefile_python.exe 
    discard PyRun_SimpleString(fmt"import sys; sys.dllhandle = {python_dll_handle}".cstring)
    when DEBUG:
        echo fmt"Setting sys.dllhandle = {python_dll_handle}"

    # Set up "nimporter" to expose pyd_has, pyd_load, stdlib_has, stdlib_read
    when DEBUG:
        echo "Loading onefile_python python module"
    let own_module = PyInit_onefile_python()
    discard PyImport_FixupExtensionObject(own_module, PyUnicode_FromString("onefile_python"), PyUnicode_FromString("<memory>"), PyImport_GetModuleDict())

    # Run `bootstrap.py` to install import hooks
    when DEBUG:
        discard PyRun_SimpleString("DEBUG = True\n")
    res = PyRun_SimpleString(bootstrap_py)
    if res > 0:
        echo "Error running bootstrap.py"
        return

    # Finish python initialization - this will import parts of the standard library
    when DEBUG:
        echo "Py_InitializeMain()"
    status = Py_InitializeMain(r)
    if PyStatus_Exception(status):
        Py_ExitStatusException(status)
        return

    # Load dlls in the embedded archive. This seems to trigger AV if we call the nim function directly, but calling it via python is enough to bypass...
    res = PyRun_SimpleString("""
import onefile_python
onefile_python.load_dlls()
""")
    if res > 0:
        echo "Error running onefile_python.load_dlls()"
        return

    if opts.command != "":
        discard PyRun_SimpleString(opts.command.cstring)
    elif opts.file == "-" or opts.file == "":
        discard PyRun_InteractiveLoop(stdin, "stdin")
    elif opts.file.find("http://") == 0 or opts.file.find("https://") == 0:
        # Hacky to use python, but means we don't need -d:ssl in the nim build
        discard PyRun_SimpleString("import urllib.request")
        discard PyRun_SimpleString(fmt"exec(urllib.request.urlopen('{opts.file.cstring}').read().decode())".cstring)
    elif opts.file != "-":
        let filename_str = Py_BuildValue("s", opts.file.cstring)
        let file = Py_fopen_obj(filename_str, "rb")
        if file != NULL:
            discard PyRun_SimpleFile(file, opts.file.cstring)
        else:
            echo fmt"can't open file '{opts.file}'"

main()