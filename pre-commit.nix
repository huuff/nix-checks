{ pkgs, treefmt }:

{
  check-merge-conflicts.enable = true;
  check-added-large-files.enable = true;
  commitizen.enable = true;

  gitleaks = {
    name = "gitleaks";
    enable = true;
    entry = "${pkgs.gitleaks}/bin/gitleaks detect";
    stages = [ "pre-commit" ];
  };

  treefmt = {
    enable = true;
    packageOverrides.treefmt = treefmt;
  };

  statix.enable = true;
  deadnix.enable = true;
  nil.enable = true;
  flake-checker.enable = true;

  actionlint.enable = true;

  markdownlint.enable = true;
  typos.enable = true;

}
