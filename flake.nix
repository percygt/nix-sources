{
  description = "PercyGT's nix sources";
  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";

    scenefx.url = "github:wlrfx/scenefx";
    scenefx.inputs.nixpkgs.follows = "nixpkgs";
    swayfx-unwrapped = {
      url = "github:WillPower3309/swayfx";
      flake = false;
    };
    keepmenu = {
      url = "github:percygt/keepmenu";
      flake = false;
    };

    pykeepass = {
      url = "github:libkeepass/pykeepass";
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
      forAllSystemsMaster = packagesFrom inputs.nixpkgs-master;
      forAllSystemsStable = packagesFrom inputs.nixpkgs-stable;
    in
    {
      packages =
        (forAllSystems (pkgs: {
          keepmenu = pkgs.callPackage (
            { keepmenu, python3Packages }:
            keepmenu.overrideAttrs (
              _: prev: {
                installCheckPhase = ''true''; # TODO: Remove once https://github.com/NixOS/nixpkgs/pull/328672 is merged
                propagatedBuildInputs =
                  [ python3Packages.pynput ]
                  ++ [
                    (python3Packages.pykeepass.overrideAttrs (_: {
                      src = inputs.pykeepass;
                    }))
                  ];
                src = inputs.keepmenu;
              }
            )
          ) { };
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
          emacs-unstable = pkgs.callPackage (
            { emacs-unstable }: emacs-unstable.override { withTreeSitter = true; }
          ) { };
          neovim-unstable = pkgs.callPackage ({ neovim }: neovim) { };
        }))
        // (forAllSystemsMaster (pkgs: { }))
        // (forAllSystemsStable (pkgs: { }));

      overlays = {
        default = final: prev: {
          inherit (outputs.packages.${prev.system})
            foot
            keepmenu
            swayfx-unwrapped
            emacs-unstable
            neovim-unstable
            ;
        };
      };
    };
}
