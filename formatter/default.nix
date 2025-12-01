flakeInputs:
let
  inherit (flakeInputs.nixpkgs-lib)
    lib
    ;

  inherit (lib.attrsets)
    mapAttrs
    ;

  inherit (lib.trivial)
    const
    ;

in
mapAttrs (const (module: module.config.build.wrapper)) flakeInputs.self.formatterModule
