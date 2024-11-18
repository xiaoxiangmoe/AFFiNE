{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        githubSha = self.rev or self.dirtyRev or "ffffffffffffffffffffffffffffffffffffffff";
      in
      {
        packages = {
          affine = pkgs.callPackage ./affine-electron.nix {
            inherit githubSha;
            buildType = "stable";
          };
          affine-canary = pkgs.callPackage ./affine-electron.nix {
            inherit githubSha;
            buildType = "canary";
          };
        };
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.nodejs_18
            pkgs.nodePackages.yarn
            pkgs.cargo
            pkgs.rustc
            pkgs.rsync
            pkgs.cacert
            pkgs.findutils
            pkgs.zip # electron-forge need zip
          ];
          RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
        };
      }
    );
}
