# GPU Cluster ML Environment

Nix flake — reproducible ML environment for ANN + Bayesian Optimization.

**Packages**: PyTorch (CUDA), scikit-learn, Optuna, TensorBoard, Hyperopt, GPyTorch, BoTorch.

---

## 设计原则

- `/nix/store` 全局共享，同一个闭包只构建一次，所有用户引用相同路径，零额外磁盘
- 用户用 `nix shell` / `nix develop` 按需进入隔离环境，退出后系统 PATH 完全恢复
- 没有全局 PATH 修改，没有 `/etc/profile.d`，没有环境污染

---

## 管理员（一次性配置）

### 1. 安装 Nix

需要支持 flakes 的 Nix。推荐用 [Determinate Systems 安装器](https://github.com/DeterminateSystems/nix-installer)，它默认开启 flakes，且卸载干净：

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

装完后**重开一个终端**，验证：

```sh
nix --version
```

> 如果你用的是官方安装器，需要手动开启 flakes，在 `~/.config/nix/nix.conf` 写入：
> ```
> experimental-features = nix-command flakes
> ```


### 2. 启用 flakes 和 CUDA 二进制缓存

`/etc/nix/nix.conf`：

```
experimental-features = nix-flakes nix-command
substituters = https://cache.nixos.org https://cuda-maintainers.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=
```

重启 daemon：`sudo systemctl restart nix-daemon`

无需其他操作。第一个用户运行时 Nix 自动构建并缓存到 `/nix/store`，后续用户直接命中缓存。

---

## 用户使用

### 临时环境（推荐）

```bash
# 进入 ML shell，退出后环境完全消失
nix shell github:Ic-arbon/wise-gpucluster
```

### 开发 shell（含 uv、git 等工具）

```bash
nix develop github:Ic-arbon/wise-gpucluster
```

### 验证

```bash
python -c "import torch, botorch, gpytorch; print(torch.__version__, torch.cuda.is_available())"
```

---

## NixOS

```nix
# flake.nix inputs:
inputs.ml-env.url = "github:Ic-arbon/wise-gpucluster";

# configuration.nix — 按需选择：
# 全局暴露（适合所有用户都是 ML 用户的机器）：
environment.systemPackages = [ inputs.ml-env.packages.${pkgs.system}.default ];

# 或者只给特定用户：
users.users.alice.packages = [ inputs.ml-env.packages.${pkgs.system}.default ];
```

---

## BoTorch overlay

`overlays/botorch.nix` 保证 BoTorch 始终可用：

- nixpkgs 已有 `botorch` → overlay 是 no-op
- nixpkgs 没有 → overlay 从 PyPI 构建

若 fallback 构建因 hash 过期失败，更新方式：

```bash
nix-prefetch-url --unpack \
  https://files.pythonhosted.org/packages/source/b/botorch/botorch-0.12.0.tar.gz
# 将输出的 hash 填入 overlays/botorch.nix → fallbackHash
```

---

## uv venv（最后手段）

若需要 Nix 无法提供的特定版本：

```bash
# 在 nix develop 环境内执行，不影响系统
uv venv .venv
source .venv/bin/activate
uv pip install botorch gpytorch --extra-index-url https://download.pytorch.org/whl/cu124
```
