flakeInputs: {
  default = {
    imports = [
      ./can-hardware
      ./github-runner
      ./windows-vm
    ];
  };
}
