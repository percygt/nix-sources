{
  description = "PercyGT's nix sources";
  nixConfig = {
    extra-substituters = [
      "https://percygtdev.cachix.org"
      "https://nix-community.cachix.org"
      "https://niri.cachix.org"
    ];
    extra-trusted-public-keys = [
      "percygtdev.cachix.org-1:AGd4bI4nW7DkJgniWF4tS64EX2uSYIGqjZih2UVoxko="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    ];
  };
  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs.follows = "nixpkgs-unstable";

    niri.url = "github:sodiboo/niri-flake";

    hjem.url = "github:feel-co/hjem";
    hjem.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, ... }@inputs:
    let
      inherit (self) outputs;
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      inherit (inputs.nixpkgs) lib;
      forEachSystem = lib.genAttrs systems;
      overlays = {
        niri-flake = inputs.niri.overlays.niri;
      };
      packagesFrom =
        inputs-nixpkgs:
        (
          function:
          (forEachSystem (
            system:
            function (
              import inputs-nixpkgs {
                inherit system;
                overlays = builtins.attrValues overlays;
                config.allowUnfree = true;
              }
            )
          ))
        );
      forAllSystems = packagesFrom inputs.nixpkgs;
    in
    {
      formatter = forAllSystems (pkgs: pkgs.nixfmt);
      packages = forAllSystems (pkgs: {
        niri-stable = pkgs.callPackage ({ niri-stable }: niri-stable) { };
        niri-unstable = pkgs.callPackage ({ niri-unstable }: niri-unstable) { };
        xwayland-satellite-stable = pkgs.callPackage (
          { xwayland-satellite-stable }: xwayland-satellite-stable
        ) { };
        xwayland-satellite-unstable = pkgs.callPackage (
          { xwayland-satellite-unstable }: xwayland-satellite-unstable
        ) { };
        smfh-unstable = inputs.hjem.packages.${pkgs.stdenv.hostPlatform.system}.smfh;
      });

      overlays = {
        default = final: prev: {
          inherit (outputs.packages.${prev.stdenv.hostPlatform.system})
            niri-stable
            niri-unstable
            smfh-unstable
            xwayland-satellite-stable
            xwayland-satellite-unstable
            ;
        };
      };
    };
}
