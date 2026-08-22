{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_24,
  gnumake,
  rsync,
  gcc,
  clang,
  rustc,
  binutils,
  coreutils,
}:

buildNpmPackage rec {
  pname = "compiler-explorer";
  version = "unstable-2026-08-22";

  src = fetchFromGitHub {
    owner = "compiler-explorer";
    repo = "compiler-explorer";
    rev = "b024d90279b7d65023d5339dee131e263b6d1a35";
    hash = "sha256-KuXffxZ2kXX8lwudIFmaPoZTH6lqQ90YlyzbdQzrOOE=";
  };

  nodejs = nodejs_24;
  npmDepsHash = "sha256-Dacq+B4LfCZsKnTEtppaEq+WPu1Go8qIj6XMcjvpRSE=";
  makeCacheWritable = true;
  CYPRESS_INSTALL_BINARY = "0";

  # Fix upstream's Express-5-incompatible systemd idle hook and reset the
  # timer directly from the HTTP server, including for handled routes.
  patches = [ ./compiler-explorer-systemd-idle.patch ];

  nativeBuildInputs = [
    gnumake
    makeWrapper
    rsync
  ];

  buildPhase = ''
    runHook preBuild
    make scripts
    npm run webpack
    npm run ts-compile
    npm prune --omit=dev --ignore-scripts --offline
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/compiler-explorer" "$out/bin"
    cp -r out node_modules examples "$out/lib/compiler-explorer/"
    cp -r etc "$out/lib/compiler-explorer/"

    cat > "$out/lib/compiler-explorer/etc/config/compiler-explorer.local.properties" <<'EOF'
restrictToLanguages=c,c++,rust
supportsExecute=false
compilerCacheConfig=InMemory(100)
storageSolution=null
textBanner=Compilation provided by the local Nix Compiler Explorer
EOF

    cat > "$out/lib/compiler-explorer/etc/config/c.local.properties" <<'EOF'
compilers=nix-gcc-c:nix-clang-c
defaultCompiler=nix-gcc-c
supportsExecute=false
tools=
demangler=${binutils}/bin/c++filt
objdumper=${binutils}/bin/objdump
compiler.nix-gcc-c.exe=${gcc}/bin/gcc
compiler.nix-gcc-c.name=GCC ${gcc.version} (Nix)
compiler.nix-gcc-c.supportsExecute=false
compiler.nix-clang-c.exe=${clang}/bin/clang
compiler.nix-clang-c.name=Clang ${clang.version} (Nix)
compiler.nix-clang-c.compilerType=clang
compiler.nix-clang-c.intelAsm=-mllvm --x86-asm-syntax=intel
compiler.nix-clang-c.supportsExecute=false
EOF

    cat > "$out/lib/compiler-explorer/etc/config/c++.local.properties" <<'EOF'
compilers=nix-gcc-cpp:nix-clang-cpp
defaultCompiler=nix-gcc-cpp
supportsExecute=false
tools=
demangler=${binutils}/bin/c++filt
objdumper=${binutils}/bin/objdump
compiler.nix-gcc-cpp.exe=${gcc}/bin/g++
compiler.nix-gcc-cpp.name=G++ ${gcc.version} (Nix)
compiler.nix-gcc-cpp.supportsExecute=false
compiler.nix-clang-cpp.exe=${clang}/bin/clang++
compiler.nix-clang-cpp.name=Clang++ ${clang.version} (Nix)
compiler.nix-clang-cpp.compilerType=clang
compiler.nix-clang-cpp.intelAsm=-mllvm --x86-asm-syntax=intel
compiler.nix-clang-cpp.supportsExecute=false
EOF

    cat > "$out/lib/compiler-explorer/etc/config/rust.local.properties" <<'EOF'
compilers=nix-rustc
defaultCompiler=nix-rustc
supportsExecute=false
tools=
demangler=${binutils}/bin/c++filt
objdumper=${binutils}/bin/objdump
llvmObjdumper=${binutils}/bin/objdump
compiler.nix-rustc.exe=${rustc}/bin/rustc
compiler.nix-rustc.name=rustc ${rustc.version} (Nix)
compiler.nix-rustc.supportsExecute=false
EOF

    makeWrapper ${nodejs_24}/bin/node "$out/bin/compiler-explorer" \
      --set NODE_ENV production \
      --chdir "$out/lib/compiler-explorer" \
      --prefix PATH : ${lib.makeBinPath [ gcc clang rustc binutils coreutils ]} \
      --add-flags "$out/lib/compiler-explorer/out/dist/app.js" \
      --add-flags "--dist" \
      --add-flags "--root-dir $out/lib/compiler-explorer/etc" \
      --add-flags "--static $out/lib/compiler-explorer/out/webpack/static" \
      --add-flags "--language c c++ rust" \
      --add-flags "--no-remote-fetch" \
      --add-flags "--exit-on-compiler-failure"

    runHook postInstall
  '';

  meta = {
    description = "Interactively explore compiler output";
    homepage = "https://github.com/compiler-explorer/compiler-explorer";
    license = lib.licenses.bsd2;
    mainProgram = "compiler-explorer";
    platforms = lib.platforms.linux;
  };
}
