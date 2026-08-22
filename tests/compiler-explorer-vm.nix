{ pkgs, compiler-explorer-module }:

pkgs.testers.nixosTest {
  name = "compiler-explorer";

  nodes.machine = { pkgs, ... }: {
    imports = [ compiler-explorer-module ];

    dotfiles.compiler-explorer = {
      enable = true;
      idleTimeoutSec = 2;
    };

    environment.systemPackages = with pkgs; [ curl jq iproute2 ];
    system.stateVersion = "26.05";
  };

  testScript = ''
    import json
    import time

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("compiler-explorer.socket")

    with subtest("socket is loopback-only and service starts on demand"):
        machine.fail("systemctl is-active compiler-explorer.service")
        listeners = machine.succeed("ss -ltn")
        assert "127.0.0.1:10240" in listeners
        assert "0.0.0.0:10240" not in listeners
        assert "[::]:10240" not in listeners

        languages = json.loads(machine.succeed(
            "curl -fsS -H 'Accept: application/json' http://127.0.0.1:10240/api/languages"
        ))
        language_ids = {language["id"] for language in languages}
        assert {"c", "c++", "rust"}.issubset(language_ids)
        machine.wait_for_unit("compiler-explorer.service")

    expected_compilers = {
        "c": {"nix-gcc-c", "nix-clang-c"},
        "c++": {"nix-gcc-cpp", "nix-clang-cpp"},
        "rust": {"nix-rustc"},
    }

    with subtest("only the Nix-pinned compiler catalog is advertised"):
        for language, expected in expected_compilers.items():
            compilers = json.loads(machine.succeed(
                "curl -fsS -H 'Accept: application/json' "
                f"'http://127.0.0.1:10240/api/compilers/{language}?fields=all'"
            ))
            assert {compiler["id"] for compiler in compilers} == expected
            assert all(not compiler["supportsExecute"] for compiler in compilers)

    sources = {
        "nix-gcc-c": ("int square(int x) { return x * x; }", "-O2"),
        "nix-clang-cpp": ("int square(int x) { return x * x; }", "-O2"),
        "nix-rustc": ('pub fn main() { println!("hello"); }', "-C opt-level=2"),
    }

    with subtest("C, C++, and Rust compile to assembly without execution"):
        for compiler, (source, arguments) in sources.items():
            request = json.dumps({
                "source": source,
                "options": {
                    "userArguments": arguments,
                    "filters": {"execute": False, "labels": True},
                },
            })
            machine.succeed(
                "curl -fsS -H 'Accept: application/json' "
                "-H 'Content-Type: application/json' "
                f"--data-binary {json.dumps(request)} "
                f"http://127.0.0.1:10240/api/compiler/{compiler}/compile "
                "| jq -e '.code == 0 and (.asm | length > 0)'"
            )

    with subtest("idle service exits while activation socket remains"):
        time.sleep(4)
        machine.fail("systemctl is-active compiler-explorer.service")
        machine.succeed("systemctl is-active compiler-explorer.socket")
  '';
}
