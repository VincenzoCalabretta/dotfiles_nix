{ pkgs, home-manager, nvim-module }:

pkgs.testers.nixosTest {
  name = "compiler-explorer-home-manager";

  nodes.machine = { pkgs, ... }: {
    imports = [ home-manager.nixosModules.home-manager ];

    users.users.v = {
      isNormalUser = true;
      uid = 1000;
    };

    environment.systemPackages = with pkgs; [ curl jq iproute2 ];

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.v = {
      imports = [ nvim-module ];
      home.username = "v";
      home.homeDirectory = "/home/v";
      home.stateVersion = "24.11";
      dotfiles.nvim.compilerExplorer = {
        enable = true;
        idleTimeoutSec = 2;
      };
    };

    system.stateVersion = "26.05";
  };

  testScript = ''
    import json
    import time

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-v.service")
    machine.succeed("loginctl enable-linger v")
    machine.succeed("systemctl start user@1000.service")
    machine.wait_until_succeeds("test -S /run/user/1000/bus")

    user_systemctl = "sudo -u v XDG_RUNTIME_DIR=/run/user/1000 systemctl --user"
    machine.succeed(f"{user_systemctl} daemon-reload")
    machine.succeed(f"{user_systemctl} start compiler-explorer.socket")

    with subtest("Home Manager socket is loopback-only and activates on demand"):
        machine.fail(f"{user_systemctl} is-active compiler-explorer.service")
        listeners = machine.succeed("ss -ltn")
        assert "127.0.0.1:10240" in listeners
        assert "0.0.0.0:10240" not in listeners
        assert "[::]:10240" not in listeners

        languages = json.loads(machine.succeed(
            "curl -fsS -H 'Accept: application/json' http://127.0.0.1:10240/api/languages"
        ))
        language_ids = {language["id"] for language in languages}
        assert {"c", "c++", "rust"}.issubset(language_ids)
        machine.succeed(f"{user_systemctl} is-active compiler-explorer.service")

    with subtest("user service compiles against a project header under HOME"):
        machine.succeed(
            "install -d -o v -g users /home/v/compiler-explorer-project/include && "
            "printf '#define PROJECT_VALUE 42\\n' > "
            "/home/v/compiler-explorer-project/include/project.h && "
            "chown v:users /home/v/compiler-explorer-project/include/project.h"
        )
        request = json.dumps({
            "source": '#include "project.h"\nint value() { return PROJECT_VALUE; }',
            "options": {
                "userArguments": "-O2 -I/home/v/compiler-explorer-project/include",
                "filters": {"execute": False, "labels": True},
            },
        })
        machine.succeed(
            "curl -fsS -H 'Accept: application/json' "
            "-H 'Content-Type: application/json' "
            f"--data-binary {json.dumps(request)} "
            "http://127.0.0.1:10240/api/compiler/nix-clang-cpp/compile "
            "| jq -e '.code == 0 and (.asm | length > 0)'"
        )

    with subtest("idle user service exits while activation socket remains"):
        time.sleep(4)
        machine.fail(f"{user_systemctl} is-active compiler-explorer.service")
        machine.succeed(f"{user_systemctl} is-active compiler-explorer.socket")
  '';
}
