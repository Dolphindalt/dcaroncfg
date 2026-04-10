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

  postPatch = ''
    # The sub-Makefiles resolve config.mak one level above the linuxcan directory.
    cat > ../config.mak <<EOF
KDIR := ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
EOF
  '';

  # Unset 'src' so Kvaser Makefiles don't pick up the Nix store tarball path.
  buildPhase = ''
    runHook preBuild
    unset src
    make -C common KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    make -C leaf KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    make -C mhydra KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    make -C usbcanII KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    make -C virtualcan KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
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
