# Out-of-tree PCAN kernel module from PEAK's peak-linux-driver tarball.
# This replaces the mainline peak_usb driver and creates /sys/class/pcan/
# and /proc/pcan entries that libpcanbasic requires.
{
  lib,
  stdenv,
  requireFile,
  kernel,
}:

stdenv.mkDerivation {
  pname = "pcan";
  version = "9.0.0-${kernel.version}";

  src = requireFile {
    name = "peak-linux-driver-9.0.tar.gz";
    url = "https://www.peak-system.com/fileadmin/media/linux/files/peak-linux-driver-9.0.tar.gz";
    hash = "sha256-atzKQ1gP5hnBkRUrXTdgHK4u31q+ne6lOJtRPeSjj/s=";
  };

  sourceRoot = "peak-linux-driver-9.0/driver";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_DIR=$(out)"
    "NET=NETDEV_SUPPORT"
  ];

  buildPhase = ''
    runHook preBuild
    make $makeFlags clean
    make $makeFlags
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
    find . -name '*.ko' -exec cp {} $out/lib/modules/${kernel.modDirVersion}/extra/ \;
    runHook postInstall
  '';

  meta = {
    description = "PEAK PCAN kernel driver (out-of-tree, with netdev support)";
    homepage = "https://www.peak-system.com/";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
