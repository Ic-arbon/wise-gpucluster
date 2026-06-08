# Overlay: ensure botorch is available and silence hyperopt deprecation warnings.
#
# To update the botorch fallback version:
#   nix-prefetch-url --unpack https://files.pythonhosted.org/packages/source/b/botorch/botorch-X.Y.Z.tar.gz
# Paste the resulting hash into `fallbackHash` below.

final: prev:
let
  fallbackVersion = "0.12.0";
  fallbackHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

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

    doCheck = false;

    pythonImportsCheck = [ "botorch" ];
  };

in {
  python312 = prev.python312.override {
    packageOverrides = pyFinal: pyPrev:
      {
        # Replace pkg_resources usage in hyperopt/atpe.py with importlib.resources
        # to eliminate the setuptools deprecation warning on Python 3.12+.
        hyperopt = pyPrev.hyperopt.overridePythonAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace hyperopt/atpe.py \
              --replace-fail 'import pkg_resources' \
                             'import importlib.resources' \
              --replace-fail \
                "pkg_resources.resource_string(__name__, 'atpe_params.json')" \
                "importlib.resources.files('hyperopt').joinpath('atpe_params.json').read_bytes()"
          '';
        });
      }
      // (if pyPrev ? botorch then { } else { botorch = botorchFallback; });
  };

  python312Packages = final.python312.pkgs;
}
