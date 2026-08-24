{
  lib,
  stdenv,
  fetchurl,
  cmake,
  ninja,
  patchelf,
  glib,
  nss,
  nspr,
  atk,
  at-spi2-atk,
  libdrm,
  expat,
  libxkbcommon,
  libgbm,
  gtk3,
  pango,
  cairo,
  alsa-lib,
  dbus,
  at-spi2-core,
  cups,
  libGL,
  udev,
  systemdLibs,
  libxrandr,
  libxfixes,
  libxext,
  libxdamage,
  libxcomposite,
  libx11,
  libxshmfence,
  libxcb,
}:

let
  runtimeLibraryPath = lib.makeLibraryPath [
    glib
    nss
    nspr
    atk
    at-spi2-atk
    libdrm
    expat
    libxkbcommon
    libgbm
    gtk3
    pango
    cairo
    alsa-lib
    dbus
    at-spi2-core
    cups
    libGL
    udev
    systemdLibs
    libxcb
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxshmfence
  ];
  graphicsLibraryPath = lib.makeLibraryPath [
    stdenv.cc.cc
    libGL
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "casparcg-cef";
  version = "142.0.17";

  src = fetchurl {
    url = "https://github.com/CasparCG/dependencies/releases/download/cef/cef_binary_${finalAttrs.version}+g60aac24+chromium-142.0.7444.176_linux64_minimal.tar.bz2";
    hash = "sha256-HYnhmy9EYQX5of5v3Ja87YYkm1iEJB3MQBO3yU2r9CQ=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    patchelf
  ];

  buildTargets = [ "libcef_dll_wrapper" ];

  cmakeFlags = [
    (lib.cmakeBool "USE_SANDBOX" false)
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
  ];

  installPhase = ''
    runHook preInstall

    cefRoot="$out/lib/casparcg-cef-142"
    mkdir -p "$out/include/casparcg-cef-142" "$cefRoot"

    cp --recursive ../include "$out/include/casparcg-cef-142/"
    cp libcef_dll_wrapper/libcef_dll_wrapper.a "$cefRoot/"
    cp --recursive ../Resources/locales "$cefRoot/"
    cp ../Resources/*.pak ../Resources/icudtl.dat "$cefRoot/"
    cp \
      ../Release/chrome-sandbox \
      ../Release/libcef.so \
      ../Release/libEGL.so \
      ../Release/libGLESv2.so \
      ../Release/libvk_swiftshader.so \
      ../Release/libvulkan.so.1 \
      ../Release/v8_context_snapshot.bin \
      ../Release/vk_swiftshader_icd.json \
      "$cefRoot/"

    install -Dm644 ../LICENSE.txt "$out/share/licenses/casparcg-cef/LICENSE.txt"

    chmod 0755 "$cefRoot/chrome-sandbox"
    patchelf \
      --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
      --set-rpath "${runtimeLibraryPath}" \
      "$cefRoot/chrome-sandbox"
    patchelf \
      --add-needed libudev.so \
      --set-rpath "${runtimeLibraryPath}" \
      "$cefRoot/libcef.so"
    patchelf --set-rpath "${graphicsLibraryPath}" "$cefRoot/libEGL.so"
    patchelf \
      --add-needed libGL.so.1 \
      --set-rpath "${graphicsLibraryPath}" \
      "$cefRoot/libGLESv2.so"
    patchelf --set-rpath "${graphicsLibraryPath}" "$cefRoot/libvk_swiftshader.so"
    patchelf --set-rpath "${graphicsLibraryPath}" "$cefRoot/libvulkan.so.1"

    runHook postInstall
  '';

  dontStrip = true;
  dontPatchELF = true;
  strictDeps = true;

  meta = {
    description = "Chromium Embedded Framework runtime for CasparCG Server";
    homepage = "https://github.com/CasparCG/dependencies/releases/tag/cef";
    license = lib.licenses.bsd3;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
})
