# Shared Starship prompt configuration
{ ... }:
{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      scan_timeout = 50;
      command_timeout = 1000;

      format = "$username$hostname$nix_shell$direnv$directory$git_branch$git_status$package$nodejs$bun$python$golang$rust$java$cmd_duration$fill$kubernetes$terraform$docker_context$helm$aws$jobs$time$line_break$status$character";

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold green)";
      };

      fill.symbol = " ";

      directory = {
        style = "bold cyan";
        truncation_length = 3;
        truncate_to_repo = true;
        truncation_symbol = "…/";
        home_symbol = "~";
        read_only = "";
        read_only_style = "red";
        fish_style_pwd_dir_length = 1;
        format = "[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        symbol = " ";
        truncation_length = 24;
        style = "bold purple";
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        style = "bold yellow";
        format = "([$staged$modified$untracked$stashed$conflicted$ahead_behind]($style)) ";
        conflicted = "!$count";
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇕⇡$ahead_count⇣$behind_count";
        untracked = "?$count";
        stashed = "≡$count";
        modified = "~$count";
        staged = "+$count";
      };

      cmd_duration = {
        min_time = 2000;
        show_milliseconds = false;
        style = "yellow";
        format = "[⏱ $duration]($style) ";
      };

      kubernetes = {
        disabled = false;
        symbol = "⎈ ";
        style = "bold cyan";
        format = "[$symbol$context( \($namespace\))]($style) ";
      };

      aws = {
        symbol = " ";
        style = "yellow";
        format = "[$symbol($profile)(@$region)]($style) ";
        region_aliases = {
          "us-east-1" = "ue1";
          "us-west-2" = "uw2";
          "eu-west-1" = "euw1";
          "ap-southeast-1" = "apse1";
        };
      };

      terraform = {
        symbol = "󱁢 ";
        format = "[$symbol$workspace]($style) ";
        style = "bold purple";
      };

      docker_context = {
        symbol = "🐳 ";
        format = "[$symbol$context]($style) ";
        style = "blue";
      };

      helm = {
        symbol = "⎈ ";
        format = "[$symbol$version]($style) ";
        style = "cyan";
      };

      nix_shell = {
        symbol = " ";
        format = "[$symbol$state( $name)]($style) ";
        style = "bold blue";
      };

      direnv = {
        disabled = false;
        symbol = "direnv ";
        style = "bold green";
        format = "[$symbol]($style) ";
      };

      package = {
        disabled = false;
        symbol = "📦 ";
        display_private = true;
        format = "[$symbol$version]($style) ";
      };

      nodejs = {
        disabled = false;
        symbol = " ";
        format = "[$symbol$version]($style) ";
        style = "bold green";
      };

      bun = {
        disabled = false;
        symbol = "🍞 ";
        format = "[$symbol$version]($style) ";
        style = "bold yellow";
      };

      python = {
        disabled = false;
        symbol = " ";
        pyenv_version_name = true;
        format = "[$symbol$version( \($virtualenv\))]($style) ";
        style = "bold blue";
      };

      golang = {
        disabled = false;
        symbol = " ";
        format = "[$symbol$version]($style) ";
        style = "bold cyan";
      };

      rust = {
        disabled = false;
        symbol = "🦀 ";
        format = "[$symbol$version]($style) ";
        style = "bold red";
      };

      java = {
        disabled = false;
        symbol = " ";
        format = "[$symbol$version]($style) ";
        style = "bold yellow";
      };

      container = {
        symbol = "⬢ ";
        style = "bold red";
        format = "[$symbol$name]($style) ";
      };

      azure = {
        disabled = true;
        symbol = "az ";
        style = "blue";
        format = "[$symbol$subscription]($style) ";
      };

      shlvl = {
        disabled = false;
        format = "[$symbol$shlvl]($style) ";
        repeat = false;
        symbol = "↕ ";
        threshold = 2;
        style = "dimmed purple";
      };

      username = {
        show_always = false;
        style_root = "bold red";
        style_user = "bold dimmed blue";
        format = "[$user]($style) ";
      };

      hostname = {
        ssh_only = true;
        trim_at = ".";
        style = "bold dimmed purple";
        format = "[@$hostname]($style) ";
      };

      os = {
        disabled = false;
        format = "[$symbol]($style) ";
        style = "bold white";
        symbols = {
          Macos = " ";
          Ubuntu = " ";
          NixOS = " ";
        };
      };

      status = {
        disabled = false;
        style = "bold red";
        format = "[$symbol$status]($style) ";
        map_symbol = true;
        symbol = "✘ ";
      };

      jobs = {
        symbol = "⚙ ";
        style = "bold cyan";
        format = "[$symbol$number]($style) ";
      };

      memory_usage = {
        disabled = false;
        symbol = "󰍛 ";
        threshold = 70;
        style = "bold dimmed green";
        format = "[$symbol$ram_pct]($style) ";
      };

      battery = {
        full_symbol = " ";
        charging_symbol = " ";
        discharging_symbol = " ";
        format = "[$symbol$percentage]($style) ";
        display = [
          { threshold = 20; style = "bold red"; }
          { threshold = 40; style = "bold yellow"; }
        ];
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "dimmed white";
        format = "[$time]($style) ";
      };
    };
  };
}
