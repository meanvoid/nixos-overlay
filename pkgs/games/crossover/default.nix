{
  lib,
  fhsenv,
  unwrapped,
}:
fhsenv rec {
  inherit unwrapped;
  binName = "crossover";
  packageName = "crossover";
  desktopName = "Crossover";

  meta = with lib; {
    description = "Run your Windows® app on MacOS, Linux, or ChromeOS";
    homepage = "https://www.codeweavers.com/crossover";
    mainProgram = binName;
    license = licenses.unfreeRedistributable;
  };
}
