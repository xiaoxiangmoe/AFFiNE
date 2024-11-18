# nix usage

## dev

dev shell:

```shell
nix develop .
```

dev shell in empty environment:

```shell
nix develop --ignore-environment .
```

## build

build affine-desktop:

```shell
nix build --print-build-logs .#affine
# in macOS
open result/Applications/AFFiNE-canary.app
```

debug build affine-desktop:

```shell
nix build --keep-failed --debug --print-build-logs .#affine
```
