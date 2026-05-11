{
  lib,
  stdenv,
  fetchurl,
  buildPackages,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  adwaita-icon-theme,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  qt6,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libdrm,
  libkrb5,
  libuuid,
  libxkbcommon,
  libxshmfence,
  libgbm,
  nspr,
  nss,
  pango,
  pipewire,
  snappy,
  udev,
  wayland,
  xdg-utils,
  coreutils,
  libxcb,
  zlib,
  unzip,
  makeWrapper,
  commandLineArgs ? "",
  # Extra raw flags appended after all other flags.
  # Useful for renderer tuning (e.g. --use-gl=angle) without baking them in.
  extraBraveFlags ? [ ],
  pulseSupport ? stdenv.hostPlatform.isLinux,
  libpulseaudio,
  libGL,
  libvaSupport ? stdenv.hostPlatform.isLinux,
  libva,
  enableVideoAcceleration ? libvaSupport,
  vulkanSupport ? false,
  addDriverRunpath,
  enableVulkan ? vulkanSupport,
}:
{
  pname,
  version,
  archives,
  channel ? "stable",
  flavor ? "browser",
}:
let
  inherit (lib)
    optional
    optionals
    makeLibraryPath
    makeSearchPathOutput
    makeBinPath
    optionalString
    strings
    escapeShellArg
    ;

  flavorData = {
    browser = {
      optStem = "brave";
      fileStem = "brave-browser";
      appIdStem = "com.brave.Browser";
      darwinStem = "Brave Browser";
      changelogFile = "CHANGELOG_DESKTOP.md";
      iconsCarryChannelSuffix = true;
      homepages = {
        stable = "https://brave.com/";
        beta = "https://brave.com/download-beta/";
        nightly = "https://brave.com/download-nightly/";
      };
    };
    origin = {
      optStem = "brave-origin";
      fileStem = "brave-origin";
      appIdStem = "com.brave.Origin";
      darwinStem = "Brave Origin";
      changelogFile = "CHANGELOG_DESKTOP_ORIGIN.md";
      iconsCarryChannelSuffix = false;
      homepages = {
        beta = "https://brave.com/origin/download-beta/";
        nightly = "https://brave.com/origin/download-nightly/";
      };
    };
  };

  fd = flavorData.${flavor};

  channelDashSuffix = if channel == "stable" then "" else "-${channel}";
  channelDotSuffix = if channel == "stable" then "" else ".${channel}";
  channelSpaceSuffix =
    if channel == "stable" then
      ""
    else
      " ${lib.toUpper (lib.substring 0 1 channel)}${lib.substring 1 (-1) channel}";

  optName = fd.optStem + channelDashSuffix;
  fileBase = fd.fileStem + channelDashSuffix;
  appId = fd.appIdStem + channelDotSuffix;
  innerWrapper = fileBase;
  darwinApp = fd.darwinStem + channelSpaceSuffix;

  upstreamBin =
    if flavor == "browser" && channel == "stable" then "brave-browser-stable" else fileBase;

  # Icon suffix used in *filenames* inside /opt (e.g. product_logo_16_beta.png).
  iconSuffix = if fd.iconsCarryChannelSuffix && channel != "stable" then "_${channel}" else "";

  # The name GTK looks up via XDG_DATA_DIRS.  We normalise to the fileStem
  # (dropping the channel suffix) so that e.g. both brave-browser and
  # brave-browser-beta resolve to the same visual icon family, and so that the
  # Icon= line in .desktop files matches what we actually install.
  iconName = fd.fileStem;

  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    gtk4
    libdrm
    libx11
    libGL
    libxkbcommon
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxshmfence
    libxtst
    libuuid
    libgbm
    nspr
    nss
    pango
    pipewire
    udev
    wayland
    libxcb
    zlib
    snappy
    libkrb5
    qt6.qtbase
  ]
  ++ optional pulseSupport libpulseaudio
  ++ optional libvaSupport libva;

  rpath = makeLibraryPath deps + ":" + makeSearchPathOutput "lib" "lib64" deps;
  binpath = makeBinPath deps;

  # Current Chromium feature flag names (the Vaapi* names were removed).
  enableFeatures =
    optionals enableVideoAcceleration [
      "AcceleratedVideoDecodeLinuxGL"
      "AcceleratedVideoEncoder"
    ]
    ++ optional enableVulkan "Vulkan";

  disableFeatures = [
    "OutdatedBuildDetector"
  ]
  ++ optionals enableVideoAcceleration [ "UseChromeOSDirectVideoDecoder" ];

  archive =
    assert lib.assertMsg (builtins.hasAttr stdenv.hostPlatform.system archives)
      "${pname} is not available for ${stdenv.hostPlatform.system}";
    archives.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  inherit pname version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl { inherit (archive) url hash; };

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;
  dontCheckForBrokenSymlinks = true;

  doInstallCheck = stdenv.hostPlatform.isLinux;

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [
      dpkg
      (buildPackages.wrapGAppsHook3.override { makeWrapper = buildPackages.makeShellWrapper; })
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      unzip
      makeWrapper
    ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    glib
    gsettings-desktop-schemas
    gtk3
    gtk4
    adwaita-icon-theme
  ];

  installPhase =
    lib.optionalString stdenv.hostPlatform.isLinux ''
      runHook preInstall

      mkdir -p $out $out/bin
      cp -R usr/share $out
      cp -R opt/ $out/opt

      export BINARYWRAPPER=$out/opt/brave.com/${optName}/${innerWrapper}

      substituteInPlace $BINARYWRAPPER \
        --replace-fail /bin/bash ${stdenv.shell} \
        --replace-fail 'CHROME_WRAPPER' 'WRAPPER'

      ln -sf $BINARYWRAPPER $out/bin/${pname}

      for exe in $out/opt/brave.com/${optName}/{brave,chrome_crashpad_handler}; do
        patchelf \
          --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
          --set-rpath "${rpath}" $exe
      done

      # Fix Exec= path and normalise Icon= to the channel-agnostic fileStem so
      # the name matches the hicolor symlinks we create below.
      substituteInPlace $out/share/applications/{${fileBase},${appId}}.desktop \
        --replace-fail /usr/bin/${upstreamBin} $out/bin/${pname} \
        --replace-fail "Icon=${fileBase}"       "Icon=${iconName}"

      substituteInPlace $out/share/gnome-control-center/default-apps/${fileBase}.xml \
        --replace-fail /opt/brave.com $out/opt/brave.com

      substituteInPlace $out/opt/brave.com/${optName}/default-app-block \
        --replace-fail /opt/brave.com $out/opt/brave.com

      # Install icons under the normalised name (iconName, no channel suffix)
      # so they match the Icon= key we set above.
      icon_sizes=("16" "24" "32" "48" "64" "128" "256")
      for icon in ''${icon_sizes[*]}; do
        mkdir -p $out/share/icons/hicolor/''${icon}x''${icon}/apps
        ln -s \
          $out/opt/brave.com/${optName}/product_logo_''${icon}${iconSuffix}.png \
          $out/share/icons/hicolor/''${icon}x''${icon}/apps/${iconName}.png
      done

      ln -sf ${xdg-utils}/bin/xdg-settings $out/opt/brave.com/${optName}/xdg-settings
      ln -sf ${xdg-utils}/bin/xdg-mime     $out/opt/brave.com/${optName}/xdg-mime

      runHook postInstall
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      runHook preInstall
      mkdir -p $out/{Applications,bin}
      cp -r . "$out/Applications/${darwinApp}.app"
      makeWrapper \
        "$out/Applications/${darwinApp}.app/Contents/MacOS/${darwinApp}" \
        $out/bin/${pname}
      runHook postInstall
    '';

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      --prefix PATH            : ${binpath}
      --suffix PATH            : ${
        lib.makeBinPath [
          xdg-utils
          coreutils
        ]
      }
      --set CHROME_WRAPPER ${pname}
      ${optionalString (enableFeatures != [ ]) ''
        --add-flags "--enable-features=${strings.concatStringsSep "," enableFeatures}\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+,WaylandWindowDecorations --enable-wayland-ime=true}}"
      ''}
      ${optionalString (disableFeatures != [ ]) ''
        --add-flags "--disable-features=${strings.concatStringsSep "," disableFeatures}"
      ''}
      ${optionalString (extraBraveFlags != [ ]) ''
        --add-flags "${strings.concatStringsSep " " extraBraveFlags}"
      ''}
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
      ${optionalString vulkanSupport ''
        --prefix XDG_DATA_DIRS : "${addDriverRunpath.driverLink}/share"
      ''}
      --add-flags ${escapeShellArg commandLineArgs}
    )
  '';

  # Bypass the upstream shell wrapper so stderr is not suppressed.
  installCheckPhase = ''
    $out/opt/brave.com/${optName}/brave --version
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    homepage = fd.homepages.${channel};
    description =
      "Privacy-oriented browser for Desktop and Laptop computers"
      + lib.optionalString (flavor == "origin") " (Origin variant)"
      + lib.optionalString (channel != "stable") " (${channel} channel)";
    changelog =
      "https://github.com/brave/brave-browser/blob/master/${fd.changelogFile}#"
      + lib.replaceStrings [ "." ] [ "" ] version;
    longDescription =
      if flavor == "origin" then
        ''
          Brave Origin is a stripped-down variant of the Brave browser that
          removes most non-privacy features (rewards, wallet, AI, etc.) while
          keeping the core privacy, adblock and Chromium-based browsing
          experience.
        ''
      else
        ''
          Brave browser blocks the ads and trackers that slow you down,
          chew up your bandwidth, and invade your privacy. Brave lets you
          contribute to your favourite creators automatically.
        '';
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.mpl20;
    platforms = builtins.attrNames archives;
    mainProgram = pname;
  };
}
