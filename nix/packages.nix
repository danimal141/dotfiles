{ pkgs, inputs, ... }:

{
  # CLI tools served from the Nix store. Nixpkgs commit pinning lives in
  # flake.lock so every host on a given commit gets bit-identical binaries.
  #
  # Packages still managed by Homebrew (see nix/homebrew.nix):
  # * GUI casks
  # * tap-only formulae (kayac/ecspresso, fujiwara/tfstate-lookup, etc.)
  # * tools that need Apple-specific signing or system integration
  #   (chromium, gdb, basictex, mysql, redis, llvm)
  # * shell bootstrap binaries (chezmoi, mise) that should not depend on
  #   `darwin-rebuild` having already run
  environment.systemPackages = (with pkgs; [
    # core text & file utilities
    bat
    coreutils
    fd
    fzf
    gnused
    jq
    ripgrep
    silver-searcher
    tig
    tree
    yq-go

    # editors
    neovim
    vim

    # multiplexer
    tmux

    # git
    gh
    git

    # system inspection
    htop
    procps  # provides watch / pgrep / etc.
    pstree

    # network
    curl
    wget

    # shell helpers
    direnv
    parallel
    peco

    # docs / data
    cloc
    cue
    graphviz
    pandoc

    # kubernetes ecosystem
    kubectx
    kustomize
    kubernetes-helm
    stern
  ]) ++ [
    # APM (microsoft/apm) packaged by numtide/llm-agents.nix.
    inputs.llm-agents.packages.${pkgs.system}.apm
  ];
}
