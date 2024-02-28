{
  stdenv,
  lib,
  git,
  fetchFromGitHub,
  wrapGAppsHook4,
  meson,
  ninja,
  pkg-config,
  glib,
  glib-networking,
  desktop-file-utils,
  gettext,
  librsvg,
  blueprint-compiler,
  python3Packages,
  sassc,
  appstream-glib,
  libadwaita,
  libportal,
  libportal-gtk4,
  libsoup_3,
  gobject-introspection,
}:
python3Packages.buildPythonApplication rec {
  pname = "gradience";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "GradienceTeam";
    repo = "Gradience";
    # See https://github.com/GradienceTeam/Gradience/releases/tag/0.4.1-patch1
    rev = "8b82f13fd50648d6dbe62caff53e4bef900e8645";
    sha256 = "sha256-a6sL41Cp6sG3BmxUNkNqlypJwgdWPD8FywJhlihyA0k=";

    fetchSubmodules = true;
  };

  format = "other";
  dontWrapGApps = true;

  nativeBuildInputs = [
    git
    appstream-glib
    blueprint-compiler
    desktop-file-utils
    gettext
    glib
    gobject-introspection
    meson
    ninja
    pkg-config
    wrapGAppsHook4
    sassc
  ];

  buildInputs = [
    glib-networking
    libadwaita
    libportal
    libportal-gtk4
    librsvg
    libsoup_3
  ];

  propagatedBuildInputs = with python3Packages; [
    libsass
    anyascii
    jinja2
    lxml
    material-color-utilities
    pygobject3
    svglib
    yapsy
  ];

  preFixup = ''

    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  meta = with lib; {
    homepage = "https://github.com/GradienceTeam/Gradience";
    description = "Customize libadwaita and GTK3 apps (with adw-gtk3)";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [foo-dogsquared];
  };
}
