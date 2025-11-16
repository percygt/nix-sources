{
  description = "PercyGT's nix sources";
  nixConfig = {
    extra-substituters = [
      "https://percygtdev.cachix.org"
      "https://nix-community.cachix.org"
      "https://niri.cachix.org"
      "https://watersucks.cachix.org"
    ];
    extra-trusted-public-keys = [
      "percygtdev.cachix.org-1:AGd4bI4nW7DkJgniWF4tS64EX2uSYIGqjZih2UVoxko="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "watersucks.cachix.org-1:6gadPC5R8iLWQ3EUtfu3GFrVY7X6I4Fwz/ihW25Jbv8="
    ];
  };
  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs.follows = "nixpkgs-unstable";

    nixos-cli.url = "github:nix-community/nixos-cli";
    niri.url = "github:sodiboo/niri-flake";
    # swayfx-unwrapped-git.url = "github:WillPower3309/swayfx";
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
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
      packages = forAllSystems (
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
        in
        {
          emacs-unstable = pkgs.callPackage (
            { emacs-unstable }:
            emacs-unstable.override {
              withTreeSitter = true;
            }
          ) { };
          niri-stable = pkgs.callPackage ({ niri-stable }: niri-stable) { };
          niri-unstable = pkgs.callPackage ({ niri-unstable }: niri-unstable) { };
          xwayland-satellite-stable = pkgs.callPackage (
            { xwayland-satellite-stable }: xwayland-satellite-stable
          ) { };
          xwayland-satellite-unstable = pkgs.callPackage (
            { xwayland-satellite-unstable }: xwayland-satellite-unstable
          ) { };
          neovim-unstable = pkgs.callPackage ({ neovim }: neovim) { };
          nixos = inputs.nixos-cli.packages.${system}.default;

          mesa = pkgs.callPackage ({ mesa }: mesa) { };
          mesa-32 = pkgs.callPackage ({ pkgsi686Linux }: pkgsi686Linux.mesa) { };
          intel-vaapi-driver = pkgs.callPackage (
            { intel-vaapi-driver }:
            intel-vaapi-driver.override {
              enableHybridCodec = true;
            }
          ) { };
          intel-vaapi-driver-32 = pkgs.callPackage (
            { driversi686Linux }:
            driversi686Linux.intel-vaapi-driver.override {
              enableHybridCodec = true;
            }
          ) { };
          intel-media-driver = pkgs.callPackage ({ intel-media-driver }: intel-media-driver) { };
          intel-media-driver-32 = pkgs.callPackage (
            { driversi686Linux }: driversi686Linux.intel-media-driver
          ) { };
          intel-ocl = pkgs.callPackage ({ intel-ocl }: intel-ocl) { };
          intel-compute-runtime = pkgs.callPackage ({ intel-compute-runtime }: intel-compute-runtime) { };
          vpl-gpu-rt = pkgs.callPackage ({ vpl-gpu-rt }: vpl-gpu-rt) { };

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
          # swayfx-git = pkgs.callPackage (
          #   { swayfx }:
          #   swayfx.override {
          #     swayfx-unwrapped =
          #       inputs.swayfx-unwrapped-git.packages.${pkgs.stdenv.hostPlatform.system}.swayfx-unwrapped-git;
          #   }
          # ) { };
        }
      );

      overlays = {
        default = final: prev: {
          inherit (outputs.packages.${prev.stdenv.hostPlatform.system})
            # swayfx-git
            nixos
            emacs-unstable
            neovim-unstable
            niri-stable
            niri-unstable
            xwayland-satellite-stable
            xwayland-satellite-unstable
            ;
          my = {
            inherit (outputs.packages.${prev.stdenv.hostPlatform.system})
              mesa
              mesa-32
              intel-vaapi-driver
              intel-vaapi-driver-32
              intel-media-driver
              intel-media-driver-32
              intel-ocl
              intel-compute-runtime
              vpl-gpu-rt
              ;
          };
        };
      };
    };
}
