#!/usr/bin/env bash
# ==============================================================================
#  Installer for JDM-theme-Grub (RAM & Cyberpunk Edition)
# ==============================================================================

set -e

THEME_NAME="JDM-theme-Grub"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRUB_DEFAULT="/etc/default/grub"
LINUX_SCRIPT="/etc/grub.d/10_linux"

# ANSI Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
BOLD="\033[1m"
RESET="\033[0m"

log_info()  { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[AVISO]${RESET} $*"; }
log_error() { echo -e "${RED}[ERRO]${RESET} $*" >&2; exit 1; }

# Root check
if [ "$EUID" -ne 0 ]; then
  log_error "Execute como root: sudo bash $0"
fi

# Detect GRUB config file
if [ -f /boot/grub/grub.cfg ]; then
  GRUB_CFG="/boot/grub/grub.cfg"
  THEMES_DIR="/boot/grub/themes"
elif [ -f /boot/grub2/grub.cfg ]; then
  GRUB_CFG="/boot/grub2/grub.cfg"
  THEMES_DIR="/boot/grub2/themes"
else
  log_error "Arquivo grub.cfg não encontrado em /boot/grub ou /boot/grub2."
fi

TARGET_DIR="$THEMES_DIR/$THEME_NAME"

# Desinstalação
if [ "$1" == "--uninstall" ] || [ "$1" == "-u" ]; then
  log_info "Desinstalando $THEME_NAME..."
  rm -rf "$TARGET_DIR"
  if grep -q "$THEME_NAME" "$GRUB_DEFAULT" 2>/dev/null; then
    sed -i "\|^GRUB_THEME=.*$THEME_NAME.*|d" "$GRUB_DEFAULT"
    log_ok "Linha GRUB_THEME removida de $GRUB_DEFAULT"
  fi
  if [ -f "${LINUX_SCRIPT}.bak" ]; then
    cp "${LINUX_SCRIPT}.bak" "$LINUX_SCRIPT"
    rm -f "${LINUX_SCRIPT}.bak"
    log_ok "Restaurado $LINUX_SCRIPT original."
  fi
  log_info "Regenerando $GRUB_CFG..."
  grub-mkconfig -o "$GRUB_CFG"
  log_ok "Tema desinstalado com sucesso!"
  exit 0
fi

echo -e "${BOLD}${CYAN}====================================================${RESET}"
echo -e "${BOLD}${CYAN}   Instalação do tema GRUB: JDM RAM Edition         ${RESET}"
echo -e "${BOLD}${CYAN}====================================================${RESET}"

# 1. Copiar arquivos do tema
log_info "Instalando tema em: $TARGET_DIR"
mkdir -p "$THEMES_DIR"
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

# Copiar arquivos necessários (excluindo git e arquivos de desenvolvimento)
cp -r "$SCRIPT_DIR/background.png" "$TARGET_DIR/"
cp -r "$SCRIPT_DIR/theme.txt" "$TARGET_DIR/"
cp -r "$SCRIPT_DIR/icons" "$TARGET_DIR/"
cp -r "$SCRIPT_DIR/select_glow" "$TARGET_DIR/"
cp -r "$SCRIPT_DIR/item_box" "$TARGET_DIR/"
cp -r "$SCRIPT_DIR"/*.pf2 "$TARGET_DIR/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/fonts" "$TARGET_DIR/" 2>/dev/null || true

log_ok "Arquivos copiados com sucesso."

# 2. Configurar /etc/default/grub
log_info "Configurando $GRUB_DEFAULT..."
THEME_ENTRY="GRUB_THEME=\"$TARGET_DIR/theme.txt\""

if grep -q "^GRUB_THEME=" "$GRUB_DEFAULT"; then
  sed -i "s|^GRUB_THEME=.*|$THEME_ENTRY|" "$GRUB_DEFAULT"
  log_ok "Parâmetro GRUB_THEME atualizado."
elif grep -q "^#GRUB_THEME=" "$GRUB_DEFAULT"; then
  sed -i "s|^#GRUB_THEME=.*|$THEME_ENTRY|" "$GRUB_DEFAULT"
  log_ok "Parâmetro GRUB_THEME descomentado e atualizado."
else
  echo "$THEME_ENTRY" >> "$GRUB_DEFAULT"
  log_ok "Parâmetro GRUB_THEME adicionado."
fi

# Ajustar GFXMODE para 1920x1080 (evita distorções de proporção)
if grep -q "^GRUB_GFXMODE=" "$GRUB_DEFAULT"; then
  sed -i "s|^GRUB_GFXMODE=.*|GRUB_GFXMODE=1920x1080,auto|" "$GRUB_DEFAULT"
else
  echo "GRUB_GFXMODE=1920x1080,auto" >> "$GRUB_DEFAULT"
fi
log_ok "Resolução definida para 1920x1080."

# Desativar entradas fantasmas da BIOS/NVRAM (evita duplicatas e botões vazios)
if grep -q "^GRUB_DISABLE_BOOTNEXT=" "$GRUB_DEFAULT"; then
  sed -i 's|^GRUB_DISABLE_BOOTNEXT=.*|GRUB_DISABLE_BOOTNEXT="true"|' "$GRUB_DEFAULT"
else
  echo 'GRUB_DISABLE_BOOTNEXT="true"' >> "$GRUB_DEFAULT"
fi
log_ok "Entradas redundantes da BIOS (EFI BootNext) desativadas."

# 3. Suporte automático a placas por kernel (ex: linux-covenant, linux-cachyos)
if [ -f "$LINUX_SCRIPT" ] && ! grep -q "kclass=" "$LINUX_SCRIPT"; then
  log_info "Configurando suporte a placas por kernel em $LINUX_SCRIPT..."
  cp "$LINUX_SCRIPT" "${LINUX_SCRIPT}.bak"
  sed -i '/linux_entry ()/,/args=/ {
    /args=/ a\  kclass="--class ${version} --class $(echo "${version}" | sed "s,linux-,,g")"
  }' "$LINUX_SCRIPT"
  sed -i 's/menuentry '\''$(echo "$title" | grub_quote)'\'' \${CLASS}/menuentry '\''$(echo "$title" | grub_quote)'\'' \${kclass} \${CLASS}/' "$LINUX_SCRIPT"
  sed -i 's/menuentry '\''$(echo "$os" | grub_quote)'\'' \${CLASS}/menuentry '\''$(echo "$os" | grub_quote)'\'' \${kclass} \${CLASS}/' "$LINUX_SCRIPT"
  log_ok "Suporte a placas por kernel ativado."
fi

# 4. Regenerar grub.cfg
log_info "Regenerando o menu do GRUB ($GRUB_CFG)..."
grub-mkconfig -o "$GRUB_CFG"

echo ""
echo -e "${GREEN}====================================================${RESET}"
echo -e "${GREEN}   ✨ Tema JDM RAM instalado com sucesso!           ${RESET}"
echo -e "${GREEN}====================================================${RESET}"
echo -e "Reinicie o sistema para conferir o visual no boot."
