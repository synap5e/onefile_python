#[
    typedef struct PyPreConfig {
    int _config_init;
    int parse_argv;
    int isolated;
    int use_environment;
    int configure_locale;
    int coerce_c_locale;
    int coerce_c_locale_warn;
#ifdef MS_WINDOWS
    int legacy_windows_fs_encoding;
#endif
    int utf8_mode;
    int dev_mode;
    int allocator;
} PyPreConfig;
]#
type PyPreConfig* = object
    config_init*: clong
    parse_argv*: clong
    isolated*: clong
    use_environment*: clong
    configure_locale*: clong
    coerce_c_locale*: clong
    coerce_c_locale_warn*: clong
    legacy_windows_fs_encoding*: clong
    utf8_mode*: clong
    dev_mode*: clong
    allocator*: clong


#[
typedef struct {
    enum {
        _PyStatus_TYPE_OK=0,
        _PyStatus_TYPE_ERROR=1,
        _PyStatus_TYPE_EXIT=2
    } _type;
    const char *func;
    const char *err_msg;
    int exitcode;
} PyStatus;
]#
type PyStatus* = object
    type_o*: cint
    func_o*: cstring
    err_msg*: cstring
    exitcode*: cint

#[
    typedef struct PyConfig {
    int _config_init;     /* _PyConfigInitEnum value */

    int isolated;
    int use_environment;
    int dev_mode;
    int install_signal_handlers;
    int use_hash_seed;
    unsigned long hash_seed;
    int faulthandler;
    int tracemalloc;
    int import_time;
    int show_ref_count;
    int dump_refs;
    int malloc_stats;
    wchar_t *filesystem_encoding;
    wchar_t *filesystem_errors;
    wchar_t *pycache_prefix;
    int parse_argv;
    PyWideStringList orig_argv;
    PyWideStringList argv;
    PyWideStringList xoptions;
    PyWideStringList warnoptions;
    int site_import;
    int bytes_warning;
    int warn_default_encoding;
    int inspect;
    int interactive;
    int optimization_level;
    int parser_debug;
    int write_bytecode;
    int verbose;
    int quiet;
    int user_site_directory;
    int configure_c_stdio;
    int buffered_stdio;
    wchar_t *stdio_encoding;
    wchar_t *stdio_errors;
#ifdef MS_WINDOWS
    int legacy_windows_stdio;
#endif
    wchar_t *check_hash_pycs_mode;

    /* --- Path configuration inputs ------------ */
    int pathconfig_warnings;
    wchar_t *program_name;
    wchar_t *pythonpath_env;
    wchar_t *home;
    wchar_t *platlibdir;

    /* --- Path configuration outputs ----------- */
    int module_search_paths_set;
    PyWideStringList module_search_paths;
    wchar_t *executable;
    wchar_t *base_executable;
    wchar_t *prefix;
    wchar_t *base_prefix;
    wchar_t *exec_prefix;
    wchar_t *base_exec_prefix;

    /* --- Parameter only used by Py_Main() ---------- */
    int skip_source_first_line;
    wchar_t *run_command;
    wchar_t *run_module;
    wchar_t *run_filename;

    /* --- Private fields ---------------------------- */

    // Install importlib? If equals to 0, importlib is not initialized at all.
    // Needed by freeze_importlib.
    int _install_importlib;

    // If equal to 0, stop Python initialization before the "main" phase.
    int _init_main;

    // If non-zero, disallow threads, subprocesses, and fork.
    // Default: 0.
    int _isolated_interpreter;
} PyConfig;
]#
type PyConfig* = object
    config_init*: cint
    isolated*: cint
    use_environment*: cint
    dev_mode*: cint
    install_signal_handlers*: cint
    use_hash_seed*: cint
    hash_seed*: clong
    faulthandler*: cint
    tracemalloc*: cint
    import_time*: cint
    show_ref_count*: cint
    dump_refs*: cint
    malloc_stats*: cint

    filesystem_encoding*: pointer
    filesystem_errors*: pointer
    pycache_prefix*: pointer

    parse_argv*: cint
    orig_argv_sz*: pointer
    orig_argv_data*: pointer
    argv_sz*: pointer
    argv_data*: pointer
    xoptions_sz*: pointer
    xoptions_data*: pointer
    warnoptions_sz*: pointer
    warnoptions_data*: pointer

    site_import*: cint
    bytes_warning*: cint
    warn_default_encoding*: cint
    inspect*: cint
    interactive*: cint
    optimization_level*: cint
    parser_debug*: cint
    write_bytecode*: cint
    verbose*: cint
    quiet*: cint
    user_site_directory*: cint
    configure_c_stdio*: cint
    buffered_stdio*: cint

    stdio_encoding*: pointer
    stdio_errors*: pointer

    legacy_windows_stdio*: cint

    check_hash_pycs_mode*: pointer

    pathconfig_warnings*: cint
    program_name*: pointer
    pythonpath_env*: pointer
    home*: pointer
    platlibdir*: pointer

    module_search_paths_set*: cint
    module_search_paths_sz*: pointer
    module_search_paths_data*: pointer
    executable*: pointer
    base_executable*: pointer
    prefix*: pointer
    base_prefix*: pointer
    exec_prefix*: pointer
    base_exec_prefix*: pointer

    skip_source_first_line*: cint
    run_command*: pointer
    run_module*: pointer
    run_filename*: pointer

    install_importlib*: cint
    init_main*: cint
    isolated_interpreter*: cint