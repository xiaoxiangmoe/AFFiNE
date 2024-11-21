{
  lib,
  stdenv,
  fetchFromGitHub,
  pkgs,
  githubSha ? "ffffffffffffffffffffffffffffffffffffffff",
  buildType ? "canary",
  rustPlatform,
  cacert,
  stdenvNoCC,
  yarn,
  electron,
  fetchurl
}:
let
  electronPrebuiltInfo = rec {
    version = "v33.2.0";
    zip = {
      darwin-arm64 = {
        url = "https://github.com/electron/electron/releases/download/v33.2.0/electron-v33.2.0-darwin-arm64.zip";
        sha256 = "b78ec0f21a12effc6830b6ac70a71e226f3898dd1c2449b5230e071211fb4a73";
      };
    };
  };
  electronPrebuiltZipDict = {
    darwin-arm64 = fetchurl electronPrebuiltInfo.zip.darwin-arm64;
  };
  yarnOfflineCache = stdenv.mkDerivation {
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
    outputHash = "sha256-/Qf7DNkiczAhTJxbtsbZF6wMRcez/ZwcmQX5+ZUwh7g=";
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

    src = ./.;

    sourceRoot = ".";
    cargoRoot = ".";

    cargoDeps = rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "y-octo-0.0.1" = "sha256-ncLAsvSXkG+x4CWdYYDb4IgoqfP1W2Nhe7jqZzc2xsE=";
      };
    };

    yarnOfflineCache = yarnOfflineCache;

    nativeBuildInputs = [
      pkgs.nodejs_18
      pkgs.nodePackages.yarn
      pkgs.cargo
      pkgs.rustc
      pkgs.rsync
      pkgs.findutils
      pkgs.tree
      pkgs.zip # electron-forge need zip
    ];

    env = {
      GITHUB_SHA = githubSha;
      BUILD_TYPE = buildType;
    };
    electronPrebuiltZip = electronPrebuiltZipDict.darwin-arm64;
    phases = [
      "buildPhase"
      "installPhase"
    ];
    buildPhase = ''
      runHook preBuild

      export HOME="$NIX_BUILD_TOP"
      rsync --archive --chmod=u+w $src/{.*,*} .

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
      ln -s $electronPrebuiltZip .electron_zip_dir/electron-v33.2.0-darwin-arm64.zip
      export electron_zip_dir=$PWD/.electron_zip_dir
      export ELECTRON_SKIP_BINARY_DOWNLOAD=1

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
          mv packages/frontend/apps/electron/out/${buildType}/${productName}-darwin-${stdenv.targetPlatform.darwinArch}/${productName}.app $out/Applications
        ''
      else if stdenv.targetPlatform.isLinux then
        ''
          mkdir -p $out/opt
          mv packages/frontend/apps/electron/out/${buildType}/${productName}-${stdenv.targetPlatform.linuxArch}/${productName} $out/opt
        ''
      else
        ''
          echo "Unsupported platform: ${stdenv.targetPlatform.system}"
          exit 1
        '';

  };
in
affineElectron
