{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  boost188,
  ffmpeg_7,
  glew,
  icu,
  libglvnd,
  libjpeg,
  liberation_ttf,
  libx11,
  libxrandr,
  openal,
  sfml_2,
  simde,
  tbb,
  zlib,
  withHtml ? false,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "casparcg-server${lib.optionalString (!withHtml) "-minimal"}";
  version = "2.5.0";

  src = fetchFromGitHub {
    owner = "CasparCG";
    repo = "server";
    rev = "69e8ad552df7a38615f0581688bd861b09de8b94";
    hash = "sha256-1Ch0S5Iwk0knxisI/IgMgklUpAZiiq0VdO98j3yZj+w=";
  };

  sourceRoot = "${finalAttrs.src.name}/src";

  patches = [ ./patches/gcc-15-cstdint.patch ];

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];

  buildInputs = [
    boost188
    ffmpeg_7
    glew
    icu
    libglvnd
    libjpeg
    libx11
    libxrandr
    openal
    sfml_2
    simde
    tbb
    zlib
  ];

  cmakeFlags = [
    (lib.cmakeBool "ENABLE_AVX2" true)
    (lib.cmakeBool "ENABLE_HTML" withHtml)
    (lib.cmakeFeature "CASPARCG_BINARY_NAME" "casparcg-server")
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
    (lib.cmakeFeature "DIAG_FONT_PATH" "${liberation_ttf}/share/fonts/truetype/LiberationMono-Regular.ttf")
  ];

  env.GIT_HASH = "69e8ad5";

  strictDeps = true;

  meta = {
    description = "Professional graphics and video playout server";
    homepage = "https://casparcg.com/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "casparcg-server";
    platforms = [ "x86_64-linux" ];
  };
})
