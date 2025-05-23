{
  description = "Checks for nix flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    pre-commit.url = "github:cachix/git-hooks.nix";
    treefmt.url = "github:numtide/treefmt-nix";
    systems.url = "github:nix-systems/x86_64-linux";
    my-derivations.url = "github:huuff/nix-derivations";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      my-derivations,
      naersk,
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
          name: code: path:
          pkgs.runCommand name { } ''
            cd ${path}
            ${code}
            mkdir "$out"
          '';

        my-pkgs = my-derivations.packages.${system};
      in
      {
        lib = {
          checks = {
            statix = mkCheck "statix-check" "${pkgs.statix}/bin/statix check";
            deadnix = mkCheck "deadnix-check" "${pkgs.deadnix}/bin/deadnix --fail";
            flake-checker = mkCheck "flake-check" "${pkgs.flake-checker}/bin/flake-checker --fail-mode";
            # actually I shouldn't use this most of the time since I'd have it for treefmt?
            leptosfmt = mkCheck "leptosfmt" "${my-pkgs.leptosfmt}/bin/leptosfmt --check .";
          };

          # These must receive a toolchain attrset generated by `rust-overlay`
          rustChecks =
            { toolchain }:
            let
              naersk' = pkgs.callPackage naersk {
                cargo = toolchain;
                rustc = toolchain;
                clippy = toolchain;
              };
            in
            {
              clippy =
                path:
                naersk'.buildPackage {
                  src = path;
                  mode = "clippy";
                  cargoBuildOptions = _: [ "--all-features" ];
                  cargoClippyOptions = _: [ "--deny warnings" ];
                };
            };
        };

        checks = {
          # just check formatting is ok without changing anything
          formatting = treefmt-build.check self;

          statix = self.lib.${system}.checks.statix ./.;
          deadnix = self.lib.${system}.checks.deadnix ./.;
          flake-checker = self.lib.${system}.checks.flake-checker ./.;
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
