import sys
import os
import glob

# Bundled printers live alongside this file in $XDG_CONFIG_HOME/nvim/gdb/
_xdg   = os.environ.get('XDG_CONFIG_HOME', os.path.join(os.path.expanduser('~'), '.config'))
_bundled = os.path.join(_xdg, 'nvim', 'gdb')

# System-installed printers (Arch, Debian, RHEL, …)
_system = (
    sorted(glob.glob('/usr/share/gcc-*/python'), reverse=True)
    + glob.glob('/usr/share/gcc/python')
    + sorted(glob.glob('/usr/lib/gcc/*/*/python'), reverse=True)
    + sorted(glob.glob('/usr/lib/gcc/*/python'), reverse=True)
)

for _p in [_bundled] + _system:
    if os.path.isdir(os.path.join(_p, 'libstdcxx')):
        if _p not in sys.path:
            sys.path.insert(0, _p)
        break

try:
    from libstdcxx.v6 import register_libstdcxx_printers
    register_libstdcxx_printers(None)
except RuntimeError:
    pass  # already registered
except ImportError:
    pass  # not available anywhere
