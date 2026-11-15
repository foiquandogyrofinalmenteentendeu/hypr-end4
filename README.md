# hypr-end4

Meu Arch Linux + Hyprland baseado nos dots do [end-4](https://github.com/end-4/dots-hyprland), com minhas modificações (ex.: `keybinds.lua` traduzido para português).
Objetivo: formatar o PC e voltar ao mesmo ambiente com poucos comandos.

## Estrutura

```
hypr-end4/
├── install.sh          # restaura tudo num Arch recém-instalado
├── backup.sh           # salva o estado atual (configs + pacotes + commit do end-4)
├── dotfiles.list       # pastas de ~/.config que entram no backup
├── end4-commit.txt     # versão do end-4 que funciona com minhas configs
├── config/hypr/        # minha configuração do Hyprland (Lua)
├── packages/
│   ├── base.txt        # pacotes base (os do guia de instalação)
│   ├── pacman-extra.txt  # meus pacotes oficiais (gerado)
│   └── aur.txt           # meus pacotes do AUR (gerado)
├── wallpapers/         # opcional
└── docs/Guia_Instalacao_Arch_Hyprland_end4.docx
```

## Restaurar depois de formatar

1. Instale o Arch pelo `archinstall` (perfil **Minimal**, NetworkManager, usuário com sudo). Veja `docs/`.
2. No primeiro boot, conecte na internet:
   ```bash
   sudo systemctl enable --now NetworkManager
   nmcli device wifi connect "NOME_DA_REDE" password "SENHA"
   ```
3. Baixe e rode:
   ```bash
   sudo pacman -S --needed git
   git clone https://github.com/SEU_USUARIO/hypr-end4.git
   cd hypr-end4
   ./install.sh
   ```
4. Reinicie, entre no TTY e rode `Hyprland`.

O `install.sh` faz, em ordem: atualiza o sistema e instala `base.txt` → ativa NetworkManager/Bluetooth → clona o end-4 oficial no commit registrado e roda o `./setup install` dele (interativo) → copia **suas** configs por cima (guardando backup `.bak-DATA` do que existia) → instala seus pacotes extras.

Opções: `--skip-end4`, `--skip-packages`, `--only-config` (só restaura as configs).

## Atualizar o backup (faça de vez em quando)

```bash
cd ~/hypr-end4
./backup.sh            # ou ./backup.sh --wallpapers
git add -A && git commit -m "backup" && git push
```

Se o end-4 estiver clonado em outra pasta: `END4_DIR=/caminho ./backup.sh`.

## Observações

- O Hyprland 0.55+ usa configuração em Lua. O commit fixado em `end4-commit.txt` evita surpresas se o end-4 mudar muito.
- Configs de apps (Firefox etc.) **não** estão incluídas, só pacotes. Para incluir uma pasta de `~/.config`, adicione em `dotfiles.list`.
- O `hyprlock/colors.conf` aponta para `~/Imagens/Wallpapers/random_wallpaper.jpg`; o `install.sh` troca `/home/lain` pelo seu `$HOME` se o usuário for outro.
- Nunca coloque senhas/chaves de API no repo. O `backup.sh` avisa se achar algo suspeito.
