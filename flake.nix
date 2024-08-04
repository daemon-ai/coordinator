{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
        };

        devShellPackages = [
          pkgs.gcc
          pkgs.poetry
          pkgs.zlib # for numpy
          pkgs.portaudio
          pkgs.ngrok
        ];
      in
      rec {
        devShell = pkgs.mkShell {
          buildInputs = devShellPackages;
        };
      });
}