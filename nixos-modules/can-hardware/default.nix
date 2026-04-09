{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dcaroncfg.canHardware;
in

{
  options.dcaroncfg.canHardware = {
    enable = lib.mkEnableOption "CAN bus hardware support";

    pcan = {
      enable = lib.mkEnableOption "PCAN-USB FD support (Peak System)";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.libpcanbasic;
        defaultText = lib.literalExpression "pkgs.libpcanbasic";
        description = "The libpcanbasic package providing libpcanbasic.so.";
      };
    };

    kvaser = {
      enable = lib.mkEnableOption "Kvaser U100 support (Kvaser AB)";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.kvaser-linuxcan;
        defaultText = lib.literalExpression "pkgs.kvaser-linuxcan";
        description = "The Kvaser CANlib package providing libcanlib.so.";
      };
    };

    vcan = {
      enable = lib.mkEnableOption "Virtual CAN interface for loopback testing";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "can";
      description = "System group granted access to CAN devices.";
    };

    libraryPath = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default =
        let
          paths =
            lib.optional cfg.pcan.enable "${cfg.pcan.package}/lib"
            ++ lib.optional cfg.kvaser.enable "${cfg.kvaser.package}/lib";
        in
        lib.concatStringsSep ":" paths;
      description = "LD_LIBRARY_PATH containing CAN userspace libraries.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };

    boot.kernelModules = [
      "can"
      "can_raw"
      "can_dev"
    ]
    ++ lib.optionals cfg.pcan.enable [ "peak_usb" ]
    ++ lib.optionals cfg.kvaser.enable [ "kvaser_usb" ]
    ++ lib.optionals cfg.vcan.enable [ "vcan" ];

    services.udev.extraRules =
      let
        pcanRules = ''
          # PCAN-USB FD (Peak System)
          SUBSYSTEM=="usb", ATTR{idVendor}=="0c72", ATTR{idProduct}=="0012", GROUP="${cfg.group}", MODE="0660"
        '';
        kvaserRules = ''
          # Kvaser U100 (Kvaser AB)
          SUBSYSTEM=="usb", ATTR{idVendor}=="0bfd", ATTR{idProduct}=="0111", GROUP="${cfg.group}", MODE="0660"
        '';
      in
      lib.concatStrings (
        lib.optional cfg.pcan.enable pcanRules ++ lib.optional cfg.kvaser.enable kvaserRules
      );

    environment.systemPackages = [
      pkgs.can-utils
    ];

    environment.sessionVariables = lib.mkIf (cfg.libraryPath != "") {
      LD_LIBRARY_PATH = cfg.libraryPath;
    };
  };
}
