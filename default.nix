# orca-slicer nix module
# based on work <zhaofengli> (https://github.com/zhaofengli/nixpkgs/tree/bambu-studio)
{ stdenv
, lib
, binutils
, fetchFromGitHub
, cmake
, pkg-config
, wrapGAppsHook
, boost
, cereal
, cgal_5
, curl
, dbus
, eigen
, expat
, gcc-unwrapped
, glew-egl
, glfw
, glib
, glib-networking
, gmp
, gstreamer
, gst-plugins-base
, gst-plugins-bad
, gtest
, gtk3
, hicolor-icon-theme
, ilmbase
, libpng
, mesa
, mpfr
, nlopt
, opencascade-occt
, openvdb
, pcre
, qhull
, systemd
, tbb_2021_8
, webkitgtk
, oWxGTK31
, xorg
, fetchpatch
, openexr
, jemalloc
, c-blosc
, withSystemd ? stdenv.isLinux
}:
let
  wxGTK31' = oWxGTK31.overrideAttrs (old: {
    configureFlags = old.configureFlags ++ [
      # Disable noisy debug dialogs
      "--enable-debug=no"
    ];
  });
  openvdb_tbb_2021_8 = openvdb.overrideAttrs (old: rec {
    buildInputs = [ openexr boost tbb_2021_8 jemalloc c-blosc ilmbase ];
  });
in
stdenv.mkDerivation rec {
  pname = "orca-slicer";
  version = "1.8.0-beta";

  src = fetchFromGitHub {
    owner = "SoftFever";
    repo = "OrcaSlicer";
    rev = "v${version}";
    hash = "sha256-9d7f10c176fa506cf77845e0fbd14f51dab81da9";
  };

  patches = [
    # https://github.com/wxWidgets/wxWidgets/issues/17942
    ./0001-segv-patches.patch
    ./0002-cmake-fix.patch
    ./0003-fix-ambiguous-call.patch
    ./0004-fix-ambiguous-call.patch
  ];

  dontStrip = true;
  enableDebugging = true;

  nativeBuildInputs = [
    cmake
    pkg-config
    wrapGAppsHook
  ];

  buildInputs = [
    binutils
    boost
    cereal
    cgal_5
    curl
    dbus
    eigen
    expat
    gcc-unwrapped
    glew-egl
    glfw
    glib
    glib-networking
    gmp
    gstreamer
    gst-plugins-base
    gst-plugins-bad
    gtk3
    hicolor-icon-theme
    ilmbase
    libpng
    mesa.osmesa
    mpfr
    nlopt
    opencascade-occt
    openvdb_tbb_2021_8
    pcre
    tbb_2021_8
    webkitgtk
    wxGTK31'
    xorg.libX11
  ] ++ lib.optionals withSystemd [
    systemd
  ] ++ checkInputs;


  doCheck = true;
  checkInputs = [ gtest ];


  # The build system uses custom logic - defined in
  # cmake/modules/FindNLopt.cmake in the package source - for finding the nlopt
  # library, which doesn't pick up the package in the nix store.  We
  # additionally need to set the path via the NLOPT environment variable.
  NLOPT = nlopt;

  # Disable compiler warnings that clutter the build log.
  # It seems to be a known issue for Eigen:
  # http://eigen.tuxfamily.org/bz/show_bug.cgi?id=1221
  NIX_CFLAGS_COMPILE = "-Wno-ignored-attributes";

  # prusa-slicer uses dlopen on `libudev.so` at runtime
  NIX_LDFLAGS = lib.optionalString withSystemd "-ludev";

  # TODO: macOS
  prePatch = ''
    # Since version 2.5.0 of nlopt we need to link to libnlopt, as libnlopt_cxx
    # now seems to be integrated into the main lib.
    sed -i 's|nlopt_cxx|nlopt|g' cmake/modules/FindNLopt.cmake
  '';

  cmakeFlags = [
    "-DSLIC3R_STATIC=0"
    "-DSLIC3R_FHS=1"
    "-DSLIC3R_GTK=3"
    "-DwxWidgets_PREFIX=${oWxGTK31}"
    "-DTBB_ROOT_DIR=${tbb_2021_8}"

    # Debug - delete me!
    "-DCMAKE_BUILD_TYPE=RelWithDebInfo"

    # BambuStudio-specific
    "-DBBL_RELEASE_TO_PUBLIC=1"
    "-DBBL_INTERNAL_TESTING=0"
    "-DDEP_WX_GTK3=ON"
    "-DSLIC3R_BUILD_TESTS=0"
    "-DCMAKE_CXX_FLAGS=-DBOOST_LOG_DYN_LINK"
  ];

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "$out/lib"

      # Fixes intermittent crash
      # The upstream setup links in glew statically
      --prefix LD_PRELOAD : "${glew-egl.out}/lib/libGLEW.so"
    )
  '';

  meta = with lib; {
    description = "Orca Slicer";
    homepage = "https://github.com/SoftFever/OrcaSlicer";
    license = licenses.agpl3;
    maintainers = with maintainers; [ ovlach ];
    mainProgram = "orca-slicer";
  };
}
