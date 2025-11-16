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
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs.follows = "nixpkgs-unstable";

    niri.url = "github:sodiboo/niri-flake";
    scenefx = {
      url = "github:wlrfx/scenefx";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    swayfx-git.url = "github:WillPower3309/swayfx";
    swayfx-git.flake = false;
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
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
      packages = forAllSystems (pkgs: {
        niri-stable = pkgs.callPackage ({ niri-stable }: niri-stable) { };
        niri-unstable = pkgs.callPackage ({ niri-unstable }: niri-unstable) { };
        xwayland-satellite-stable = pkgs.callPackage (
          { xwayland-satellite-stable }: xwayland-satellite-stable
        ) { };
        xwayland-satellite-unstable = pkgs.callPackage (
          { xwayland-satellite-unstable }: xwayland-satellite-unstable
        ) { };
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
        foot = pkgs.callPackage ({ foot }: foot) { };
        # swayfx-unstable = pkgs.callPackage (
        #   { swayfx, swayfx-unwrapped }:
        #   swayfx.override {
        #     swayfx-unwrapped = swayfx-unwrapped.overrideAttrs (old: {
        #       version = "git";
        #       src = pkgs.lib.cleanSource inputs.swayfx-git;
        #       nativeBuildInputs = with pkgs; [
        #         meson
        #         ninja
        #         pkg-config
        #         wayland-scanner
        #         scdoc
        #       ];
        #       buildInputs =
        #         with pkgs;
        #         [
        #           libGL
        #           wayland
        #           libxkbcommon
        #           pcre2
        #           json_c
        #           libevdev
        #           pango
        #           cairo
        #           libinput
        #           gdk-pixbuf
        #           librsvg
        #           wayland-protocols
        #           libdrm
        #           xorg.xcbutilwm
        #           wlroots_0_19
        #         ]
        #         ++ [ inputs.scenefx.packages.${pkgs.stdenv.hostPlatform.system}.scenefx-git ];
        #     });
        #   }
        # ) { };
      });

      overlays = {
        default = final: prev: {
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
          inherit (outputs.packages.${prev.stdenv.hostPlatform.system})
            niri-stable
            niri-unstable
            # swayfx-unstable
            xwayland-satellite-stable
            xwayland-satellite-unstable
            foot
            ;
        };
      };
    };
}
