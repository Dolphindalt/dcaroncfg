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

    bitrate = lib.mkOption {
      type = lib.types.int;
      default = 500000;
      description = "Nominal CAN bitrate in bits/s.";
    };

    dataBitrate = lib.mkOption {
      type = lib.types.int;
      default = 2000000;
      description = "CAN FD data bitrate in bits/s.";
    };

    fdEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable CAN FD mode on physical interfaces.";
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
    ++ lib.optionals cfg.pcan.enable [ "pcan" ]
    ++ lib.optionals cfg.vcan.enable [ "vcan" ];

    # Blacklist mainline drivers so the vendor drivers take over.
    boot.blacklistedKernelModules =
      lib.optionals cfg.pcan.enable [ "peak_usb" ]
      ++ lib.optionals cfg.kvaser.enable [ "kvaser_usb" ];

    # Build out-of-tree vendor kernel modules.
    boot.extraModulePackages =
      lib.optional cfg.pcan.enable
        (config.boot.kernelPackages.callPackage ./pcan-driver.nix { })
      ++ lib.optional cfg.kvaser.enable
        (config.boot.kernelPackages.callPackage ./kvaser-driver.nix { });

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

    # Bring up physical CAN interfaces after their kernel drivers create them.
    systemd.services.can-interfaces-setup = lib.mkIf (cfg.pcan.enable || cfg.kvaser.enable) {
      description = "Configure and bring up CAN interfaces";
      after = [ "network.target" "systemd-udevd.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.iproute2 ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script =
        let
          bitrateArgs =
            if cfg.fdEnabled then
              "bitrate ${toString cfg.bitrate} dbitrate ${toString cfg.dataBitrate} fd on"
            else
              "bitrate ${toString cfg.bitrate}";
          setupIf = iface: ''
            if [ -e /sys/class/net/${iface} ]; then
              ip link set ${iface} type can ${bitrateArgs}
              ip link set ${iface} up
              echo "${iface}: configured and up"
            else
              echo "${iface}: not found, skipping"
            fi
          '';
        in
        (lib.optionalString cfg.pcan.enable (setupIf "can0"))
        + (lib.optionalString cfg.kvaser.enable (setupIf "can1"));
    };

    systemd.services.vcan0-setup = lib.mkIf cfg.vcan.enable {
      description = "Set up virtual CAN interface";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.iproute2}/bin/ip link add vcan0 type vcan";
        ExecStartPost = "${pkgs.iproute2}/bin/ip link set vcan0 up";
        ExecStop = "${pkgs.iproute2}/bin/ip link del vcan0";
      };
    };

    environment.systemPackages = [
      pkgs.can-utils
    ];

    environment.sessionVariables = lib.mkIf (cfg.libraryPath != "") {
      LD_LIBRARY_PATH = cfg.libraryPath;
    };
  };
}
