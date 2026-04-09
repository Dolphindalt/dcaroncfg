flakeInputs:

let
  inherit (flakeInputs.nixpkgs-lib)
    lib
    ;

  inherit (lib.attrsets)
    attrNames
    genAttrs
    ;

  inherit (lib.lists)
    elem
    ;

  inherit (flakeInputs.self.library.path)
    getDirectoryNames
    ;

  inherit (flakeInputs.self.dcaroncfg)
    knownHosts
    ;
in
genAttrs (getDirectoryNames ./.) (
  host:
  let
    hostInfo = import ./${host} flakeInputs;
  in
  hostInfo.release.nixpkgs.lib.nixosSystem {
    modules = [
      (
        { config, ... }:
        {
          assertions = [
            {
              assertion = elem config.networking.hostName (attrNames knownHosts);
              message = "Hostname is not known!";
            }
          ];
          networking.hostName = host;
          nixpkgs.overlays = [ flakeInputs.self.overlays.default ];
        }
      )
      flakeInputs.self.nixosModules.default
      hostInfo.modules
    ];
  }
)
