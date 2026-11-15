#!/usr/bin/env bash
# Salva o estado ATUAL do seu sistema dentro deste repo (configs + listas de pacotes + commit do end-4).
# Rode sempre que mudar algo importante, depois faça commit e push.
#
# Uso: ./backup.sh [--wallpapers]
# Se o end-4 estiver clonado em outro lugar: END4_DIR=/caminho ./backup.sh
set -Eeuo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITH_WALL=0
[ "${1:-}" = "--wallpapers" ] && WITH_WALL=1

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }
read_list() { grep -vE '^\s*(#|$)' "$1" 2>/dev/null || true; }

log "Copiando configs de ~/.config"
while IFS= read -r name; do
  src="$HOME/.config/$name"; dst="$REPO_DIR/config/$name"
  if [ ! -d "$src" ]; then warn "~/.config/$name não existe, pulando."; continue; fi
  rm -rf "$dst"; mkdir -p "$dst"
  cp -a "$src/." "$dst/"
  echo "OK: $name"
done < <(read_list "$REPO_DIR/dotfiles.list")

log "Exportando listas de pacotes"
# remove os meta-pacotes do end-4 (o instalador oficial cuida deles) e pacotes -debug
{ echo "# Pacotes oficiais (pacman) instalados explicitamente. Gerado por ./backup.sh em $(date +%F)"
  pacman -Qqen | grep -vE '^illogical-impulse-|-debug$' || true; } > "$REPO_DIR/packages/pacman-extra.txt"
{ echo "# Pacotes do AUR/foreign instalados explicitamente. Gerado por ./backup.sh em $(date +%F)"
  pacman -Qqem | grep -vE '^illogical-impulse-|-debug$' || true; } > "$REPO_DIR/packages/aur.txt"
echo "pacman: $(read_list "$REPO_DIR/packages/pacman-extra.txt" | wc -l) pacotes | AUR: $(read_list "$REPO_DIR/packages/aur.txt" | wc -l) pacotes"

log "Registrando o commit do end-4"
END4_DIR="${END4_DIR:-}"
if [ -z "$END4_DIR" ]; then
  for c in "$HOME/.local/src/dots-hyprland" "$HOME/dots-hyprland" "$HOME/Downloads/dots-hyprland" "$HOME/Downloads/dots-hyprland-main"; do
    [ -d "$c/.git" ] && { END4_DIR="$c"; break; }
  done
fi
if [ -n "$END4_DIR" ] && [ -d "$END4_DIR/.git" ]; then
  { echo "# Commit do end-4/dots-hyprland usado. Gerado por ./backup.sh em $(date +%F)"
    git -C "$END4_DIR" rev-parse HEAD; } > "$REPO_DIR/end4-commit.txt"
  echo "end-4 em $(git -C "$END4_DIR" rev-parse --short HEAD)"
else
  warn "Clone do end-4 não encontrado. Rode: END4_DIR=/caminho/do/clone ./backup.sh"
fi

if [ "$WITH_WALL" = 1 ] && [ -d "$HOME/Imagens/Wallpapers" ]; then
  log "Copiando wallpapers (cuidado com o tamanho do repo)"
  cp -a "$HOME/Imagens/Wallpapers/." "$REPO_DIR/wallpapers/"
fi

log "Procurando possíveis segredos nas configs"
grep -rIinE 'api[_-]?key|secret|token|password|senha' "$REPO_DIR/config" 2>/dev/null | grep -v 'fuzzel-emoji' | head -n 20 \
  && warn "Revise as linhas acima ANTES de dar push (principalmente se o repo for público)." || echo "Nada suspeito encontrado."

echo; echo "Feito. Agora: git add -A && git commit -m 'backup' && git push"
