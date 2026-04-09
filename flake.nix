{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-2511.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = flakeInputs: {
    formatter = import ./formatter flakeInputs;
    formatterModule = import ./formatter-module flakeInputs;
    library = import ./library flakeInputs;
    overlays = import ./overlays.nix flakeInputs;
    legacyPackages = import ./legacy-packages flakeInputs;
    nixosModules = import ./nixos-modules flakeInputs;
    nixosConfigurations = import ./nixos-configurations flakeInputs;
    dcaroncfg = import ./dcaroncfg flakeInputs;
  };
}
