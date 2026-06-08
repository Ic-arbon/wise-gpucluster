{
  description = "Shared ML environment: ANN + Bayesian Optimization (PyTorch + CUDA)";

  # ── Binary cache (国内加速) ────────────────────────────────────────────────
  # 顺序：USTC 镜像(普通包) → cuda-maintainers(CUDA 包) → 官方(兜底)。
  # 注意：USTC 是 cache.nixos.org 的镜像，签名仍是 nixos 的 key，故无需额外 key。
  # 生效前提：用户的 ~/.config/nix/nix.conf 或 /etc/nix/nix.conf 需把这些 URL
  #   列入 trusted-substituters（或将用户加入 trusted-users），否则 Nix 会忽略
  #   flake 自带的 substituters 并仅用系统默认值。
  nixConfig = {
    substituters = [
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://cuda-maintainers.cachix.org"
      "https://cache.nixos.org/"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            # Host driver (CUDA 13.2) supplies libcuda.so at runtime.
            # Nix supplies the CUDA 12.x toolkit; driver is backward-compatible.
            cudaSupport = true;
          };
          overlays = [ (import ./overlays/botorch.nix) ];
        };

        mlPython = pkgs.python3.withPackages (ps: with ps; [
          torch
          torchvision
          scikit-learn
          optuna
          tensorboard
          hyperopt
          gpytorch
          botorch
        ]);

      in {
        # ── System-wide package ───────────────────────────────────────────────
        # Deploy to all users (multi-user daemon, non-NixOS):
        #   sudo nix profile install --profile /nix/var/nix/profiles/ml-env \
        #     github:YOUR_ORG/gpu-cluster#default
        # Then add to /etc/profile.d/ml-env.sh:
        #   export PATH="/nix/var/nix/profiles/ml-env/bin:$PATH"
        packages.default = mlPython;

        # ── Dev shell (the-nix-way style) ─────────────────────────────────────
        devShells.default = pkgs.mkShell {
          name = "ml-env";
          packages = [
            mlPython
            pkgs.uv
            pkgs.git
            pkgs.stdenv.cc.cc.lib
          ];

          shellHook = ''
            echo "──────────────────────────────────────────"
            echo " ML environment (CUDA $(python -c 'import torch; print(torch.version.cuda)'))"
            python -c "import torch;    print(' torch      ', torch.__version__)"
            python -c "import sklearn;  print(' sklearn    ', sklearn.__version__)"
            python -c "import optuna;   print(' optuna     ', optuna.__version__)"
            python -c "import hyperopt; print(' hyperopt   ok')"
            python -c "import gpytorch; print(' gpytorch   ', gpytorch.__version__)"
            python -c "import botorch;  print(' botorch    ', botorch.__version__)"
            echo "──────────────────────────────────────────"
          '';
        };
      }
    );
}
