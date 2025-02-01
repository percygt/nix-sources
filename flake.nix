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
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    swayfx-unwrapped.url = "github:WillPower3309/swayfx";
    # swayfx-unwrapped.inputs.nixpkgs.follows = "nixpkgs";
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay/";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs-stable";
      };
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
            swayfx-unwrapped =
              inputs.swayfx-unwrapped.packages.${pkgs.system}.swayfx-unwrapped.overrideAttrs
                (oldAttrs: {
                  postInstall =
                    let
                      swaySession = ''
                        [Desktop Entry]
                        Name=SwayNvidia
                        Comment=An i3-compatible Wayland compositor
                        Exec=sway --unsupported-gpu
                        Type=Application
                      '';
                    in
                    ''
                      [ ! -d $out/share/wayland-sessions ] && mkdir -p $out/share/wayland-sessions
                      echo "${swaySession}" > $out/share/wayland-sessions/sway-nvidia.desktop
                    '';
                  providedSessions = oldAttrs.providedSessions ++ [ "sway-nvidia" ];
                });
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
            # emacs-pgtk
            # emacs-unstable-pgtk
            neovim-unstable
            nix-your-shell
            ;
        };
      };
    };
}
