{
  description = "PercyGT's nix sources";
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://niri.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    ];
  };
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    niri.url = "github:sodiboo/niri-flake";
    niri.inputs.nixpkgs.follows = "nixpkgs";

    swayfx-unwrapped-git.url = "github:WillPower3309/swayfx";
    # swayfx-unwrapped-git.inputs.nixpkgs.follows = "nixpkgs";
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay/";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs-stable";
      };
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      # IMPORTANT: we're using "libgbm" and is only available in unstable so ensure
      # to have it up to date or simply don't specify the nixpkgs input
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-your-shell = {
      url = "github:MercuryTechnologies/nix-your-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
        nix-your-shell = inputs.nix-your-shell.overlays.default;
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
        niri-stable = inputs.niri.packages."${pkgs.system}".niri-stable;
        niri-unstable = inputs.niri.packages."${pkgs.system}".niri-unstable;
        zen-browser = inputs.zen-browser.packages."${pkgs.system}".default;
        zen-browser-beta = inputs.zen-browser.packages."${pkgs.system}".beta;
        zen-browser-twilight = inputs.zen-browser.packages."${pkgs.system}".twilight;
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
        nix-your-shell = pkgs.callPackage ({ nix-your-shell }: nix-your-shell) { };
      });

      overlays = {
        default = final: prev: {
          inherit (outputs.packages.${prev.system})
            swayfx-git
            emacs-unstable
            zen-browser
            zen-browser-beta
            zen-browser-twilight
            neovim-unstable
            niri-stable
            niri-unstable
            nix-your-shell
            ;
        };
      };
    };
}
