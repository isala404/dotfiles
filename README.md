# dotfiles
This contains config and dotfiles from my personal setup

# sync command
nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake ~/Projects/dotfiles/nix#m1-wso2
