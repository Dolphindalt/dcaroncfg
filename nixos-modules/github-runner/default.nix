{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dcaroncfg.githubRunner;
  canCfg = config.dcaroncfg.canHardware;
in

{
  options.dcaroncfg.githubRunner = {
    enable = lib.mkEnableOption "GitHub Actions self-hosted runner";

    url = lib.mkOption {
      type = lib.types.str;
      description = "GitHub repository URL the runner is registered to.";
      example = "https://github.com/owner/repo";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/github-runner/token";
      description = ''
        Path to the file containing the GitHub runner registration token.
        Create one at: repo Settings > Actions > Runners > New self-hosted runner.
      '';
    };

    name = lib.mkOption {
      type = lib.types.str;
      description = "Name of the runner as it appears on GitHub.";
    };

    labels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "nixos"
        "can-bus"
      ];
      description = "Labels attached to the runner for job targeting.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages available in the runner environment.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.github-runners.${cfg.name} = {
      enable = true;
      name = cfg.name;
      url = cfg.url;
      tokenFile = cfg.tokenFile;
      noDefaultLabels = true;
      extraLabels = cfg.labels;
      replace = true;
      user = "github-runner";
      group = "github-runner";

      extraPackages =
        with pkgs;
        [
          # Rust toolchain
          rustc
          cargo
          clippy
          rustfmt
          rust-analyzer

          # Build essentials
          gcc
          pkg-config
          openssl.dev
          gnumake

          # Tools
          git
          rsync
          openssh
          coreutils

          # VM management
          libvirt

          # CAN utilities
          can-utils
        ]
        ++ cfg.extraPackages;

      extraEnvironment = lib.mkIf canCfg.enable {
        LD_LIBRARY_PATH = canCfg.libraryPath;
      };

      serviceOverrides = {
        SupplementaryGroups = lib.concatStringsSep " " (
          [
            "kvm"
            "libvirtd"
          ]
          ++ lib.optional canCfg.enable canCfg.group
        );
      };
    };

    users.users.github-runner = {
      isSystemUser = true;
      group = "github-runner";
      home = "/var/lib/github-runner";
      createHome = true;
    };

    users.groups.github-runner = { };
  };
}
