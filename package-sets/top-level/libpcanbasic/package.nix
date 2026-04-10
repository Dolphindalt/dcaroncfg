{
  lib,
  stdenv,
  requireFile,
  gcc,
  popt,
}:

stdenv.mkDerivation {
  pname = "libpcanbasic";
  version = "9.0.0";

  # Download the peak-linux-driver tarball from:
  # https://www.peak-system.com/fileadmin/media/linux/files/peak-linux-driver-9.0.tar.gz
  # Then: nix-store --add-fixed sha256 peak-linux-driver-9.0.tar.gz
  src = requireFile {
    name = "peak-linux-driver-9.0.tar.gz";
    url = "https://www.peak-system.com/fileadmin/media/linux/files/peak-linux-driver-9.0.tar.gz";
    hash = "sha256-atzKQ1gP5hnBkRUrXTdgHK4u31q+ne6lOJtRPeSjj/s=";
  };

  nativeBuildInputs = [ gcc ];
  buildInputs = [ popt ];

  sourceRoot = "peak-linux-driver-9.0/libpcanbasic/pcanbasic";

  # Build with netdev (SocketCAN) support for mainline peak_usb driver.
  buildPhase = ''
    make clean
    make
  '';

  installPhase = ''
    mkdir -p $out/lib $out/include
    cp -a lib/libpcanbasic.so* $out/lib/
    cp include/PCANBasic.h $out/include/
  '';

  meta = {
    description = "PCAN-Basic Linux API (userspace library for PEAK CAN adapters)";
    homepage = "https://www.peak-system.com/";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.linux;
  };
}
