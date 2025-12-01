flakeInputs:
let
  inherit (builtins)
    readDir
    ;

  inherit (flakeInputs.nixpkgs-lib)
    lib
    ;

  inherit (lib.attrsets)
    attrNames
    filterAttrs
    ;

  inherit (lib.fixedPoints)
    fix
    ;

  inherit (lib.trivial)
    const
    flip
    pipe
    ;
in
fix (finalLibrary: {

  path = fix (finalPath: {

    /**
      Filter the contents of a directory path for directories only.

      # Inputs

      `contents`

      : 1\. The contents of a directory path.

      # Type

      ```
      filterDirectories :: AttrSet -> AttrSet
      ```

      # Example
      :::{.example}
      ## `lib.path.filterDirectories` usage example

      ```nix
      x = {
        "default.nix" = "regular";
        djacu = "directory";
        programs = "directory";
        services = "directory";
      }
      filterDirectories x
      => {
        djacu = "directory";
        programs = "directory";
        services = "directory";
      }
      ```

      :::
    */
    filterDirectories = filterAttrs (const (fileType: fileType == "directory"));

    /**
      Get list of directories names under the parent directory.

      # Inputs

      `path`

      : 1\. The parent directory path.

      # Type

      ```
      getDirectoryNames :: Path -> [String]
      ```

      # Example
      :::{.example}
      ## `lib.path.getDirectoryNames` usage example

      ```nix
      getDirectoryNames ./home-modules
      => [
        "djacu"
        "programs"
        "services"
      ]
      ```
    */
    getDirectoryNames = flip pipe [
      finalPath.getDirectories
      attrNames
    ];

    /**
      Get attribute set of directories under the parent directory.

      # Inputs

      `path`

      : 1\. The parent directory path.

      # Type

      ```
      getDirectoryNames :: Path -> AttrSet
      ```

      # Example
      :::{.example}
      ## `lib.path.getDirectories` usage example

      ```nix
      getDirectories ./home-modules
      => [
        djacu = "directory"
        programs = "directory"
        services = "directory"
      ]
      ```
    */
    getDirectories = flip pipe [
      readDir
      finalPath.filterDirectories
    ];

  });

})
