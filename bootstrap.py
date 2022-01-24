import sys
import marshal
import _imp
import _frozen_importlib_external as _bootstrap_external
import _frozen_importlib as _bootstrap

from nimporter import *

_bootstrap._install_external_importers()
_bootstrap_external._set_bootstrap_module(_bootstrap)


DEBUG = globals().get('DEBUG', False)
def debug(s: str):
    if DEBUG:
        print(s, file=sys.stderr)


class InMemoryExtensionLoader:
    def __init__(self, filename: str):
        self.filename = filename

    def create_module(self, spec):
        debug(f'InMemoryExtensionLoader.load_module({self.filename=!r}, {spec=!r})')
        module = pyd_load(self.filename, spec.name, spec)
        debug(f'\t{module=}')
        return module

    def exec_module(self, module):
        _imp.exec_dynamic(module)


class InMemoryBytecodeLoader(_bootstrap_external._LoaderBasics):

    def __init__(self, filename: str):
        self.filename = filename

    def get_code(self, fullname):
        debug(f'InMemoryBytecodeLoader.get_code({self.filename=!r}, {fullname=!r})')

        pyc = stdlib_read(self.filename)
        code = marshal.loads(pyc[16:])
        
        debug(f'\t{code=}')
        return code


class InMemoryFinder:
    def find_spec(self, fullname, path, target=None):
        debug(f'InMemoryFinder.find_spec(fullname={fullname!r}, path={path!r}, target={target!r})')
        
        loader = None
        submodule_search_locations = None

        if '.' in fullname:
            package_name, module_name = fullname.split('.', 1)
        else:
            package_name = fullname
            module_name = ''
        module_path = module_name.replace('.', '/')

        pyd = package_name + '.pyd'
        if module_path:
            init = '/'.join([package_name, module_path, '__init__.pyc'])
        else:
            init = '/'.join([package_name, '__init__.pyc'])
        module = '/'.join([package_name, module_path + '.pyc'])
        single_file = package_name + '.pyc'

        debug(f'\tChecking {[init, module, single_file]}')

        if pyd_has(pyd):
            debug(f'\t> found pyd: {pyd!r}')
            loader = InMemoryExtensionLoader(pyd)
        elif stdlib_has(init):
            debug(f'\t> found init: {init!r} (setting submodule_search_locations)')
            loader = InMemoryBytecodeLoader(init)
            submodule_search_locations = [f'<{fullname}>']
        elif stdlib_has(module):
            debug(f'\t> found module: {module!r}')
            loader = InMemoryBytecodeLoader(module)
        elif stdlib_has(single_file):
            debug(f'\t> found single file: {single_file!r}')
            loader = InMemoryBytecodeLoader(single_file)
        
        if loader:
            return _bootstrap_external.spec_from_file_location(
                fullname, 
                loader=loader, 
                submodule_search_locations=submodule_search_locations
            )
        else:
            debug(f'\t> not found')

sys.meta_path.insert(1, InMemoryFinder())
debug(sys.meta_path)
