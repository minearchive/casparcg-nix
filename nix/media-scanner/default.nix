{
  lib,
  stdenv,
  fetchFromGitHub,
  ffmpeg_7,
  makeWrapper,
  node-gyp,
  nodejs_24,
  python3,
  yarn-berry_4,
}:

let
  yarnBerry = yarn-berry_4.override { nodejs = nodejs_24; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "casparcg-media-scanner";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "CasparCG";
    repo = "media-scanner";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Esa88aE2GzomrITFmxbcQGk20fKDuq3zzt187NipOAU=";
  };

  patches = [
    ./yarn-4.14-support.patch
    ./native-leveldown.patch
  ];

  offlineCache = yarnBerry.fetchYarnBerryDeps {
    inherit (finalAttrs) src patches missingHashes;
    hash = "sha256-3Mh4ks7wUGbzTEgIW+Buck/9mrAS0gtlz7Guiu0MkfA=";
  };

  missingHashes = ./missing-hashes.json;

  nativeBuildInputs = [
    makeWrapper
    node-gyp
    nodejs_24
    python3
    yarnBerry
    yarnBerry.yarnBerryConfigHook
  ];

  buildInputs = [ nodejs_24 ];

  env = {
    UNPACKED = "1";
    YARN_ENABLE_SCRIPTS = "0";
  };

  preBuild = ''
    rm -rf node_modules/leveldown/build node_modules/leveldown/prebuilds
    pushd node_modules/leveldown
    node-gyp rebuild
    popd
  '';

  buildPhase = ''
    runHook preBuild

    yarn build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm644 deploy/scanner.js "$out/lib/casparcg-media-scanner/scanner.js"
    cp --recursive deploy/build "$out/lib/casparcg-media-scanner/build"

    makeWrapper "${nodejs_24}/bin/node" "$out/bin/media-scanner" \
      --add-flags "$out/lib/casparcg-media-scanner/scanner.js" \
      --prefix PATH : "${lib.makeBinPath [ ffmpeg_7 ]}" \
      --set NODE_ENV production
    ln -s media-scanner "$out/bin/scanner"

    runHook postInstall
  '';

  strictDeps = true;

  meta = {
    description = "Media metadata and thumbnail scanner for CasparCG Server";
    homepage = "https://github.com/CasparCG/media-scanner";
    license = lib.licenses.lgpl3Plus;
    mainProgram = "media-scanner";
    platforms = [ "x86_64-linux" ];
  };
})
