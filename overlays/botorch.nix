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
        # Silence the pkg_resources deprecation warning in hyperopt/atpe.py.
        # We only patch the import line; resource_string itself is left intact
        # because the call site varies across patch releases.
        hyperopt = pyPrev.hyperopt.overridePythonAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace hyperopt/atpe.py \
              --replace-fail 'import pkg_resources' \
                'import warnings as _w; _w.filterwarnings("ignore", message="pkg_resources is deprecated", category=UserWarning); import pkg_resources'
          '';
        });
      }
      // (if pyPrev ? botorch then { } else { botorch = botorchFallback; });
  };

  python312Packages = final.python312.pkgs;
}
