flakeInputs:

{
  default =
    final: prev:
    prev.lib.packagesFromDirectoryRecursive {
      callPackage = final.callPackage;
      directory = ./package-sets/top-level;
    };
}
