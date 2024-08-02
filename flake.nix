{
  description = "PercyGT's nix sources";
  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    scenefx.url = "github:wlrfx/scenefx";
    scenefx.inputs.nixpkgs.follows = "nixpkgs";
    swayfx-unwrapped = {
      url = "github:WillPower3309/swayfx";
      flake = false;
    };

    foot = {
      url = "git+https://codeberg.org/dnkl/foot";
      flake = false;
    };

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs-stable";
      };
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
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
      forEachSystem = inputs.nixpkgs.lib.genAttrs systems;
      overlays = {
        emacs = inputs.emacs-overlay.overlay;
        # swayfx-unwrapped = inputs.swayfx-unwrapped.overlays.default;
        neovim-nightly = inputs.neovim-nightly-overlay.overlays.default;
        scenefx = inputs.scenefx.overlays.insert;
      };
      forAllSystems =
        function:
        forEachSystem (
          system:
          function (
            import inputs.nixpkgs {
              inherit system;
              overlays = builtins.attrValues overlays;
              config.allowUnfree = true;
            }
          )
        );
    in
    {
      packages = forAllSystems (pkgs: {
        foot = pkgs.callPackage (
          { foot }:
          foot.overrideAttrs (_: {
            src = inputs.foot;
          })
        ) { };
        swayfx-unwrapped = pkgs.callPackage (
          { swayfx-unwrapped }:
          swayfx-unwrapped.overrideAttrs (old: {
            version = "0.4.0-git";
            src = inputs.swayfx-unwrapped;
            nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.cmake ];
            buildInputs = old.buildInputs ++ [ pkgs.scenefx ];
          })
        ) { };
        emacs-unstable-pgtk = pkgs.callPackage (
          { emacs-unstable-pgtk }: emacs-unstable-pgtk.override { withTreeSitter = true; }
        ) { };
        neovim-unstable = pkgs.callPackage ({ neovim }: neovim) { };
      });

      overlays = {
        default = final: prev: {
          inherit (outputs.packages.${prev.system})
            foot
            swayfx-unwrapped
            emacs-unstable-pgtk
            neovim-unstable
            ;
        };
      };
    };
}
