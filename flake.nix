{
  description = "PercyGT's nix sources";
  nixConfig = {
    extra-substituters = [
      "https://percygtdev.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "percygtdev.cachix.org-1:AGd4bI4nW7DkJgniWF4tS64EX2uSYIGqjZih2UVoxko="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  inputs = {
    nixpkgs-stable.url = "https://channels.nixos.org/nixos-25.05/nixexprs.tar.xz";
    nixpkgs-old.url = "https://channels.nixos.org/nixos-24.11/nixexprs.tar.xz";
    nixpkgs-unstable.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs.follows = "nixpkgs-unstable";

    niri.url = "github:sodiboo/niri-flake";
    niri.inputs.nixpkgs.follows = "nixpkgs";

    swayfx-unwrapped-git.url = "github:WillPower3309/swayfx";
    # swayfx-unwrapped-git.inputs.nixpkgs.follows = "nixpkgs";
    emacs-overlay.url = "github:nix-community/emacs-overlay/";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
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
        emacs = inputs.emacs-overlay.overlays.default;
        neovim-nightly = inputs.neovim-nightly-overlay.overlays.default;
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
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
      packages = forAllSystems (pkgs: {
        emacs-unstable = pkgs.callPackage (
          { emacs-unstable }:
          emacs-unstable.override {
            withTreeSitter = true;
          }
        ) { };
        niri-stable-git = inputs.niri.packages."${pkgs.system}".niri-stable;
        niri-unstable-git = inputs.niri.packages."${pkgs.system}".niri-unstable;
        xwayland-satellite-stable-git = inputs.niri.packages."${pkgs.system}".xwayland-satellite-stable;
        xwayland-satellite-unstable-git = inputs.niri.packages."${pkgs.system}".xwayland-satellite-unstable;
        # emacs-pgtk = pkgs.callPackage (
        #   { emacs-pgtk }:
        #   emacs-pgtk.override {
        #     withTreeSitter = true;
        #   }
        # ) { };
        # emacs-unstable-pgtk = pkgs.callPackage (
        #   { emacs-unstable-pgtk }:
        #   emacs-unstable-pgtk.override {
        #     withTreeSitter = true;
        #   }
        # ) { };
        swayfx-git = pkgs.callPackage (
          { swayfx }:
          swayfx.override {
            swayfx-unwrapped = inputs.swayfx-unwrapped-git.packages.${pkgs.system}.swayfx-unwrapped-git;
          }
        ) { };
        neovim-unstable = pkgs.callPackage ({ neovim }: neovim) { };
      });

      overlays = {
        default = final: prev: {
          inherit (outputs.packages.${prev.system})
            swayfx-git
            emacs-unstable
            neovim-unstable
            niri-stable-git
            niri-unstable-git
            xwayland-satellite-stable-git
            xwayland-satellite-unstable-git
            ;
        };
      };
    };
}
