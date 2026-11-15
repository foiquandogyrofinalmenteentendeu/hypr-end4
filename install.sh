#!/usr/bin/env bash
# Restaura o ambiente Arch + Hyprland (end-4) com as suas configs.
# Rode como usuário normal (com sudo), com internet, depois do primeiro boot do Arch mínimo.
#
# Uso: ./install.sh [--skip-end4] [--skip-packages] [--only-config]
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
END4_URL="https://github.com/end-4/dots-hyprland"
END4_DIR="${END4_DIR:-$HOME/.local/src/dots-hyprland}"
END4_REF="${END4_REF:-}"
WALL_DIR="$HOME/Imagens/Wallpapers"
OLD_HOME="/home/lain"
STAMP="$(date +%Y%m%d-%H%M%S)"

DO_BASE=1; DO_END4=1; DO_CONFIG=1; DO_EXTRA=1
for arg in "$@"; do
  case "$arg" in
    --skip-end4)     DO_END4=0 ;;
    --skip-packages) DO_BASE=0; DO_EXTRA=0 ;;
    --only-config)   DO_BASE=0; DO_END4=0; DO_EXTRA=0 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $arg"; exit 1 ;;
  esac
done

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[erro]\033[0m %s\n' "$*" >&2; exit 1; }

read_list() { grep -vE '^\s*(#|$)' "$1" 2>/dev/null || true; }

pacman_install_file() {
  local file="$1" pkgs
  mapfile -t pkgs < <(read_list "$file")
  [ "${#pkgs[@]}" -eq 0 ] && { warn "$file está vazio, pulando."; return 0; }
  if ! sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
    warn "Instalação em lote falhou; tentando um por um."
    for p in "${pkgs[@]}"; do
      sudo pacman -S --needed --noconfirm "$p" || warn "Falhou: $p"
    done
  fi
}

ensure_aur_helper() {
  command -v yay >/dev/null 2>&1 && { AUR=yay; return; }
  command -v paru >/dev/null 2>&1 && { AUR=paru; return; }
  log "Instalando yay (helper do AUR)"
  local tmp; tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"; AUR=yay
}

# ---------- checagens ----------
[ "$(id -u)" -ne 0 ] || die "Não rode como root. Use seu usuário normal (com sudo)."
command -v pacman >/dev/null || die "Isto só funciona no Arch Linux."
if [ "$DO_BASE$DO_END4$DO_EXTRA" != "000" ]; then
  ping -c 1 -W 3 archlinux.org >/dev/null 2>&1 || die "Sem internet. Conecte (nmcli device wifi connect ...) e tente de novo."
fi

# ---------- 1. sistema base ----------
if [ "$DO_BASE" = 1 ]; then
  log "Atualizando o sistema e instalando pacotes base"
  sudo pacman -Syu --noconfirm
  pacman_install_file "$REPO_DIR/packages/base.txt"
  sudo systemctl enable --now NetworkManager || warn "NetworkManager não habilitou."
  sudo systemctl enable --now bluetooth || warn "Bluetooth não habilitou."
fi

# ---------- 2. end-4 oficial ----------
if [ "$DO_END4" = 1 ]; then
  log "Baixando o end-4/dots-hyprland em $END4_DIR"
  mkdir -p "$(dirname "$END4_DIR")"
  if [ ! -d "$END4_DIR/.git" ]; then
    git clone --recurse-submodules "$END4_URL" "$END4_DIR"
  fi
  ref="$END4_REF"
  [ -z "$ref" ] && ref="$(read_list "$REPO_DIR/end4-commit.txt" | head -n1 || true)"
  if [ -n "$ref" ]; then
    log "Usando o commit fixado do end-4: $ref"
    git -C "$END4_DIR" fetch --all --tags
    git -C "$END4_DIR" checkout "$ref"
    git -C "$END4_DIR" submodule update --init --recursive
  else
    warn "Nenhum commit fixado; usando o mais recente do end-4."
  fi
  log "Rodando o instalador oficial do end-4 (interativo, responda as perguntas)"
  (cd "$END4_DIR" && ./setup install)
fi

# ---------- 3. suas configs ----------
if [ "$DO_CONFIG" = 1 ]; then
  log "Restaurando suas configs em ~/.config"
  mkdir -p "$HOME/.config"
  while IFS= read -r name; do
    src="$REPO_DIR/config/$name"; dst="$HOME/.config/$name"
    if [ ! -d "$src" ]; then warn "config/$name não existe no repo, pulando."; continue; fi
    if [ -e "$dst" ]; then
      cp -a "$dst" "$dst.bak-$STAMP"
      echo "Backup do existente: $dst.bak-$STAMP"
    fi
    mkdir -p "$dst"
    cp -a "$src/." "$dst/"
    echo "OK: ~/.config/$name"
  done < <(read_list "$REPO_DIR/dotfiles.list")

  # caminhos fixos do usuário antigo (ex.: wallpaper do hyprlock)
  if [ "$HOME" != "$OLD_HOME" ]; then
    grep -rIl "$OLD_HOME/" "$HOME/.config/hypr" 2>/dev/null | while read -r f; do
      sed -i "s#$OLD_HOME/#$HOME/#g" "$f"
    done
  fi
  find "$HOME/.config/hypr" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

  # wallpapers (opcional)
  if [ -n "$(ls -A "$REPO_DIR/wallpapers" 2>/dev/null | grep -v '^\.gitkeep$' || true)" ]; then
    mkdir -p "$WALL_DIR"
    cp -an "$REPO_DIR/wallpapers/." "$WALL_DIR/"
    rm -f "$WALL_DIR/.gitkeep"
    echo "Wallpapers copiados para $WALL_DIR"
  fi
fi

# ---------- 4. seus pacotes extras ----------
if [ "$DO_EXTRA" = 1 ]; then
  log "Instalando seus pacotes extras (pacman)"
  pacman_install_file "$REPO_DIR/packages/pacman-extra.txt"
  mapfile -t aur_pkgs < <(read_list "$REPO_DIR/packages/aur.txt")
  if [ "${#aur_pkgs[@]}" -gt 0 ]; then
    ensure_aur_helper
    log "Instalando seus pacotes do AUR ($AUR)"
    "$AUR" -S --needed --noconfirm "${aur_pkgs[@]}" || warn "Alguns pacotes do AUR falharam."
  fi
fi

log "Pronto! Reinicie, faça login no TTY e rode: Hyprland"
echo "Atalhos: Super + / (lista de atalhos), Super + Enter (terminal)"
