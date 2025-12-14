# dotfiles

Multi-system Nix configuration for macOS and Linux machines.

## Systems

| System | Type | User | Description |
|--------|------|------|-------------|
| `m1-wso2` | Darwin | isala | M1 Office Computer (WSO2) |
| `m3-personal` | Darwin | supiri | M3 Personal Computer |

## Project Structure

```
nix/
├── flake.nix                      # Main entry point with helper functions
├── flake.lock                     # Locked versions of inputs
│
├── hosts/                         # Machine-specific configurations
│   ├── darwin/                    # macOS machines
│   │   ├── m1-wso2.nix           # M1 office config
│   │   └── m3-personal.nix       # M3 personal config
│   └── nixos/                     # Linux servers
│       └── _template.nix         # Template for new servers
│
├── home/                          # User-specific home-manager configs
│   ├── isala.nix                 # isala's home config
│   └── supiri.nix                # supiri's home config
│
└── modules/                       # Shared, reusable modules
    ├── darwin/
    │   └── common.nix            # Common macOS settings
    ├── nixos/
    │   └── common.nix            # Common Linux settings
    └── home/
        ├── common.nix            # Common home-manager (imports below)
        ├── common-linux.nix      # Linux-specific home config
        ├── starship.nix          # Starship prompt config
        ├── git.nix               # Git configuration
        └── editors.nix           # Editor configs (VSCode, Zed, etc.)
```

## Prerequisites

Install Nix with flakes enabled:
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

## Bootstrap (Fresh Install)

### macOS (Darwin)

```bash
# M1 Office Computer
nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake ~/Projects/dotfiles/nix#m1-wso2

# M3 Personal Computer
nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake ~/Projects/dotfiles/nix#m3-personal
```

### Linux (NixOS)

```bash
# After installing NixOS and cloning this repo
sudo nixos-rebuild switch --flake ~/dotfiles/nix#server-name
```

## Update Configuration

After making changes:

```bash
# macOS
darwin-rebuild switch --flake ~/Projects/dotfiles/nix#<system-name>

# Linux
sudo nixos-rebuild switch --flake ~/dotfiles/nix#<system-name>
```

## Update Flake Inputs

```bash
nix flake update --flake ~/Projects/dotfiles/nix
```

## Adding a New Machine

### New macOS Machine

1. Create host config: `nix/hosts/darwin/<hostname>.nix`
   ```nix
   { pkgs, ... }:
   {
     imports = [ ../../modules/darwin/common.nix ];

     # Machine-specific packages
     environment.systemPackages = with pkgs; [ ... ];

     # Homebrew casks
     homebrew.casks = [ ... ];

     # User shell
     users.users.<username>.shell = pkgs.fish;
     system.primaryUser = "<username>";

     system.activationScripts.extraActivation.text = ''
       softwareupdate --install-rosetta --agree-to-license
       dscl . -create /Users/<username> UserShell /run/current-system/sw/bin/fish
     '';
   }
   ```

2. Create home config: `nix/home/<username>.nix`
   ```nix
   { ... }:
   {
     imports = [ ../modules/home/common.nix ];
     programs.git = {
       userName = "Your Name";
       userEmail = "your@email.com";
     };
   }
   ```

3. Add to `flake.nix`:
   ```nix
   "<hostname>" = mkDarwinSystem {
     hostname = "<hostname>";
     user = "<username>";
     hostConfig = ./hosts/darwin/<hostname>.nix;
     homeConfig = import ./home/<username>.nix;
   };
   ```

### New Linux Server

1. Copy template: `cp nix/hosts/nixos/_template.nix nix/hosts/nixos/<hostname>.nix`
2. Customize the configuration
3. Create home config if needed
4. Add to `flake.nix` under `nixosConfigurations`

## What's Included

### Shared (All Machines)
- Fish shell with Starship prompt
- Git with useful aliases
- Nix flakes enabled
- Common dev tools: vim, ripgrep, jq, yq

### macOS Specific
- Touch ID for sudo
- Homebrew integration
- Nerd Fonts
- App aliases in /Applications

### Linux Specific
- SSH server (key-only)
- Basic firewall
- Common server tools

## Backup Before Formatting

See [BACKUP_BEFORE_FORMAT.md](./BACKUP_BEFORE_FORMAT.md) for the backup checklist.
