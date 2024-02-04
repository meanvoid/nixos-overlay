{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  bash,
  subversion,
  coreutils,
  gnused,
  procps,
  curl,
  which,
  gitMinimal,
  pkgs,
}:
stdenv.mkDerivation {
  pname = "thcrap-proton";
  version = "47792a3";

  src = fetchFromGitHub {
    owner = "tactikauan";
    repo = "thcrap-steam-proton-wrapper";
    rev = "47792a3d7fc8c28c409ebcb04d11562979cd6ce0";
    sha256 = "sha256-qxjHiQrsKQdNQ9eXE7fZ5C738Ae4dG6M1yZc3J38fTU=";
  };
  buildInputs = [
    bash
    subversion
  ];
  nativeBuildInputs = [
    makeWrapper
  ];
  installPhase = ''
    mkdir -p $out/bin
    cp thcrap_proton $out/bin/thcrap_proton
  '';
  postFixup = ''
    wrapProgram $out/bin/thcrap_proton \
        --prefix PATH : ${lib.makeBinPath [
      bash
      subversion
      pkgs.gnome.zenity
    ]}
  '';
}
