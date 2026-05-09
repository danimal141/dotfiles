{ user, lib, ... }:

# macOS システム設定 + Nix / nix-darwin 自体の運用 (flake / gc / 環境変数 /
# zsh の取扱い) を宣言するモジュール。
#
# `system.defaults.*` の設計方針:
#   * 「declarative に固定したい設定」をすべて宣言する。
#     宣言した key は `darwin-rebuild switch` のたびに値が固定されるので、
#     System Settings から手動で変えても次の switch で巻き戻る。
#   * 値の変更が頻繁な「Dock の persistent-apps」などは宣言しない
#     (= macOS のデフォルトに任せて mutable のまま運用)。
#
# 一部の設定 (Dock 系 / Finder 系) は反映に再起動が必要:
#   killall Dock      # Dock 系
#   killall Finder    # Finder 系
#   killall SystemUIServer   # menubar / screencapture 系
# `KeyRepeat` / `InitialKeyRepeat` は再ログインが必要。
#
# アプリ単体の defaults (1Password / Raycast / Karabiner 等) はスコープ外。
# 必要になったら `system.defaults.CustomUserPreferences` か手動
# `defaults write` で対応する。
{
  # `system.defaults` / nix-homebrew が「誰の defaults を書くか」を決めるための
  # primary user 宣言。multi-user 環境ではないので flake から渡された user で固定。
  system.primaryUser = user;

  # nix-darwin に user 本体を宣言する。home-manager の darwin module は
  # `users.users.<name>.home` から home directory を引くため、これ無しだと
  # home.homeDirectory が null として merge され「is not of type absolute path」
  # で activation が落ちる。home-manager 統合の前提条件。
  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
  };

  system.defaults = {
    # ============================================================
    # Dock — タスクバー / 起動済み app の表示
    # ============================================================
    dock = {
      # マウスホバーで Dock が現れる auto-hide 動作。フルスクリーン作業領域を
      # 最大化したいので有効。
      autohide = true;

      # Dock の表示位置。default も "bottom" だが、別マシンで誤って左右に
      # 動かしてしまった場合に switch で戻すために defensive に明示する。
      orientation = "bottom";

      # icon サイズ (px)。tilesize は通常状態のサイズ、largesize は
      # magnification 時の拡大サイズ。default は tilesize=48 / largesize=64。
      # tilesize と largesize を同値にすると hover で拡大しない (= 視覚効果
      # は magnification=true のままで size 変化のみ抑える) ことになる。
      tilesize = 48;
      largesize = 48;

      # マウスホバーで icon を拡大表示する。視認性向上のため有効。
      magnification = true;

      # Spaces (デスクトップ) を「最近使った順」に並べ替えない。
      # Mission Control 内で Space の位置が勝手に動くと muscle memory が壊れる
      # ため、宣言で固定する。
      mru-spaces = false;

      # Dock の右側に「最近使った app」エリアを出さない。
      # 永続的に追加した app だけを Dock に並べたい運用。
      show-recents = false;

      # Hot corners: 4 隅をマウスで指したときの動作。値の意味:
      #   1  = no action               2  = Mission Control
      #   3  = Application Windows     4  = Desktop
      #   5  = Start Screen Saver      6  = Disable Screen Saver
      #   7  = Dashboard               10 = Put Display to Sleep
      #   11 = Launchpad               12 = Notification Center
      #   13 = Lock Screen             14 = Quick Note
      # 右下のみ Quick Note (Monterey+)、その他は誤動作防止のため無効化。
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 14;
    };

    # ============================================================
    # Finder — ファイル管理
    # ============================================================
    finder = {
      # ファイル拡張子を常に表示する (.txt / .md / .png 等)。default は隠す。
      # 拡張子を見ないと「foo.pdf」と「foo.pdf.exe」のような偽装に気付けないので
      # 安全のため表示。
      AppleShowAllExtensions = true;

      # 新規 Finder window のデフォルト表示形式: column view。値:
      #   "icnv" = Icon / "Nlsv" = List / "clmv" = Column / "Flwv" = Gallery
      # column view は path 階層が一目で見えて作業しやすい。
      FXPreferredViewStyle = "clmv";

      # ファイル名検索のデフォルトスコープ。値:
      #   "SCcf" = Search current folder
      #   "SCev" = Search the previous scope
      #   "SCsp" = Search This Mac (default)
      # default の "This Mac" は意図せず全 disk を grep するので重い。
      # 「現在のフォルダから検索」に変更。
      FXDefaultSearchScope = "SCcf";

      # Finder の sort で directory を file より先に並べる。
      # 直感的なファイラー挙動 (Windows / Linux 系の典型) に揃える。
      _FXSortFoldersFirst = true;

      # Finder window の title bar に full POSIX path を表示。
      # `cd` でターミナルに渡すときに簡単。
      _FXShowPosixPathInTitle = true;

      # Path bar (window 下部の現在地階層表示) と Status bar (選択ファイルの
      # サイズ / 個数表示) を常時表示。
      ShowPathbar = true;
      ShowStatusBar = true;

      # デスクトップに表示する drive 種別:
      #   外付け HDD / リムーバブルメディア (USB / SD card 等) は表示
      #   内蔵 HDD は表示しない (= デスクトップを散らかさない、迷わない)
      #   network mount も非表示 (auto mount で勝手に出るのを防ぐ)
      ShowExternalHardDrivesOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowMountedServersOnDesktop = false;
    };

    # ============================================================
    # NSGlobalDomain (= Apple Global Domain) — システム全体 default
    # ============================================================
    # nix-darwin が typed option として持っているものだけここに書く。
    # typed でない key (AppleLanguages / AppleLocale など) は下の
    # CustomUserPreferences."NSGlobalDomain" に書く。
    NSGlobalDomain = {
      # キーボード入力速度 (developer 標準セット):
      #   KeyRepeat: リピート中の連打速度。値が小さいほど速い (default 6)
      #   InitialKeyRepeat: 押下から連打開始までの遅延。小さいほど短い (default 25)
      # 2 / 15 はターミナル / vim 操作で詰まらない最速設定。
      KeyRepeat = 2;
      InitialKeyRepeat = 15;

      # 長押しで「文字バリエーション menu (é è ê ë...)」を出さない。
      # vim ユーザー定番: `hjkl` 長押しが menu でなく key repeat になる。
      ApplePressAndHoldEnabled = false;

      # Tab キーで全 UI controls (text / list / checkbox / button) に focus 可能に。
      # default は 0 (text と list のみ)。3 にして全要素を keyboard で操作可能に。
      AppleKeyboardUIMode = 3;

      # 自動補完系を全 OFF。code / markdown 編集で、
      #   - 'foo' が curly quote (‘foo’) に化ける
      #   - ピリオド 2 つで「. 」(narrow no-break space) になる
      #   - 行頭が勝手に大文字化される
      #   - ハイフン 2 つが en-dash になる
      # などの想定外の置換を防ぐ。code review 時に diff が荒れる原因 #1。
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
    };

    # ============================================================
    # CustomUserPreferences — typed module で扱えない key の自由記述
    # ============================================================
    # nix-darwin の typed option リストにない key は domain ごとに attrset
    # で書く。format は `defaults write <domain> <key> <type> <value>` と
    # ほぼ 1:1 対応。
    CustomUserPreferences = {
      # 言語優先順位 (japanese first、english fallback)。
      # アプリが対応していれば日本語で出る、無ければ英語で出る。
      "NSGlobalDomain" = {
        AppleLanguages = [ "ja-JP" "en-JP" ];
        AppleLocale = "ja_JP";

        # title bar の double-click で window を最小化させない。
        # default は最小化するが、誤って画面から消える挙動が紛らわしいため。
        # 0 = NO (no minimize), 1 = YES (default)
        AppleMiniaturizeOnDoubleClick = 0;
      };

      # 日本語 IM (Kotoeri / 「ことえり」) の挙動。
      # JIMPrefLiveConversionKey: ライブ変換 (入力中の自動漢字変換) を無効化。
      # 入力途中で勝手に候補が確定して visual に飛ぶのが煩わしいため OFF。
      # 1 = ON (default), 0 = OFF
      # JIMPrefConvertWithPunctuationKey: 句読点入力時の自動変換を無効化。
      # 「、」「。」を打った瞬間に変換が走るのを止め、明示的に space で
      # 変換するスタイルに揃える。
      "com.apple.inputmethod.Kotoeri" = {
        JIMPrefLiveConversionKey = 0;
        JIMPrefConvertWithPunctuationKey = 0;
      };
    };

    # ============================================================
    # Trackpad — タッチパッドジェスチャ
    # ============================================================
    trackpad = {
      # タップ→クリックを無効化 (誤クリック防止、物理 click のみ受け付ける)。
      # ノート PC を膝に乗せた時などに勝手に発動するのを防ぐ。
      Clicking = false;

      # 三本指ドラッグを無効化。誤動作で window 移動するのを防ぐ。
      # 必要なら macOS の Accessibility 設定からマウスキー経由で代替可能。
      TrackpadThreeFingerDrag = false;
    };

    # ============================================================
    # WindowManager (macOS 14 Sonoma+) — Stage Manager / Desktop
    # ============================================================
    WindowManager = {
      # Sonoma で増えた「壁紙クリックでデスクトップ表示」を無効化。
      # 誤クリックで作業中の全 window が一斉に隠れるのを防ぐ。
      EnableStandardClickToShowDesktop = false;

      # デスクトップにアイコン (ファイル / フォルダ) を表示しない。
      # 作業領域として綺麗な状態を保ち、~/Desktop の中身は Finder で管理する。
      HideDesktop = true;

      # Stage Manager 利用時に widget を非表示 (画面ノイズ削減)。
      StageManagerHideWidgets = true;
    };

    # ============================================================
    # menubar clock — メニューバー右上の時計表示
    # ============================================================
    menuExtraClock = {
      # 12 時間制 + AM/PM 表示。24 時間制にしたければ
      # Show24Hour = true、ShowAMPM = false に切り替え。
      Show24Hour = false;
      ShowAMPM = true;

      # 曜日を表示、日付は非表示 (時計をコンパクトに保つ)。
      # 日付は menubar の Calendar アプリ icon 等から確認する。
      ShowDayOfWeek = true;
      ShowDate = 0; # 0 = off, 1 = when space allows, 2 = on

      # 秒は表示しない (psychological にも見ないほうが集中できる)。
      ShowSeconds = false;
    };
  };

  # ============================================================
  # キーボード modifier remap — HID レベルの key 入れ替え
  # ============================================================
  # `system.keyboard.*` は `system.defaults.*` とは別系統で、HID 入力レイヤで
  # key code を書き換える (System Settings → Keyboard → Modifier Keys と
  # 同じ層)。`hidutil property --set` を nix-darwin が裏で発行する。
  #
  # remapCapsLockToControl: 左 Caps Lock を Control に置き換える。
  # vim / tmux / emacs / shell の C-a / C-e / C-x / C-c などを左小指で
  # 押しやすい位置に持ってくる定番設定。Caps Lock 自体はほぼ使わないので
  # 物理キーを Control 化することで日常的な負荷を下げる。
  #
  # ただし `system.keyboard.*` は `darwin-rebuild switch` 時にのみ
  # `hidutil property --set` を発行する一方、hidutil の mapping は
  # session-scoped で再起動するとリセットされる (Apple TN2450)。
  # つまり「新マシンに switch → 再起動」した瞬間に default に戻ってしまう。
  # これを防ぐため、login 時に再適用する LaunchAgent を下の
  # `launchd.user.agents.remap-caps-lock` で declarative に追加する。
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  # 上の `system.keyboard.*` の永続化補助。RunAtLoad で login 直後に
  # `hidutil property --set` を再発行することで、再起動を跨いでも
  # Caps Lock → Control を維持する。送信する payload は nix-darwin の
  # keyboard.nix が switch 時に発行するものと同じ HID usage code:
  #   Src 0x700000039 = Caps Lock
  #   Dst 0x7000000E0 = Left Control
  launchd.user.agents.remap-caps-lock = {
    serviceConfig = {
      Label = "org.danimal141.remap-caps-lock";
      ProgramArguments = [
        "/usr/bin/hidutil"
        "property"
        "--set"
        ''{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0}]}''
      ];
      RunAtLoad = true;
    };
  };

  # ============================================================
  # 入力ソース切り替え shortcut (System Settings → Keyboard →
  # Keyboard Shortcuts → 入力ソース)
  # ============================================================
  # `com.apple.symbolichotkeys.AppleSymbolicHotKeys` は Spotlight /
  # Mission Control / Screenshot など多数の shortcut を 1 つの dict に
  # 持つ。`CustomUserPreferences` で書くと dict ごと上書きされて他 entry
  # を巻き込むため、`defaults write -dict-add` で 60 / 61 のみ targeted
  # update する activation script で宣言する。
  #
  # ID 60 = 前の入力ソースを選択 (⌘ Space)
  # ID 61 = 入力メニューの次のソースを選択 (⌥⌘ Space)
  #
  # parameters[0] = 32 (ASCII space)
  # parameters[1] = 49 (HID space key code)
  # parameters[2] = modifier mask
  #   1048576 = 0x100000 = ⌘
  #   1572864 = 0x180000 = ⌘ + ⌥ (Cmd + Option)
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "configuring input source switch shortcuts..." >&2
    USER_UID=$(id -u -- ${user})
    AS_USER="launchctl asuser $USER_UID sudo --user=${user} --"
    $AS_USER /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
      -dict-add 60 '{enabled=1;value={parameters=(32,49,1048576);type=standard;};}'
    $AS_USER /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
      -dict-add 61 '{enabled=1;value={parameters=(32,49,1572864);type=standard;};}'
    # cfprefsd を再起動して running session に即反映 (login 後の再ログインを不要に)
    $AS_USER /usr/bin/killall cfprefsd 2>/dev/null || true
  '';

  # zsh の rc は repo の `zsh/.zshrc` を home.file で `~/.zshrc` に symlink
  # 配置する (nix/home/programs/zsh.nix)。nix-darwin が /etc/zshrc を生成
  # すると home-manager 側の zshrc と読み込み順で競合 (PATH 重複 /
  # completion 多重設定) しうるため、system 側 zsh module は無効化する。
  programs.zsh.enable = false;

  # HOMEBREW_FORBIDDEN_FORMULAE: language runtime (node / python / ruby) は
  # mise が管理する。brew の依存解決が裏で node を pull すると PATH 順次第で
  # ビルドが壊れるため物理的に禁止する。`claude` は Anthropic 公式の npm
  # package で同様の二重 install を避けたいので含める。
  #
  # NIX_SSL_CERT_FILE: 社内 VPN の SSL inspection 対策 (下の
  # `nix.settings.ssl-cert-file` と同じ bundle を user shell にも見せる)。
  environment.variables = {
    HOMEBREW_FORBIDDEN_FORMULAE = "node python python3 pip npm pnpm yarn claude";
    NIX_SSL_CERT_FILE = "/etc/nix/ca-bundle.pem";
  };

  nix = {
    settings = {
      # flake / nix command を使うので必須
      experimental-features = [ "nix-command" "flakes" ];
      # primaryUser を trusted にして sudo なしで `darwin-rebuild` を打てるようにする
      trusted-users = [ "@admin" user ];

      # 社内 VPN の SSL inspection (中間者 CA) 対策。bundle は setup.sh が
      # macOS Keychain から `/etc/nix/ca-bundle.pem` に焼き出す。社内 CA を
      # 含むため bundle 自体はリポジトリに commit しない。bundle を更新した
      # ときは `sudo launchctl kickstart -k system/org.nixos.nix-daemon`。
      ssl-cert-file = "/etc/nix/ca-bundle.pem";
    };

    # Nix store の自動 GC: 30 日以上前の世代を毎週日曜 03:00 に削除。
    # nix-darwin の世代も対象になるため、ロールバック先がある程度長く残るよう
    # 30d は手厚めに取る。容量が逼迫したら 14d 等に短縮を検討。
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

  # nix-darwin の state 互換番号。手動 migration を伴うため上げない (現時点で 6)。
  system.stateVersion = 6;
}
