{
 inputs = {
  #  nixpkgs.url = github:NixOS/nixpkgs/nixos-23.05;
   nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
   flake-utils.url = github:numtide/flake-utils;
 };

 outputs = { self, nixpkgs, flake-utils, llamaDotCpp }:
   flake-utils.lib.eachDefaultSystem (system:
     let
       pkgs = import nixpkgs {
         inherit system overlays;
         config = { allowUnfree = true; };
       };

       overlay = (final: prev: { });
       overlays = [ overlay ];
     in
     rec {
       inherit overlay overlays;
       devShell = (pkgs.buildFHSUserEnv {
         name = "poetry-env";
         targetPkgs = pkgs:
           [
             pkgs.gcc
             pkgs.poetry
             pkgs.zlib # for numpy
             pkgs.portaudio
           ];
         runScript = "bash";
       }).env;
     });
}
# {
#   inputs = {
#     nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";
#     llamaDotCpp.url = "github:ggerganov/llama.cpp";
#     flake-utils.url = "github:numtide/flake-utils";
#   };
#   outputs = { self, nixpkgs, flake-utils, llamaDotCpp }: let
#     llamaDotCppFlake = llamaDotCpp;
#     nonSystemSpecificOutputs = {
#       overlays = {
#         noSentencePieceCustomMallocOnDarwin = (final: prev: {
#           sentencepiece = if prev.stdenv.isDarwin then prev.sentencepiece.override { withGPerfTools = false; } else prev.sentencepiece;
#         });
#       };
#     };
#     poetryOverrides = final: prev: {
#       urllib3 = prev.urllib3.overridePythonAttrs (old: { buildInputs = (old.buildInputs or []) ++ [ final.hatchling ]; });
#       llama-cpp-python = prev.llama-cpp-python.overridePythonAttrs (old: {
#         buildInputs = (old.buildInputs or []) ++ [ final.setuptools ];
#         prePatch = (old.prePatch or "") + "\n" + ''
#           ${final.pkgs.gnused}/bin/sed -i -e 's@from skbuild import setup@from setuptools import setup@' setup.py
#         '';
#         postInstall = ''
#           oldWD=$PWD
#           ln -s -- ${llamaDotCpp.packages.${final.pkgs.system}.default}/lib/libllama.* "$out"/lib/*/site-packages/llama_cpp/ || exit
#           cd "$oldWD" || exit
#         '';
#       });
#     };
#   in nonSystemSpecificOutputs // flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-linux" ] (system: let
#     # version =
#     #   if self.sourceInfo ? "rev"
#     #   then "${self.sourceInfo.lastModifiedDate}-${builtins.toString self.sourceInfo.revCount}-${self.sourceInfo.shortRev}"
#     #   else "dirty";
#     pkgs = import nixpkgs {
#       inherit system;
#       overlays = [
#         nonSystemSpecificOutputs.overlays.noSentencePieceCustomMallocOnDarwin
#       ];
#     };
#     poetryEnv = pkgs.poetry2nix.mkPoetryEnv {
#       python = pkgs.python310;
#       projectDir = self;
#       overrides = pkgs.poetry2nix.overrides.withDefaults poetryOverrides;
#     };
#   in {
#     legacyPackages = pkgs;
#     packages = {
#       llamaDotCpp = llamaDotCppFlake.packages.${system}.default;
#     };
#     devShells = {
#       default = poetryEnv.env.overrideAttrs (oldAttrs: {
#         buildInputs = [
#           llamaDotCppFlake.packages.${system}.default
#           pkgs.poetry
#           pkgs.poetry2nix.cli
#         ];
#       });
#       # poetryMinimal = pkgs.mkShell {
#       #   name = "minimal-poetry-shell";
#       #   buildInputs = [
#       #     pkgs.poetry
#       #     pkgs.poetry2nix.cli
#       #     (pkgs.python310.withPackages (p: [p.poetry-core]))
#       #   ];

#       # };
#     };
#   });
# }
