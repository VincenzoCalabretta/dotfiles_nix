# Proves the automatable points of CHECKLIST.md's "Secrets provisioning"
# section: given the secrets a human provisions by hand (WireGuard config,
# Forgejo registration token, SSH deploy key), the shared modules produce
# exactly the end state the checklist promises — users, permissions,
# systemd units, group membership. Also exercises tools/capture-host.sh's
# actual rewrite/guardrail logic against fixture files.
#
# Out of scope, by design: registering with the real Forgejo instance
# (needs the actual external server — see CHECKLIST.md's <!-- manual -->
# markers), and anything that requires real hardware.
{ pkgs, capture-host-script, wireguard-module
, forgejo-runner-module, netdebug-module, wireshark-module
}:

pkgs.testers.nixosTest {
  name = "checklist-secrets-provisioning";

  nodes.machine = { pkgs, ... }: {
    imports = [
      wireguard-module
      forgejo-runner-module
      netdebug-module
      wireshark-module
    ];

    # Deliberately not importing modules/nixos-base.nix: its
    # nixpkgs.config.allowUnfree conflicts with testers.nixosTest's
    # externally-supplied pkgs (can't reapply nixpkgs.config on an
    # already-realized package set), and none of the modules under test
    # here need it.
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    users.users.v = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    environment.systemPackages = [ pkgs.git ];

    dotfiles.wireguard.enable = true;
    dotfiles.wireshark = {
      enable = true;
      user = "v";
    };
    dotfiles.netdebug = {
      enable = true;
      user = "v";
    };
    dotfiles.forgejo-runner = {
      enable = true;
      url = "https://10.10.0.101:3000";
    };

    system.stateVersion = "26.05";
  };

  testScript = ''
    import time

    machine.wait_for_unit("multi-user.target")

    with subtest("checklist: WireGuard secret provisioning brings up wg1"):
        key = machine.succeed("wg genkey").strip()
        machine.succeed(
            "install -d -m700 /etc/wireguard && "
            f"printf '[Interface]\\nPrivateKey = {key}\\nAddress = 10.10.0.99/24\\n' "
            "> /etc/wireguard/wg1.conf && chmod 600 /etc/wireguard/wg1.conf"
        )
        machine.succeed("systemctl restart wg-quick-wg1.service")
        machine.wait_for_unit("wg-quick-wg1.service")
        machine.succeed("wg show wg1")

    with subtest("checklist: Forgejo runner token + user/dir provisioning"):
        machine.succeed("mkdir -p /etc/forgejo-runner && chmod 0700 /etc/forgejo-runner")
        machine.succeed(
            "echo 'TOKEN=dummy-token' > /etc/forgejo-runner/registration-token.env "
            "&& chmod 0600 /etc/forgejo-runner/registration-token.env"
        )
        machine.succeed("id forgejo-runner")
        machine.succeed("test -d /var/lib/forgejo-runner/.ssh")
        machine.succeed('[ "$(stat -c %a /var/lib/forgejo-runner/.ssh)" = 700 ]')
        machine.succeed('[ "$(stat -c %U /var/lib/forgejo-runner/.ssh)" = forgejo-runner ]')

    with subtest("checklist: SSH deploy key generation + permissions"):
        machine.succeed(
            "sudo -u forgejo-runner ssh-keygen -t ed25519 "
            "-f /var/lib/forgejo-runner/.ssh/id_ed25519 -N \"\""
        )
        machine.succeed('[ "$(stat -c %a /var/lib/forgejo-runner/.ssh/id_ed25519)" = 600 ]')

    with subtest("checklist: runner service is wired up as documented"):
        unit = machine.succeed("systemctl cat gitea-runner-home.service")
        assert "User=forgejo-runner" in unit, "runner must run as the forgejo-runner user"
        assert "GIT_SSL_NO_VERIFY=true" in unit, "job checkout must skip TLS verification for the mkcert cert"
        # Registration itself needs the real, external Forgejo instance —
        # unreachable from this isolated VM by design, and act_runner retries
        # the ping internally for far longer than systemd's own start
        # timeout, so blocking on `systemctl start` here would hang the test
        # for minutes. --no-block plus polling the journal confirms it
        # actually tries to reach the configured URL, without waiting for
        # that retry loop to resolve.
        machine.succeed("systemctl start --no-block gitea-runner-home.service")
        attempted = False
        for _ in range(15):
            journal_output = machine.succeed("journalctl -u gitea-runner-home.service --no-pager")
            if "10.10.0.101:3000" in journal_output:
                attempted = True
                break
            time.sleep(1)
        assert attempted, "expected the runner to attempt reaching the configured Forgejo URL"
        machine.succeed("systemctl stop --no-block gitea-runner-home.service || true")

    with subtest("checklist: netdebug tcpdump + scoped NOPASSWD sudo"):
        machine.succeed("which tcpdump")
        out = machine.succeed("sudo -l -U v")
        assert "tcpdump" in out, "NOPASSWD sudo rule for tcpdump must be scoped to user v"

    with subtest("checklist: wireshark group membership"):
        out = machine.succeed("id v")
        assert "wireshark" in out, "user v must be in the wireshark group"

    with subtest("checklist: capture-host.sh rewrite + secret guardrail"):
        machine.succeed("mkdir -p /root/fixture-repo/tools && cd /root/fixture-repo && git init -q")
        machine.succeed("cp ${capture-host-script} /root/fixture-repo/tools/capture-host.sh")
        machine.succeed("chmod +x /root/fixture-repo/tools/capture-host.sh")

        # Clean fixture, three import kinds:
        #   1. this repo's own module (matched by REPO_BASENAME "fixture-repo",
        #      even though the path below isn't its real location — the
        #      rewrite matches on directory *name*, not an existing path)
        #      -> repo-relative rewrite
        #   2. a module the base repo actually exports as a nixosModule
        #      -> inputs.dotfiles.nixosModules.<name>
        #   3. a module under the base repo's path that ISN'T in its
        #      exported nixosModules (hardware.nix is deliberately private)
        #      -> left untouched, with a warning, not guessed at
        machine.succeed("mkdir -p /etc/nixos")
        machine.succeed(
            "printf '{ ... }:\\n{\\n  imports = [\\n"
            "    /home/v/fixture-repo/modules/foo.nix\\n"
            "    /home/v/dotfiles-nix/modules/wireguard.nix\\n"
            "    /home/v/dotfiles-nix/modules/hardware.nix\\n"
            "  ];\\n}\\n' "
            "> /etc/nixos/configuration.nix"
        )
        machine.succeed("rm -f /etc/nixos/hardware-configuration.nix")
        result = machine.succeed("cd /root/fixture-repo && ./tools/capture-host.sh --host testhost --yes")
        out = machine.succeed("cat /root/fixture-repo/hosts/testhost/configuration.nix")
        assert "../../modules/foo.nix" in out, "this repo's own absolute imports must be rewritten repo-relative"
        assert "inputs.dotfiles.nixosModules.wireguard" in out, "known base-repo modules must be rewritten to inputs.dotfiles.nixosModules.*"
        assert "/home/v/dotfiles-nix/modules/hardware.nix" in out, "unrecognized base-repo modules must be left untouched rather than silently dropped or guessed at"
        assert "Warning" in result, "an unrecognized base-repo module import must print a warning"

        # Dirty fixture: a leaked /etc/wireguard/ reference must be rejected.
        machine.succeed("rm -rf /root/fixture-repo/hosts/testhost")
        machine.succeed(
            "printf '{ ... }:\\n{\\n  x = \"/etc/wireguard/wg1.conf\";\\n}\\n' "
            "> /etc/nixos/configuration.nix"
        )
        machine.fail("cd /root/fixture-repo && ./tools/capture-host.sh --host testhost --yes")
        machine.fail("test -f /root/fixture-repo/hosts/testhost/configuration.nix")
  '';
}
