{
  lib,
  pkgs,
  python3Packages,
  fetchFromGitHub,
  writeText,
  bash,
  ...
}:
with python3Packages; let
  setupPy = writeText "setup.py" ''
    from setuptools import setup, find_packages

    setup(
      name='vgpu_unlock',
      version='1.0.0',
      description='vGPU unlock script for consumer GPUs',
      author='Krutav Shah',
      packages=find_packages(),
      scripts=[
        'vgpu_unlock',
        'scripts/vgpu-name.sh'
      ],
      install_requires=['frida'],
      classifiers=[
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
      ],
    )
  '';
in
  buildPythonPackage rec {
    pname = "vgpu-unlock";
    version = "f432ffc";
    format = "setuptools";

    src = fetchFromGitHub {
      owner = "DualCoder";
      repo = "vgpu_unlock";
      rev = "f432ffc8b7ed245df8858e9b38000d3b8f0352f4";
      sha256 = "sha256-o+8j82Ts8/tEREqpNbA5W329JXnwxfPNJoneNE8qcsU=";
    };

    # Disable running checks during the build
    doCheck = false;

    nativeBuildInputs = [setuptools];
    propagatedBuildInputs = [frida-python];

    postPatch = ''
      # copy seetupPy
      for i in vgpu_unlock scripts/vgpu-name.sh; do
        substituteInPlace $i \
          --replace /bin/bash ${bash}/bin/bash
      done
      cp ${setupPy} ${setupPy.name}
    '';
  }
