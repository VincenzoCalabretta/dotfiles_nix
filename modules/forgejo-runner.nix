{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkForce mkOption types;
  cfg = config.dotfiles.forgejo-runner;
in
{
  options.dotfiles.forgejo-runner = {
    enable = mkEnableOption "Forgejo Actions runner on this host";

    url = mkOption {
      type = types.str;
      default = "https://10.10.0.101:3000";
      description = "Base URL of your Forgejo instance.";
    };

    name = mkOption {
      type = types.str;
      default = "home";
      description = "Runner instance name (appears in Forgejo admin).";
    };

    tokenFile = mkOption {
      type = types.str;
      default = "/etc/forgejo-runner/registration-token.env";
      description = ''
        Path to an environment file containing TOKEN=<registration-token>.
        Root-owned 0600, outside the Nix store — like /etc/wireguard/*.conf.
      '';
    };

    capacity = mkOption {
      type = types.int;
      default = 2;
      description = "Number of simultaneous CI jobs this runner accepts.";
    };

    labels = mkOption {
      type = types.listOf types.str;
      default = [ "self-hosted:host" ];
      description = ''
        Labels registered with the Forgejo instance. Jobs must match one.
        Uses host execution (no Docker/Podman) — jobs run directly on the host
        as the forgejo-runner user.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.gitea-actions-runner.instances."${cfg.name}" = {
      enable = true;
      name = cfg.name;
      url = cfg.url;
      tokenFile = cfg.tokenFile;
      labels = cfg.labels;
      hostPackages = with pkgs; [
        bash coreutils curl gawk git gnused gnutar gzip xz
        jq nodejs openssh wget
        nix
      ];
      settings.runner.capacity = cfg.capacity;
      # Forgejo serves a mkcert (locally-trusted-CA) certificate, not one chained
      # to a public root. Traffic stays inside the WireGuard tunnel either way,
      # so skip TLS verification rather than syncing the mkcert root CA here.
      settings.runner.insecure = true;
    };

    # Override from DynamicUser to a real system user so we get:
    #  - a stable ~/.ssh/ for the deploy key
    #  - a resolvable user name for nix.settings.trusted-users
    systemd.services."gitea-runner-${cfg.name}" = {
      environment.HOME = mkForce "/var/lib/forgejo-runner";
      # The runner's own Gitea/Forgejo API client honors settings.runner.insecure
      # above, but job checkout shells out to plain git/libcurl, which reads the
      # system OpenSSL trust store instead — so it needs its own opt-out for the
      # same mkcert certificate.
      environment.GIT_SSL_NO_VERIFY = "true";
      serviceConfig = {
        User = mkForce "forgejo-runner";
        Group = mkForce "forgejo-runner";
        DynamicUser = mkForce false;
        StateDirectory = mkForce "forgejo-runner";
        WorkingDirectory = mkForce "-/var/lib/forgejo-runner/${cfg.name}";
      };
    };

    users.users.forgejo-runner = {
      isSystemUser = true;
      group = "forgejo-runner";
      home = "/var/lib/forgejo-runner";
      createHome = true;
    };
    users.groups.forgejo-runner = {};

    # Ensure the token directory and SSH dir exist (contents provisioned out of band).
    systemd.tmpfiles.rules = [
      "d /etc/forgejo-runner 0700 root root -"
      "d /var/lib/forgejo-runner/.ssh 0700 forgejo-runner forgejo-runner -"
    ];

    # The runner user needs nix trust to avoid sandbox / substituter restrictions.
    nix.settings.trusted-users = [ "forgejo-runner" ];
  };
}