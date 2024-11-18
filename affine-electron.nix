{
  lib,
  stdenv,
  fetchFromGitHub,
  pkgs,
  githubSha ? "ffffffffffffffffffffffffffffffffffffffff",
  buildType ? "canary",
}:
stdenv.mkDerivation {
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

  nativeBuildInputs = [
    pkgs.nodejs_18
    pkgs.nodePackages.yarn
    pkgs.cargo
    pkgs.rustc
    pkgs.rsync
    pkgs.cacert
    pkgs.findutils
    pkgs.zip # electron-forge need zip
  ];

  env = {
    GITHUB_SHA = githubSha;
    BUILD_TYPE = buildType;
  };
  phases = [
    "buildPhase"
    "installPhase"
  ];

  buildPhase = ''
    export HOME=$PWD/.home
    echo "Building $BUILD_TYPE in commit sha: $GITHUB_SHA"
    rsync --archive --chmod=u+w $src/{.*,*} .
    yarn config set enableTelemetry false

    yarn install --immutable
    yarn workspace @affine/native build
    SKIP_NX_CACHE=1 yarn workspace @affine/electron generate-assets

    yarn config set nmMode classic
    yarn config set nmHoistingLimits workspaces
    find . -name 'node_modules' -type d -prune -exec rm -rf '{}' +
    yarn install --immutable

    SKIP_WEB_BUILD=1 SKIP_BUNDLE=1 HOIST_NODE_MODULES=1 yarn workspace @affine/electron make
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

}
