flakeInputs: {
  inherit (flakeInputs.self) library;

  knownHosts = {
    beetle = {
      type = "ci-runner";
      forwardAgent = true;
    };
    tortoise = {
      type = "desktop";
      forwardAgent = true;
    };
  };
}
