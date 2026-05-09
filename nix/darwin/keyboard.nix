{ user, lib, ... }:

# キーボード layer の declarative 副作用を 3 経路で組み合わせる:
#
#   1. `system.keyboard` — HID 層で Caps Lock を Control に remap
#      (`hidutil property --set` 経由)
#   2. `launchd.user.agents.remap-caps-lock` — login のたびに hidutil
#      mapping を再適用 (= session-scoped で揮発するのを補う永続化)
#   3. `system.activationScripts.postActivation` — 入力ソース切替の
#      `AppleSymbolicHotKeys` を `defaults write -dict-add` で targeted update
#      (= dict 全体を上書きせず ID 60 / 61 のみ書き換える)
#
# 1 + 2 は CapsLock → Control の永続化、3 は ⌘ Space / ⌥⌘ Space を
# 入力ソース切替に固定する用途。前者は HID layer、後者は AppleSymbolic
# Hotkey なので層は別だが、どちらも「キーボード layer の declarative
# 副作用」として近接配置している。
{
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
}
