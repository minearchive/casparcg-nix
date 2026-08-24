{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  patchelf,
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
  cef ? null,
  withHtml ? false,
}:

assert lib.assertMsg (
  !withHtml || cef != null
) "CEF is required when HTML Producer support is enabled";

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

  patches = [
    ./patches/gcc-15-cstdint.patch
  ]
  ++ lib.optionals withHtml [
    ./patches/cef-runtime-paths.patch
  ];

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ]
  ++ lib.optionals withHtml [ patchelf ];

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
  ]
  ++ lib.optionals withHtml [ cef ];

  cmakeFlags = [
    (lib.cmakeBool "ENABLE_AVX2" true)
    (lib.cmakeBool "ENABLE_HTML" withHtml)
    (lib.cmakeFeature "CASPARCG_BINARY_NAME" "casparcg-server")
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
    (lib.cmakeFeature "DIAG_FONT_PATH" "${liberation_ttf}/share/fonts/truetype/LiberationMono-Regular.ttf")
  ]
  ++ lib.optionals withHtml [
    (lib.cmakeBool "USE_SYSTEM_CEF" true)
    (lib.cmakeFeature "CASPARCG_CEF_INCLUDE_PATH" "${cef}/include/casparcg-cef-142")
    (lib.cmakeFeature "CASPARCG_CEF_LIBRARY_PATH" "${cef}/lib/casparcg-cef-142")
    (lib.cmakeFeature "CASPARCG_CEF_RESOURCE_PATH" "${cef}/lib/casparcg-cef-142")
  ];

  env.GIT_HASH = "69e8ad5";

  postFixup = lib.optionalString withHtml ''
    patchelf --add-rpath "${cef}/lib/casparcg-cef-142" "$out/bin/casparcg-server"
  '';

  strictDeps = true;

  meta = {
    description = "Professional graphics and video playout server";
    homepage = "https://casparcg.com/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "casparcg-server";
    platforms = [ "x86_64-linux" ];
  };
})
