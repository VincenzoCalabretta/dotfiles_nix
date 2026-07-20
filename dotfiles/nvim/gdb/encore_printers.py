# ~/.config/nvim/gdb/encore_printers.py
# GDB pretty-printers for Encore project types.
# Loaded at GDB startup via -iex in the nvim-dap adapter (lua/dap_modules/config.lua).

import gdb
import gdb.printing


class SafeMapPrinter:
    """
    Pretty-print Encore::Utils::SafeMap<K,V>.

    Delegates tree iteration to the libstdc++ std::map printer, then consumes
    its alternating (key, value) child pairs and re-emits them as single entries
    with the key folded into the label and integer values formatted as hex.
    """

    def __init__(self, val):
        self.val = val
        self._base = self._get_base(val)
        self._delegate = gdb.default_visualizer(self._base) if self._base is not None else None
        self._size = self._read_size()

    @staticmethod
    def _get_base(val):
        """Return the std::map base sub-object via raw pointer cast."""
        try:
            addr = val.address
            for field in val.type.strip_typedefs().fields():
                if not field.is_base_class:
                    continue
                if addr is not None:
                    return addr.cast(field.type.pointer()).dereference()
                return val.cast(field.type)
        except gdb.error:
            pass
        return None

    def _read_size(self):
        if self._base is None:
            return 0
        try:
            return int(self._base['_M_t']['_M_impl']['_M_node_count'])
        except gdb.error:
            return 0

    @staticmethod
    def _hex(val):
        """Return '0x…' for scalar/pointer types; None for complex ones."""
        try:
            return '0x{:x}'.format(int(val))
        except (gdb.error, TypeError, ValueError):
            return None

    def to_string(self):
        return 'SafeMap with {} element{}'.format(
            self._size, '' if self._size == 1 else 's')

    def children(self):
        if self._delegate is None or not hasattr(self._delegate, 'children'):
            return
        it = iter(self._delegate.children())
        try:
            while True:
                # libstdc++ yields interleaved: (name, key_val), (name, mapped_val)
                _, k_val = next(it)
                _, v_val = next(it)
                k = self._hex(k_val) or str(k_val)
                v_hex = self._hex(v_val)
                # Yield raw gdb.Value for complex types so their own printer runs
                yield '[{}]'.format(k), v_hex if v_hex is not None else v_val
        except StopIteration:
            pass

    def display_hint(self):
        # 'array' (not 'map'): the key is already in the child name,
        # so no special key/value grouping is needed by the client.
        return 'array'


def _build():
    pp = gdb.printing.RegexpCollectionPrettyPrinter('encore-utils')
    pp.add_printer('SafeMap', r'^Encore::Utils::SafeMap<', SafeMapPrinter)
    return pp


gdb.printing.register_pretty_printer(None, _build(), replace=True)
