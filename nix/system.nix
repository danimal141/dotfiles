{ user, ... }:

{
  # nix-darwin の primary user (system.defaults / GUI 設定の適用先)
  system.primaryUser = user;

  # macOS システム設定 (アプリ単位の defaults は除く)
  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
      tilesize = 48;
    };

    finder = {
      AppleShowAllFiles = true;
      FXEnableExtensionChangeWarning = false;
      ShowPathbar = true;
    };

    NSGlobalDomain = {
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      ApplePressAndHoldEnabled = false;
      AppleShowAllExtensions = true;
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };
  };

  # zsh の rc は chezmoi 管理に集約。nix-darwin が /etc/zshrc を上書きしない
  programs.zsh.enable = false;

  # brew 経由で language runtime を入れるのを禁止 (mise / asdf 側に集約)
  environment.variables = {
    HOMEBREW_FORBIDDEN_FORMULAE = "node python python3 pip npm pnpm yarn claude";
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "@admin" user ];
    };

    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  # nix-darwin state version (changing this requires manual migration)
  system.stateVersion = 6;
}
