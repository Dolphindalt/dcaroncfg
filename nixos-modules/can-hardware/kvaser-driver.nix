# Out-of-tree Kvaser kernel modules from the linuxcan SDK.
# This replaces the mainline kvaser_usb driver and creates device
# nodes that libcanlib requires.
{
  lib,
  stdenv,
  requireFile,
  kernel,
}:

let
  kdir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in

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
    cat > ../config.mak <<EOF
KDIR := ${kdir}
EOF
  '';

  # Unset 'src' so Kvaser Makefiles don't pick up the Nix store tarball path.
  # Use Kbuild (make -C $KDIR M=...) to build each kernel module.
  buildPhase = ''
    runHook preBuild
    unset src
    for mod in common leaf mhydra usbcanII virtualcan; do
      if [ -d "$mod" ]; then
        make -C ${kdir} M=$(pwd)/$mod modules
      fi
    done
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
