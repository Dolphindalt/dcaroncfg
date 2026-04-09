{
  lib,
  stdenv,
  requireFile,
  gcc,
}:

stdenv.mkDerivation {
  pname = "libpcanbasic";
  version = "5.0.0.1116";

  # Download the PCAN-Basic Linux standalone package from:
  # https://www.peak-system.com/PCAN-Basic.239.0.html
  # Then: nix-store --add-fixed sha256 PCAN-Basic_Linux-5.0.0.1116.tar.gz
  src = requireFile {
    name = "PCAN-Basic_Linux-5.0.0.1116.tar.gz";
    url = "https://www.peak-system.com/PCAN-Basic.239.0.html";
    hash = "sha256-HNNvNOA7IT8bJf/05m8CWu8gmxlcKV0qIQpMOxOrEbQ=";
  };

  nativeBuildInputs = [ gcc ];

  sourceRoot = "PCAN-Basic_Linux-5.0.0.1116/libpcanbasic/pcanbasic";

  buildPhase = ''
    make PCANFD_HEADER=src/pcan/driver/pcanxl.h
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
