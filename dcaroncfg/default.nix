flakeInputs: {
  inherit (flakeInputs.self) library;

  knownHosts = {
    tortoise = {
      type = "desktop";
      forwardAgent = true;
    };
  };
}
