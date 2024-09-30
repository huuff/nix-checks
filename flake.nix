{
  description = "Checks for nix flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    pre-commit.url = "github:cachix/git-hooks.nix";
    treefmt.url = "github:numtide/treefmt-nix";
    systems.url = "github:nix-systems/x86_64-linux";
    utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      pre-commit,
      treefmt,
      ...
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        treefmt-build = (treefmt.lib.evalModule pkgs ./treefmt.nix).config.build;
        pre-commit-check = pre-commit.lib.${system}.run {
          src = ./.;
          hooks = import ./pre-commit.nix {
            inherit pkgs;
            treefmt = treefmt-build.wrapper;
          };
        };
        mkCheck =
          name: code:
          pkgs.runCommand name { } ''
            cd ${./.}
            ${code}
            mkdir "$out"
          '';
      in
      {
        lib = {
          checks = {
            statix = mkCheck "statix-check" "${pkgs.statix}/bin/statix check";
            deadnix = mkCheck "deadnix-check" "${pkgs.deadnix}/bin/deadnix --fail";
            flake-checker = mkCheck "flake-check" "${pkgs.flake-checker}/bin/flake-checker --fail-mode";
          };
        };
        checks = {
          # just check formatting is ok without changing anything
          formatting = treefmt-build.check self;

          inherit (self.lib.${system}.checks) statix deadnix flake-checker;
        };

        # for `nix fmt`
        formatter = treefmt-build.wrapper;

        devShells.default = pkgs.mkShell {
          inherit (pre-commit-check) shellHook;
          buildInputs =
            with pkgs;
            pre-commit-check.enabledPackages
            ++ [
              nil
              nixfmt-rfc-style
            ];
        };
      }
    );
}
