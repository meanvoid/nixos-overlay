{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  unzip,
}: let
  # dimensions = {
  #   palette = [ "Frappe" "Latte" "Macchiato" "Mocha" ];
  #   color = [ "Blue" "Dark" "Flamingo" "Green" "Lavender" "Light" "Maroon" "Mauve" "Peach" "Pink" "Red" "Rosewater" "Sapphire" "Sky" "Teal" "Yellow" ];
  # };
  # product = lib.attrsets.cartesianProductOfSets dimensions;
  # variantName = { palette, color }: (lib.strings.toLower palette) + color;
  # variants = map variantName product;
  # Credit: https://github.com/NixOS/nixpkgs/blob/master/pkgs/data/icons/catppuccin-cursors/default.nix
  dimensions = {
    variant = [
      "Aya"
      "Flandre"
      "Junko"
      "Kaguya"
      "Koishi"
      "Marisa"
      "Mokou"
      "Patchouli"
      "Reimu"
      "Reisen"
      "Remilia"
      "Rumia"
      "Sanae"
      "Suwako"
      "Tewi"
      "Utsuho"
      "Youmu"
    ];
  };
  product = lib.attrsets.cartesianProductOfSets dimensions;
  variantName = {variant}: (lib.strings.toLower variant);
  variants = map variantName product;
in
  stdenvNoCC.mkDerivation rec {
    pname = "anime-cursors";
    version = "c605694";
    dontBuild = true;

    src = fetchFromGitHub {
      owner = "ashuramaruzxc";
      repo = "anime-cursors";
      rev = "${version}";
      sha256 = "sha256-7iXjc3SqIZFXpj0jkoiNHHxYz5GHKnzAajh/ga2paD8=";
      sparseCheckout = ["cursors"];
    };

    nativeBuildInputs = [unzip];

    outputs = variants ++ ["out"];

    outputsToInstall = [];

    installPhase = ''
      runHook preInstall

      for output in $(getAllOutputNames); do
        if [ "$output" != "out" ]; then
          local outputDir="''${!output}"
          local iconsDir="$outputDir"/share/icons

          mkdir -p "$iconsDir"

          # Convert to kebab case with the first letter of each word capitalized
          local variant=$(sed 's/\([A-Z]\)/-\1/g' <<< "$output")
          local variant=''${variant^}
          unzip "cursors/$variant.zip" -d "$iconsDir"
        fi
      done

      # Needed to prevent breakage
      mkdir -p "$out"

      runHook postInstall
    '';
  }
