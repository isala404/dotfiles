# dotfiles
This contains config and dotfiles from my personal setup

# sync command
sudo nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake ~/Projects/dotfiles/nix#m1-wso2

# Update 
nix flake update --flake /Users/isala/Projects/dotfiles/nix
