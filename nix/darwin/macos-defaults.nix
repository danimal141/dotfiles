{ ... }:

# `system.defaults.*` — `defaults write` 経路で macOS の domain (Dock /
# Finder / NSGlobalDomain / Trackpad / WindowManager / menuExtraClock /
# 任意 domain) を declarative に固定する。
#
# 設計方針:
#   * 「declarative に固定したい設定」をすべて宣言する。
#     宣言した key は `nix run .#switch` のたびに値が固定されるので、
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
      # 通常 52 / hover で 64 (約 1.23x ratio で控えめな拡大)。
      tilesize = 52;
      largesize = 64;

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

      # ドットファイル (隠しファイル) を Finder で常に表示する。default は隠す。
      # .zshrc / .config / .ssh 等を Finder から直接確認・移動するため有効化。
      AppleShowAllFiles = true;

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
        AppleLanguages = [
          "ja-JP"
          "en-JP"
        ];
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

      # Finder のデフォルト並び順を追加日順に設定。
      # FXArrangeGroupViewBy: 「整理」の基準 key ("Date Added" = 追加日)。
      # nix-darwin の typed finder option にないため CustomUserPreferences で設定。
      "com.apple.finder" = {
        FXArrangeGroupViewBy = "Date Added";
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
      # 24 時間制で表示。24 時間制では AM/PM ラベルは無意味なので
      # ShowAMPM は false に揃える。
      Show24Hour = true;
      ShowAMPM = false;

      # 曜日を表示、日付は非表示 (時計をコンパクトに保つ)。
      # 日付は menubar の Calendar アプリ icon 等から確認する。
      ShowDayOfWeek = true;
      ShowDate = 0; # 0 = off, 1 = when space allows, 2 = on

      # 秒は表示しない (psychological にも見ないほうが集中できる)。
      ShowSeconds = false;
    };
  };
}
