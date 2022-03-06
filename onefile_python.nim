import std/os
import std/strformat
import std/streams
import std/tables
import std/strutils

import zippy/ziparchives
import minhook
import winim/lean
import memlib
import nimpy
import nimpy/py_types
import argparse

import cpython_types


const DEBUG = false  # Print debug messages (in nim code, and in python loaders)
const EMBED_DLL = true  # Use the .dll embedded in the zip archive. If false, will require python310.dll to be in the PATH. If true, debugging may be harder as the dll is reflectively loaded


let p = newParser("onefile_python"):
  help("{prog}")
  flag("-V", "--version")
  option("-c", "--command", help="program passed in as string")
  arg("file", default=some(""), help="program read from script file")
  arg("arg", nargs=(-1), help="arguments passed to program in sys.argv[1:]")


template `//`(a, b: untyped) : untyped = a div b

converter falsey(i: int): bool = i != 0

func bytes(str: string): seq[byte] {.inline.} =
  ## Copy ``string`` memory into an immutable``seq[byte]``.
  let length = str.len
  if length > 0:
    result = newSeq[byte](length)
    copyMem(result[0].unsafeAddr, str[0].unsafeAddr, length)


# hook so python shows up for nimpy
proc K32EnumProcessModules(hProcess: HANDLE, lphModule: ptr UncheckedArray[HMODULE], cb: DWORD, cbNeeded: ptr DWORD): WINBOOL {. dynlib: "kernel32", importc: "K32EnumProcessModules", stdcall.}
proc myEnumProcessModules(hProcess: HANDLE, lphModule: ptr UncheckedArray[HMODULE], cb: DWORD, cbNeeded: ptr DWORD): WINBOOL {.stdcall, minhook: K32EnumProcessModules.} =
    result = K32EnumProcessModules(hProcess, lphModule, cb, cbNeeded)
    if result == 1:
        var sz = cbNeeded[] // 8
        var mx = cb // 8
        if DEBUG:
            echo fmt"EnumProcessModules(0x{cast[uint](hProcess):x}, 0x{cast[uint](lphModule):x}, 0x{cast[uint](cb):x}, 0x{cast[uint](cbNeeded):x} => {sz}) => {result}"
            echo fmt"   0x{cast[uint](lphModule[0]):x}, ..., 0x{cast[uint](lphModule[sz-1]):x}, 0x{cast[uint](lphModule[sz]):x}"
        if sz < mx:
            lphModule[sz] = LoadLibraryA("python310.dll")
            if DEBUG:
                echo fmt"   > Appending library handle: 0x{cast[uint](lphModule[0]):x}, ..., 0x{cast[uint](lphModule[sz-1]):x}, 0x{cast[uint](lphModule[sz]):x}"
                echo ""
            cbNeeded[] = sz + 8

    
enableHook(K32EnumProcessModules)


const python_310_embedded_zip = staticRead("python-3.10.1-embed-amd64.zip")  # TODO: easier to customize what version

var python_embedded = ZipArchive()
python_embedded.open(newStringStream(python_310_embedded_zip))

var python_stdlib = ZipArchive()
python_stdlib.open(newStringStream(python_embedded.contents["python310.zip"].contents))  # TODO: detect what version

when EMBED_DLL:
    var python = checkedLoadLib(python_embedded.contents["python310.dll"].contents.bytes)
    python.hook("python310.dll")  # TODO: detect what version
else:
    var python = "python310.dll"
# proc PyPreConfig_InitPythonConfig(preconfig: ptr PyPreConfig): void {. memlib: python, importc: "PyPreConfig_InitPythonConfig" .}
proc PyPreConfig_InitIsolatedConfig(preconfig: ptr PyPreConfig): void {. memlib: python, importc: "PyPreConfig_InitIsolatedConfig", cdecl .}
proc Py_PreInitialize(r: PyStatus, preconfig: ptr PyPreConfig): ptr PyStatus {. memlib: python, importc: "Py_PreInitialize", cdecl .}
proc Py_DecodeLocale(arg: cstring, size: pointer): pointer {. memlib: python, importc: "Py_DecodeLocale", cdecl .}
proc Py_SetProgramName(name: pointer): void {. memlib: python, importc: "Py_SetProgramName", cdecl .}
proc Py_SetPath(path: pointer): void {. memlib: python, importc: "Py_SetPath", cdecl .}
# proc PyConfig_InitPythonConfig(config: ptr PyConfig): void {. memlib: python, importc: "PyConfig_InitPythonConfig", cdecl .}
proc PyConfig_InitIsolatedConfig(config: ptr PyConfig): void {. memlib: python, importc: "PyConfig_InitIsolatedConfig", cdecl .}
proc PyConfig_SetArgv(r: PyStatus, config: ptr PyConfig, argc: int, argv: pointer): ptr PyStatus {. memlib: python, importc: "PyConfig_SetArgv", cdecl .}
proc Py_InitializeFromConfig(r: PyStatus, config: ptr PyConfig): ptr PyStatus {. memlib: python, importc: "Py_InitializeFromConfig", cdecl .}
proc PyUnicode_AsUTF8AndSize(obj: pointer, size: pointer): cstring {. memlib: python, importc: "PyUnicode_AsUTF8AndSize", cdecl .}
proc PyUnicode_FromString(str: cstring): pointer {. memlib: python, importc: "PyUnicode_FromString", cdecl .}
proc PyImport_GetModuleDict(): pointer {. memlib: python, importc: "PyImport_GetModuleDict", cdecl .}
proc PyImport_FixupExtensionObject(module: pointer, name: pointer, filename: pointer, modules: pointer): void {. memlib: python, importc: "_PyImport_FixupExtensionObject", cdecl .}
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


when DEBUG:
    proc print_repr(obj: pointer): void =
        var r = PyObject_Repr(obj)
        var s = PyUnicode_AsUTF8AndSize(r, nil)
        echo s

type
    PyInit = proc (): PPyObject {.stdcall.}


proc load_dlls(): void {. exportpy .} = 
    # TODO: foreach .dll in archive rather than hardcode
    for dllname in ["libffi-7.dll", "libcrypto-1_1.dll", "libssl-1_1.dll"]:
        let lib = checkedLoadLib(python_embedded.contents[dllname].contents.bytes)
        lib.hook(dllname)

proc pyd_has(name: string): bool {. exportpy .} =
    return python_embedded.contents.contains(name)

proc pyd_load(filename: string, modulename: string, spec: PPyObject): PPyObject {. exportpy .} =
    let moduleContent = python_embedded.contents[filename].contents.bytes
    let module = checkedLoadLib(moduleContent)
    let s: string = fmt"PyInit_{modulename}"
    var init_func = module.symAddr(s)
    var py_module = cast[PyInit](init_func)()
    # As per https://www.python.org/dev/peps/pep-0489/, modules can return either a module or a moduledef.
    # Multi-phase initialization (https://docs.python.org/3/c-api/module.html#low-level-module-creation-functions) requires that we call
    # `PyModule_FromDefAndSpec`

    # This is a hacky way to check if we are single or multi-phase, but `PyModule_Check` is a macro... 
    # could be better to read the struct property for type and work out something to comapre it to
    let repr = PyUnicode_AsUTF8AndSize(PyObject_Repr(cast[pointer](py_module)), nil)  # memory leak?
    if ($repr).startsWith("<moduledef"):  
        py_module = PyModule_FromDefAndSpec2(py_module, spec, 1013)
    return py_module

proc stdlib_has(name: string): bool {. exportpy .} =
    return python_stdlib.contents.contains(name)

proc stdlib_read(name: string): string {. exportpy .} =
    # nimpy seems to automatically decide whether this should be bytes or string
    # hopefully it never decides string...
    return python_stdlib.contents[name].contents

# Init this exe as a python module
proc PyInit_onefile_python(): pointer {. stdcall, importc: "PyInit_onefile_python" .}


const bootstrap_py = staticRead("bootstrap.py")


proc parse_args: auto = 
    try:
        return p.parse(commandLineParams())
    except ShortCircuit as e:
        if e.flag == "argparse_help":
            echo p.help
            quit(1)
    except UsageError:
        stderr.writeLine getCurrentExceptionMsg()
        quit(1)


proc main = 
    var r: PyStatus
    var status: ptr PyStatus
    var res: int

    var opts = parse_args()


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

    # Set up "nimporter" to expose pyd_has, pyd_load, stdlib_has, stdlib_read
    when DEBUG:
        echo "Loading onefile_python python module"
    let modules = PyImport_GetModuleDict()
    let own_module = PyInit_onefile_python()
    PyImport_FixupExtensionObject(own_module, PyUnicode_FromString("onefile_python"), PyUnicode_FromString("<memory>"), modules)

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
        echo "Error running nimporter.load_dlls()"
        return

    # run modes: command, TODO: module, file, interactive
    if opts.command != "":
        discard PyRun_SimpleString(opts.command.cstring)
    elif opts.file == "-" or opts.file == "":
        discard PyRun_InteractiveLoop(stdin, "stdin")
    elif opts.file != "-":
        let filename_str = Py_BuildValue("s", opts.file.cstring)
        let file = Py_fopen_obj(filename_str, "rb")
        if file != NULL:
            discard PyRun_SimpleFile(file, opts.file.cstring)
        else:
            echo fmt"can't open file '{opts.file}'"

main()