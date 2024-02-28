{
  lib,
  stdenv,
  fetchzip,
  unzip,
}:
stdenv.mkDerivation {
  name = "gradience-devel";
  src = fetchzip {
    url = "https://nightly.link/GradienceTeam/Gradience/workflows/build/main/gradience-devel-x86_64.zip";
    hash = "sha256-b4jSlokuibEhcEhwOoY/GNJMo+5FfdqchjyO+gt3Pwk=";
  };
  outputs = ["out"];
  dontBuild = true;

  NativeBuildInputs = [unzip];

  installPhase = ''
    mkdir -p $out
  '';
  meta = with lib; {
    homepage = "https://github.com/GradienceTeam/Gradience";
    description = "Customize libadwaita and GTK3 apps (with adw-gtk3)";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ashuramaruzxc];
  };
}
