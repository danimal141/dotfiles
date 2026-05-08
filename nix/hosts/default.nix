{ ... }:

# Phase 1 (move-nix) prototype host。private.nix の username を
# system.primaryUser / home.homeDirectory に流す経路を実証するためだけの
# 最小ホスト定義。
#
# work.nix / personal.nix が `networking.hostName` を強制するのは IT 部門
# 払い出しの hostname を上書きして chezmoi 側の machineType 判定を確実に
# する目的だった。default は private.nix から identity を取るので
# hostname に依存せず、ここでは `networking.hostName` を宣言しない。
#
# Phase 2 で hosts/ 配下を default のみに集約 → Phase 3 以降で nix/hosts/
# 自体を撤去予定。
{ }
