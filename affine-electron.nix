{
  buildType ? "stable",
  githubSha ? "ffffffffffffffffffffffffffffffffffffffff",
  lib,
  stdenv,
  stdenvNoCC,
  fetchFromGitHub,
  pkgs,
  rustPlatform,
  cacert,
  yarn,
  electron,
  fetchurl,
  copyDesktopItems,
  makeDesktopItem,
  makeWrapper,
  commandLineArgs ? "",
}:
let
  env = {
    GITHUB_SHA = githubSha;
    BUILD_TYPE = buildType;
    CI = "1";
  };
  src = ./.;
  version = "v33.2.0";
  electronPrebuiltInfo = {
    darwin-arm64 = {
      url = "https://github.com/electron/electron/releases/download/v33.2.0/electron-v33.2.0-darwin-arm64.zip";
      sha256 = "b78ec0f21a12effc6830b6ac70a71e226f3898dd1c2449b5230e071211fb4a73";
    };
    darwin-x64 = {
      url = "https://github.com/electron/electron/releases/download/v33.2.0/electron-v33.2.0-darwin-x64.zip";
      sha256 = "08a345c459103334643df9a093c4eab73eb3bd57bc86e75ca46e8e38b94bb2eb";
    };
    linux-x64 = {
      url = "https://github.com/electron/electron/releases/download/v33.2.0/electron-v33.2.0-linux-x64.zip";
      sha256 = "fc9e2a5f969d0fcf7546eb3299a2450329ba4f05c1baa4f0ed7b269b45e2232b";
    };
    linux-arm64 = {
      url = "https://github.com/electron/electron/releases/download/v33.2.0/electron-v33.2.0-linux-arm64.zip";
      sha256 = "246064a2f8b29e163c7d999ea1fb98e6a99e4614bb4b07a62f19777965bf19cc";
    };
  };
  icon = "${src}/packages/frontend/core/public/favicon-192.png";
  # nodejs's `process.platform`
  nodePlatform = lib.toLower stdenv.targetPlatform.uname.system;
  # nodejs's `process.arch`
  nodeArch =
    {
      "x86_64" = "x64";
      "aarch64" = "arm64";
    }
    .${stdenv.targetPlatform.uname.processor};
  nodePlatformArch = nodePlatform + "-" + nodeArch;
  cargoDeps = rustPlatform.importCargoLock {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "y-octo-0.0.1" = "sha256-ncLAsvSXkG+x4CWdYYDb4IgoqfP1W2Nhe7jqZzc2xsE=";
    };
  };
  yarnOfflineCache = stdenvNoCC.mkDerivation {
    name = "yarn-offline-cache";
    src = ./.;
    version = "0.0.1";

    nativeBuildInputs = [
      pkgs.nodePackages.yarn
    ];

    NODE_EXTRA_CA_CERTS = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    supportedArchitectures = builtins.toJSON {
      os = [
        "darwin"
        "linux"
      ];
      cpu = [
        "arm64"
        "x64"
      ];
      libc = [
        "glibc"
        "musl"
      ];
    };
    buildPhase = ''
      runHook preBuild

      export HOME="$NIX_BUILD_TOP"

      mkdir -p $out
      yarn config set cacheFolder $out
      yarn config set enableTelemetry false
      yarn config set enableGlobalCache false
      yarn config set supportedArchitectures --json "$supportedArchitectures"

      yarn install --immutable --mode=skip-build

      runHook postBuild
    '';

    dontInstall = true;

    outputHashAlgo = "sha256";
    outputHash = "sha256-HueTia+1ApfvbBK/b+iE84TB1DCWIDLoQ9XhjYlGCUs=";
    outputHashMode = "recursive";
  };
  affineElectron = stdenv.mkDerivation {
    pname = "affine";
    version = "0.18.0";

    meta = {
      description = "Workspace with fully merged docs, whiteboards and databases";
      longDescription = ''
        AFFiNE is an open-source, all-in-one workspace and an operating
        system for all the building blocks that assemble your knowledge
        base and much more -- wiki, knowledge management, presentation
        and digital assets
      '';
      homepage = "https://affine.pro/";
      license = lib.licenses.mit;
      # TODO: 把我自己加到 maintainers 里面
      # maintainers = with lib.maintainers; [ xiaoxiangmoe ];
      platforms = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      sourceProvenance = with lib.sourceTypes; [ fromSource ];
    };

    inherit
      src
      yarnOfflineCache
      cargoDeps
      env
      ;

    nativeBuildInputs = [
      pkgs.nodejs_18
      pkgs.nodePackages.yarn
      pkgs.cargo
      pkgs.rustc
      pkgs.findutils
      pkgs.tree
      pkgs.zip # electron-forge need zip
      copyDesktopItems
      makeWrapper
    ];

    electronPrebuiltZip = fetchurl electronPrebuiltInfo.${nodePlatformArch};

    patches = [ ./electron-build.diff ];

    configurePhase = ''
      export HOME="$NIX_BUILD_TOP"

      # cargo config
      mkdir -p .cargo
      cat $cargoDeps/.cargo/config.toml >> .cargo/config.toml
      ln -s $cargoDeps cargo-vendor-dir

      # yarn config
      yarn config set enableTelemetry false
      yarn config set enableGlobalCache false
      yarn config set cacheFolder $yarnOfflineCache

      # electron config
      mkdir .electron_zip_dir
      # ln -s $electronPrebuiltZip .electron_zip_dir/electron-v33.2.0-${nodePlatformArch}.zip
      cp $electronPrebuiltZip .electron_zip_dir/electron-v33.2.0-${nodePlatformArch}.zip
      export electron_zip_dir=$PWD/.electron_zip_dir
      export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    '';
    buildPhase = ''
      runHook preBuild

      # first build
      yarn install --immutable --immutable-cache
      CARGO_NET_OFFLINE=true yarn workspace @affine/native build
      SKIP_NX_CACHE=1 yarn workspace @affine/electron generate-assets

      # second build
      yarn config set nmMode classic
      yarn config set nmHoistingLimits workspaces
      find . -name 'node_modules' -type d -prune -exec rm -rf '{}' +
      yarn install --immutable --immutable-cache
      SKIP_WEB_BUILD=1 SKIP_BUNDLE=1 HOIST_NODE_MODULES=1 yarn workspace @affine/electron make

      runHook postBuild
    '';
    installPhase =
      let
        productName = if buildType == "stable" then "AFFiNE" else "AFFiNE-" + buildType;
      in
      if stdenv.targetPlatform.isDarwin then
        ''
          mkdir -p $out/Applications
          mv packages/frontend/apps/electron/out/${buildType}/${productName}-darwin-${nodeArch}/${productName}.app $out/Applications
        ''
      else if stdenv.targetPlatform.isLinux then
        ''
          mkdir -p $out/lib
          cd packages/frontend/apps/electron/out/${buildType}/${productName}-linux-${nodeArch}
          cp -r ./resources/* -t $out/lib/
          mkdir -p $out/share/doc/affine/
          cp LICENSE* $out/share/doc/affine/
          install -Dm644 ${icon} $out/share/pixmaps/affine.png
          makeWrapper "${electron}/bin/electron" $out/bin/affine \
            --inherit-argv0 \
            --add-flags $out/lib/app.asar \
            --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
            --add-flags ${lib.escapeShellArg commandLineArgs}
        ''
      else
        ''
          echo "Unsupported platform: ${stdenv.targetPlatform.system}"
          exit 1
        '';
    desktopItems = [
      (makeDesktopItem {
        name = "affine";
        desktopName = "AFFiNE";
        exec = "affine %U";
        terminal = false;
        icon = "affine";
        startupWMClass = "affine";
        categories = [ "Utility" ];
      })
    ];
  };
in
affineElectron
