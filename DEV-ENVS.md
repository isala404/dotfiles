# Dev Environments

Per-project dev environments using nix flakes + direnv. Tools activate automatically when you `cd` into a project and deactivate when you leave.

## Quick Start

1. Copy a template into your project:
```bash
cp ~/Projects/dotfiles/templates/python/flake.nix ./
cp ~/Projects/dotfiles/templates/python/.envrc ./
```

2. Allow direnv:
```bash
direnv allow
```

That's it. The environment activates on `cd`.

## Available Templates

| Template | What you get |
|----------|-------------|
| `templates/python/` | python 3.14, uv |
| `templates/rust/` | stable rust + rust-analyzer, cargo-watch, cargo-edit |
| `templates/go/` | go, gopls, golangci-lint, delve |
| `templates/node/` | node 24, bun, prettier, ts-language-server |
| `templates/terraform/` | terraform, terraform-ls, tflint |

## Customizing

Edit the `flake.nix` in your project. Add packages to the `packages` list:

```nix
packages = with pkgs; [
  python314
  uv
  postgresql  # add whatever you need
  redis
];
```

Then reload:
```bash
direnv reload
```

## Adding Environment Variables

```nix
default = pkgs.mkShell {
  packages = with pkgs; [ python314 uv ];

  env = {
    DATABASE_URL = "postgres://localhost/mydb";
  };

  shellHook = ''
    echo "Python $(python --version) ready"
  '';
};
```

## Combining Languages

Just add packages from multiple ecosystems:

```nix
packages = with pkgs; [
  python314
  uv
  nodejs_24
  bun
  postgresql
];
```

## Pinning nixpkgs

Lock to a specific nixpkgs commit for reproducibility:

```nix
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
# or pin to a specific commit:
# inputs.nixpkgs.url = "github:NixOS/nixpkgs/abc123...";
```

Run `nix flake update` to bump the lock file.

## Rust with Extra Targets

The rust template uses `rust-overlay` for flexible toolchain control:

```nix
(rust-bin.stable.latest.default.override {
  extensions = [ "rust-src" "rust-analyzer" ];
  targets = [ "wasm32-unknown-unknown" "aarch64-linux-android" ];
})
```

## How It Works

- `flake.nix` declares the tools your project needs
- `flake.lock` pins exact versions (commit to git for reproducibility)
- `.envrc` tells direnv to use the flake
- `nix-direnv` caches the environment so it's fast after first build
- Add `flake.nix`, `flake.lock`, and `.envrc` to git

## Tips

- First `direnv allow` takes a minute (building the env). After that it's instant.
- Run `direnv reload` after changing `flake.nix`.
- Run `nix flake update` to bump all dependencies.
- Add `.direnv/` to `.gitignore` (it's the local cache).
- Search packages at https://search.nixos.org/packages
