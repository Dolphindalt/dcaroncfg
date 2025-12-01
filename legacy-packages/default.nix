flakeInputs:
flakeInputs.nixpkgs-lib.lib.genAttrs
  [
    "x86_64-linux"
    "aarch64-linux"
  ]
  (
    system:
    import flakeInputs.nixpkgs {
      inherit system;
      # TODO(dcaron): Add overlays here as needed.
    }
  )
