# Third-party notices

The top-level MIT license covers original configuration and documentation in
this repository. It does not replace the licenses of copied files, generated
files, fetched Nix inputs, or programs configured by these dotfiles.

## Copied source

The following files are GNU libstdc++ GDB support code:

- `dotfiles/nvim/gdb/libstdcxx/v6/__init__.py`
- `dotfiles/nvim/gdb/libstdcxx/v6/printers.py`
- `dotfiles/nvim/gdb/libstdcxx/v6/xmethods.py`

They are copyright Free Software Foundation, Inc. and licensed under
GPL-3.0-or-later, as stated in their file headers. They are not MIT-licensed.
Redistributors must preserve the headers, provide the corresponding source,
and include `third_party_licenses/GPL-3.0-or-later.txt`. The surrounding local
registration/configuration code is MIT-licensed unless marked otherwise.

## Generated configuration

`hosts/home/hardware-configuration.nix` and
`hosts/server/hardware-configuration.nix` were produced by
`nixos-generate-config` and then retained as machine-specific configuration.
`dotfiles/i3/config` began as output from `i3-config-wizard` and was customized.
These configuration outputs contain declarative facts and local choices; no
NixOS or i3 executable/library is included. They are distributed under the
top-level MIT grant to the extent copyright applies to the repository author,
while any independently copyrightable upstream template fragment retains its
upstream terms.

## Fetched inputs and plugins

The Nix flake lock selects nixpkgs, Home Manager, and other inputs. Neovim's
plugin lock selects plugin revisions. These lockfiles are dependency metadata;
they do not vendor those projects. Each fetched input, package, editor plugin,
model server, and tool keeps its own license, and a binary/Nix-closure
distributor must carry the notices and source obligations of the exact
packages included in that closure.

No generated binary, vendor library, bitstream, PDF, extracted manual, or
board-support package is tracked in this repository as of this audit. Adding
one requires a provenance and redistribution review before publication.
