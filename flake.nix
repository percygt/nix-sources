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

    quickemu.url = "github:TuxVinyards/quickemu/freespirit-next";
    quickemu.flake = false;

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
        zen-browser = inputs.zen-browser.packages."${pkgs.system}".default;
        zen-browser-beta = inputs.zen-browser.packages."${pkgs.system}".beta;
        zen-browser-twilight = inputs.zen-browser.packages."${pkgs.system}".twilight;
        quickemu = pkgs.callPackage (
          {
            quickemu,
            spice-gtk,
            lib,
            stdenv,
            cdrtools,
            curl,
            gawk,
            mesa-demos,
            gnugrep,
            gnused,
            jq,
            pciutils,
            procps,
            python3,
            qemu_full,
            socat,
            swtpm,
            usbutils,
            util-linux,
            unzip,
            xdg-user-dirs,
            xrandr,
            zsync,
          }:
          let
            runtimePaths =
              [
                cdrtools
                curl
                gawk
                gnugrep
                gnused
                jq
                pciutils
                procps
                python3
                qemu_full
                socat
                swtpm
                util-linux
                unzip
                xrandr
                zsync
              ]
              ++ lib.optionals stdenv.hostPlatform.isLinux [
                mesa-demos
                usbutils
                xdg-user-dirs
              ];
          in
          quickemu.overrideAttrs (oldAttrs: {
            src = inputs.quickemu;
            installPhase = ''
              runHook preInstall

              installManPage docs/quickget.1 docs/quickemu.1 docs/quickemu_conf.5
              install -Dm755 -t "$out/bin" chunkcheck quickemu quickget quickreport

              # spice-gtk needs to be put in suffix so that when virtualisation.spiceUSBRedirection
              # is enabled, the wrapped spice-client-glib-usb-acl-helper is used
              for f in chunkcheck quickget quickemu quickreport; do
                wrapProgram $out/bin/$f \
                  --prefix PATH : "${lib.makeBinPath runtimePaths}" \
                  --suffix PATH : "${lib.makeBinPath [ spice-gtk ]}"
              done

              runHook postInstall
            '';
          })
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
            inherit (inputs.swayfx-unwrapped.packages.${pkgs.system}) swayfx-unwrapped;
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
            quickemu
            # emacs-pgtk
            # emacs-unstable-pgtk
            neovim-unstable
            nix-your-shell
            ;
        };
      };
    };
}
