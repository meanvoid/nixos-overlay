{
  stdenv,
  lib, 
  git,
  fetchgit,
  coreutils,
  bash,
  subversion,
  makeWrapper,
  openssl
}:
stdenv.mkDerivation {
  name = "thcrap-wrapper";

  src = fetchgit {
    url = "https://github.com/tactikauan/thcrap-steam-proton-wrapper.git";
    rev = "519e82ca48709cfa71b02bb24c33647307f8eb50";
    sha256 = "0g4w5qb4ggn1q1rn2d2y6blhfnnhlci9d2v9j72123vga0z2hnnn";
  };
  
  nativeBuildInputs = [makeWrapper];
  buildInputs = [bash subversion];
  installPhase = ''
    mkdir -p $out/bin
    cp thcrap_proton $out/bin/thcrap_proton
    wrapProgram $out/bin/thcrap_proton --prefix PATH : ${lib.makeBinPath [bash subversion]}
  '';
}
