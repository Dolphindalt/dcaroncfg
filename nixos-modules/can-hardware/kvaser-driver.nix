# Out-of-tree Kvaser kernel modules from the linuxcan SDK.
# This replaces the mainline kvaser_usb driver and creates device
# nodes that libcanlib requires.
{
  lib,
  stdenv,
  requireFile,
  kernel,
}:

stdenv.mkDerivation {
  pname = "kvaser-linuxcan-driver";
  version = "5.51.461-${kernel.version}";

  src = requireFile {
    name = "linuxcan_5_51_461.tar.gz";
    url = "https://www.kvaser.com/linux-drivers-and-sdk-2/";
    hash = "sha256-muApLgITJ/97sGBZYevNi3jk/JiXp9dx9QYwXUWaYpo=";
  };

  sourceRoot = "linuxcan";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  buildPhase = ''
    runHook preBuild
    make $makeFlags -C common
    make $makeFlags -C leaf
    make $makeFlags -C mhydra
    make $makeFlags -C usbcanII
    make $makeFlags -C virtualcan
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
    find . -name '*.ko' -exec cp {} $out/lib/modules/${kernel.modDirVersion}/extra/ \;
    runHook postInstall
  '';

  meta = {
    description = "Kvaser linuxcan kernel drivers (out-of-tree)";
    homepage = "https://www.kvaser.com/";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
