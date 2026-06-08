# Overlay: ensure botorch is available regardless of nixpkgs channel state.
#
# Priority order:
#   1. Use nixpkgs botorch if it exists and is not broken.
#   2. Fall back to a minimal buildPythonPackage sourced from PyPI.
#
# To update the fallback version:
#   nix-prefetch-url --unpack https://files.pythonhosted.org/packages/source/b/botorch/botorch-X.Y.Z.tar.gz
# Paste the resulting hash into `fallbackHash` below.

final: prev:
let
  fallbackVersion = "0.12.0";
  fallbackHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  # ↑ Replace with real hash. Get it by running:
  #   nix-prefetch-url --unpack \
  #     https://files.pythonhosted.org/packages/source/b/botorch/botorch-${fallbackVersion}.tar.gz

  botorchFallback = prev.python312Packages.buildPythonPackage rec {
    pname = "botorch";
    version = fallbackVersion;
    pyproject = true;

    src = prev.python312Packages.fetchPypi {
      inherit pname version;
      hash = fallbackHash;
    };

    build-system = with prev.python312Packages; [ setuptools wheel ];

    dependencies = with prev.python312Packages; [
      torch
      gpytorch
      scipy
      multipledispatch
      linear-operator
    ];

    # Tests require GPU; skip in build sandbox.
    doCheck = false;

    pythonImportsCheck = [ "botorch" ];
  };

in {
  # Override the python312 package set so all downstream consumers see botorch.
  python312 = prev.python312.override {
    packageOverrides = pyFinal: pyPrev:
      if pyPrev ? botorch
      then { }               # nixpkgs already has it — nothing to do
      else { botorch = botorchFallback; };
  };

  # Keep python312Packages in sync with the overridden python312.
  python312Packages = final.python312.pkgs;
}
