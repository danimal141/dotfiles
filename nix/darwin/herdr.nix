{ user, ... }:

# herdr server を login 時常駐の LaunchAgent として declarative に上げる。
#
# 背景 (この module が要る理由):
#   herdr は「headless server + attach client」構成で、client が繋いでいる
#   server が消えると client 側に `detached from server` が出る。ところが
#   server は app / LaunchAgent / login item のいずれでも自動起動されておらず、
#   `herdr` / `herdr-start` 実行時にその場で立つ自己 daemon (PPID=1) でしかない。
#   keep_alive されないため boot 直後は server の存在が保証されず、初回
#   `herdr-start` (内部の `exec herdr`) が「立ち上がりかけ / update 差し替え中 /
#   落ちた直後」の server を掴んで `detached from server` を出すことがあった。
#   ここで launchd に 1 本常駐させることで、boot 直後から必ず server が居る
#   状態を作り、この race を消す。
#
#   実測メモ: client を SIGKILL しても server は clean に disconnect を記録し、
#   複数 client の同時 attach も許容される (mirror 型)。つまり `detached from
#   server` は client 同士の衝突ではなく server 消滅時にだけ出る。原因は
#   server 寿命側にあり、常駐化が正しい対処になる。
#
# Homebrew formula との関係:
#   本 agent は Homebrew formula の `service do / run [herdr, "server"] /
#   keep_alive true` を nix-darwin の declarative agent へ写したもの。binary を
#   mise 供給へ移した今も常駐はこの agent に一本化する (brew 版が残っている
#   マシンで `brew services start herdr` を併用すると launchd plist が 2 枚に
#   なり同じ socket を奪い合って server が二重起動する)。
#
# update 手順 (`mise install` だけでは不十分):
#   tools/mise/config.toml の version を上げて `mise install` しても、launchd 上で
#   実行中の旧 server プロセスはそのまま残る。新 CLI と旧 server が並存し、
#   protocol 非互換のある更新では操作不能になりうる。install 後に
#   `herdr server stop` で旧 server を落とすと KeepAlive が即座に新 binary で
#   server を上げ直す。最後に `herdr status server` の version で反映を確認する。
#
# 初回 bootstrap:
#   nix-darwin は switch 時に plist を配置するだけでなく `launchctl` で即
#   load する (RunAtLoad なので switch 時点で server が上がる。次回 login 待ちで
#   はない)。既に ad-hoc の server が socket を握った状態で switch すると、agent
#   側の server が bind に失敗し KeepAlive で再起動ループになりうる。初回だけ
#   `herdr server stop` で既存を止めてから `nix run .#switch` すること。以後は
#   launchd 管理の 1 本だけが上がる (bare `herdr` は socket が生きていれば
#   server を新規起動せず attach するだけなので衝突しない)。
{
  # herdr binary は nixpkgs 未収載で mise 供給 (tools/mise/config.toml)。
  # mise の shim を指すので version を上げてもこの path は不変 (shim が global
  # config から version を解決する)。新規マシンでは setup.sh の `mise install`
  # が終わるまで binary が無く、agent は KeepAlive で起動を繰り返す。
  launchd.user.agents.herdr-server = {
    serviceConfig = {
      Label = "org.danimal141.herdr-server";
      ProgramArguments = [
        "/Users/${user}/.local/share/mise/shims/herdr"
        "server"
      ];
      # formula の keep_alive true と同義。落ちても login 時も常に 1 本上げる。
      KeepAlive = true;
      RunAtLoad = true;
    };
  };
}
