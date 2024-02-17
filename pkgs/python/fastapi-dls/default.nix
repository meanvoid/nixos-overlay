{
  lib,
  stdenv,
  callPackage,
  python3,
  python3Packages,
  fetchFromGitea,
  nixosTests,
  openssl,
  dbBackend ? "sqlite",
  libmysqlclient,
  postgresql,
  writeText,
  makeWrapper,
}: let
  setupPy = writeText "setup.py" ''
    from setuptools import setup, find_packages

    setup(
      name='fastapi-dls',
      version='1.4.0',
      author='Oscar Krause',
      description='Unofficial NLS compatible server written in Python',
      packages=['app'],
      # scripts=[
      #   'app/main.py',
      #   'app/orm.py',
      #   'app/util.py'
      # ],  # Assuming your Python modules are inside the 'app' directory
    )
  '';
in
  python3Packages.buildPythonPackage rec {
    pname = "fastapi-dls";
    version = "1.4.0";
    format = "setuptools";

    src = fetchFromGitea {
      domain = "gitea.publichub.eu";
      owner = "oscar.krause";
      repo = "fastapi-dls";
      rev = "213e768708";
      hash = "sha256-R16oDVMF3ZQyMLr5eRkzpa4w9lRaWEUUu49uCncUN98=";
    };

    # buildInputs = with lib;
    #   [openssl]
    #   ++ optional (dbBackend == "mysql") libmysqlclient
    #   ++ optional (dbBackend == "postgresql") postgresql;
    # buildFeatures = dbBackend;
    nativeBuildInputs = [
      makeWrapper
    ];

    propagatedBuildInputs = with python3Packages; [
      fastapi
      uvicorn
      python-jose
      pycryptodome
      python-dateutil
      sqlalchemy
      markdown
      python-dotenv
    ];

    dontWrapPythonPrograms = true;
    doCheck = false;

    postPatch = ''
      # copy seetupPy
      cp ${setupPy} ${setupPy.name}
    '';

    postInstall = ''
      makeWrapper ${python3Packages.uvicorn}/bin/uvicorn $out/bin/fastapi-dls \
        --set PYTHONPATH ${python3Packages.makePythonPath (propagatedBuildInputs ++ [(placeholder "out")])} \
        --set INSTANCE_KEY_RSA /opt/docker/fastapi-dls/cert/instance.private.pem \
        --set INSTANCE_KEY_PUB /opt/docker/fastapi-dls/cert/instance.public.pem \
        --add-flags "--app-dir $out/${python3Packages.python.sitePackages}/app --ssl-certfile /opt/docker/fastapi-dls/cert/webserver.crt --ssl-keyfile /opt/docker/fastapi-dls/cert/webserver.key main:app"
    '';

    meta = with lib; {
      description = "Unofficial NLS compatible server written in Python";
      homepage = "https://gitea.publichub.eu/oscar.krause/fastapi-dls";
      changelog = "https://gitea.publichub.eu/oscar.krause/fastapi-dls/commit/${version}";
      license = licenses.agpl3Only;
      maintainers = with maintainers; [ashuramaruzxc];
      mainProgram = "fastapi-dls";
    };
  }
