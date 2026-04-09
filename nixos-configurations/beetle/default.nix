flakeInputs: {
  release = rec {
    number = "2511";
    nixpkgs = flakeInputs."nixpkgs-${number}";
  };
  modules =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    {
      imports = [
        ./hardware-configuration.nix
      ];
      config = {
        nixpkgs.config.allowUnfreePredicate =
          pkg:
          builtins.elem (lib.getName pkg) [
            "kvaser-linuxcan"
          ];

        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;

        networking.hostName = "beetle";

        networking.networkmanager.enable = true;

        time.timeZone = "America/Los_Angeles";

        i18n.defaultLocale = "en_US.UTF-8";

        users.users.dcaron = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "libvirt"
            "kvm"
            "can"
          ];
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDFx7dU/EXygXkfPFZcCP/5TN+Ff9YtXiVRpviKWjRgY dpcaron99@gmail.com"
          ];
        };

        # CAN bus hardware.
        # Packages come from the overlay (pkgs.libpcanbasic, pkgs.kvaser-linuxcan).
        # Update the placeholder hashes in package-sets/top-level/*/package.nix
        # after downloading the vendor SDKs. Run: nix hash file <tarball>
        dcaroncfg.canHardware = {
          enable = true;
          pcan.enable = true;
          kvaser.enable = true;
          vcan.enable = true;
        };

        # GitHub Actions self-hosted runner.
        dcaroncfg.githubRunner = {
          enable = true;
          url = "https://github.com/Dolphindalt/can-hal-rs";
          name = "beetle";
        };

        # Windows VM for cross-platform CI.
        dcaroncfg.windowsVm = {
          enable = true;
          usbDevices = [
            {
              vendor = "0c72";
              product = "0012";
            } # PCAN-USB FD
            {
              vendor = "0bfd";
              product = "0111";
            } # Kvaser U100
          ];
        };

        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };
        };

        environment.systemPackages = with pkgs; [
          vim
          wget
          git
          htop
        ];

        system.stateVersion = "25.11";

        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
    };
}
