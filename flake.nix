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
    # channel urls are faster and more reliable than github -.-
    nixpkgs-stable.url = "https://channels.nixos.org/nixos-25.11/nixexprs.tar.xz";
    nixpkgs-old.url = "https://channels.nixos.org/nixos-24.11/nixexprs.tar.xz";
    nixpkgs-unstable.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

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
      packages = forAllSystems (
        pkgs:
        let
          mkBrave = release: pkgs.callPackage ./make-brave.nix { } (import release);
        in
        {
          brave-origin-beta = mkBrave ./packages/brave-origin-beta.nix;
          brave-origin-nightly = mkBrave ./packages/brave-origin-nightly.nix;
          niri-stable = pkgs.callPackage ({ niri-stable }: niri-stable) { };
          niri-unstable = pkgs.callPackage ({ niri-unstable }: niri-unstable) { };
          xwayland-satellite-stable = pkgs.callPackage (
            { xwayland-satellite-stable }: xwayland-satellite-stable
          ) { };
          xwayland-satellite-unstable = pkgs.callPackage (
            { xwayland-satellite-unstable }: xwayland-satellite-unstable
          ) { };
          smfh-unstable = inputs.hjem.packages.${pkgs.stdenv.hostPlatform.system}.smfh;
        }
      );

      overlays = {
        default = final: prev: {
          inherit (outputs.packages.${prev.stdenv.hostPlatform.system})
            brave-origin-beta
            brave-origin-nightly
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
