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
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;

        networking.hostName = "tortoise";

        networking.networkmanager.enable = true;

        time.timeZone = "America/Los_Angeles";

        i18n.defaultLocale = "en_US.UTF-8";

        services.xserver.enable = true;
        services.xserver.xkb.layout = "us";
        services.xserver.xkb.options = "eurosign:e,caps:escape";

        services.xserver.windowManager.dwm.enable = true;

        services.pipewire = {
          enable = true;
          pulse.enable = true;
        };

        users.users.dcaron = {
          isNormalUser = true;
          extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
          packages = with pkgs; [
            tree
          ];
        };

        programs.firefox.enable = true;

        environment.systemPackages = with pkgs; [
          vim
          wget
          git
        ];

        services.openssh.enable = true;

        system.stateVersion = "25.11";

        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
    };
}
