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
mapAttrs (const (
  pkgs:
  (flakeInputs.treefmt-nix.lib.evalModule pkgs (
    { ... }:
    {
      config = {
        enableDefaultExcludes = true;
        projectRootFile = "flake.nix";
        programs = {
          mdformat.enable = true;
          mdsh.enable = true;
          nixfmt.enable = true;
          shellcheck.enable = true;
        };
        settings.global.excludes = [
          "*.gitignore"
          "*.git-blame-ignore-revs"
        ];
      };
    }
  ))
)) flakeInputs.self.legacyPackages
