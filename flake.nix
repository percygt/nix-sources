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
    swayfx-unwrapped.url = "github:WillPower3309/swayfx";
    swayfx-unwrapped.inputs.nixpkgs.follows = "nixpkgs";
    swayfx-unwrapped.inputs.scenefx.follows = "scenefx";
    # swayfx-unwrapped = {
    #   url = "github:WillPower3309/swayfx";
    #   flake = false;
    # };

    firefox-nightly.url = "github:nix-community/flake-firefox-nightly";
    firefox-nightly.inputs.nixpkgs.follows = "nixpkgs";

    zen-browser.url = "github:MarceColl/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

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
        emacs = inputs.emacs-overlay.overlays.default;
        # swayfx-unwrapped = inputs.swayfx-unwrapped.overlays.default;
        # scenefx = inputs.scenefx.overlays.insert;
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
        firefox-nightly = inputs.firefox-nightly.packages.${pkgs.system}.firefox-nightly-bin;
        zen-browser = inputs.zen-browser.packages."${pkgs.system}".default;
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
        emacs-unstable = pkgs.callPackage (
          { emacs-unstable }:
          emacs-unstable.override {
            withTreeSitter = true;
          }
        ) { };
        # emacs-pgtk = pkgs.callPackage (
        #   { emacs-unstable-pgtk }:
        #   emacs-unstable-pgtk.override {
        #     withTreeSitter = true;
        #   }
        # ) { };
        emacs-unstable-pgtk = pkgs.callPackage (
          { emacs-unstable-pgtk }:
          emacs-unstable-pgtk.override {
            withTreeSitter = true;
          }
        ) { };
        swayfx-git = pkgs.callPackage (
          { swayfx }:
          swayfx.override {
            swayfx-unwrapped = inputs.swayfx-unwrapped.packages.${pkgs.system}.swayfx-unwrapped;
          }
        ) { };
        # nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.cmake ];
        # buildInputs = old.buildInputs ++ [
        #   (pkgs.scenefx.overrideAttrs (oldAttrs: {
        #     depsBuildBuild = [ pkgs.pkg-config ];
        #     nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ pkgs.wayland-scanner ];
        #   }))
        # ];
        # swayfx-git = pkgs.callPackage (
        #   { swayfx-unwrapped }:
        #   swayfx-unwrapped.overrideAttrs (old: {
        #     version = "0.4.0-git";
        #     src = inputs.swayfx-unwrapped;
        #     nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.cmake ];
        #     buildInputs = old.buildInputs ++ [ pkgs.scenefx ];
        #   })
        # ) { };
        neovim-unstable = pkgs.callPackage ({ neovim }: neovim) { };
      });

      overlays = {
        default = final: prev: {
          inherit (outputs.packages.${prev.system})
            foot
            firefox-nightly
            zen-browser
            keepmenu
            swayfx-git
            emacs-unstable
            emacs-pgtk
            emacs-unstable-pgtk
            neovim-unstable
            ;
        };
      };
    };
}
