{
  lib,
  stdenv,
  requireFile,
  gcc,
}:

stdenv.mkDerivation {
  pname = "kvaser-linuxcan";
  version = "5.51.461";

  # Download the Kvaser linuxcan SDK from:
  # https://www.kvaser.com/linux-drivers-and-sdk-2/
  # Then: nix-store --add-fixed sha256 linuxcan_5_51_461.tar.gz
  src = requireFile {
    name = "linuxcan_5_51_461.tar.gz";
    url = "https://www.kvaser.com/linux-drivers-and-sdk-2/";
    hash = "sha256-muApLgITJ/97sGBZYevNi3jk/JiXp9dx9QYwXUWaYpo=";
  };

  nativeBuildInputs = [ gcc ];

  sourceRoot = "linuxcan/canlib";

  buildPhase = ''
    make canlib
  '';

  installPhase = ''
    mkdir -p $out/lib $out/include
    cp -a libcanlib.so* $out/lib/
    cp ../include/canlib.h ../include/canstat.h $out/include/
  '';

  meta = {
    description = "Kvaser CANlib SDK (userspace library for Kvaser CAN adapters)";
    homepage = "https://www.kvaser.com/";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
