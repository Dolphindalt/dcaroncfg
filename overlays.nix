flakeInputs:

let
  unstable = system: import flakeInputs.nixpkgs { inherit system; };
in

{
  default =
    final: prev:
    prev.lib.packagesFromDirectoryRecursive {
      callPackage = final.callPackage;
      directory = ./package-sets/top-level;
    }
    // {
      github-runner = (unstable prev.stdenv.hostPlatform.system).github-runner;
    };
}
