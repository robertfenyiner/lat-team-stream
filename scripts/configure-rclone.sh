#!/usr/bin/env bash
# Configure rclone for multiple cloud providers
# Usage: ./configure-rclone.sh
# This script helps configure OneDrive, Google Drive, and MEGA

set -euo pipefail

RCLONE_CONFIG_DIR="/root/.config/rclone"
RCLONE_CONFIG_FILE="$RCLONE_CONFIG_DIR/rclone.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Configuración de Rclone para múltiples proveedores ===${NC}"
echo ""

# Ensure rclone config directory exists
mkdir -p "$RCLONE_CONFIG_DIR"

# Function to check if rclone is installed
check_rclone() {
    if ! command -v rclone &> /dev/null; then
        echo -e "${RED}Error: rclone no está instalado.${NC}"
        echo "Instálalo con: curl https://rclone.org/install.sh | sudo bash"
        exit 1
    fi
    echo -e "${GREEN}✓ Rclone está instalado: $(rclone version | head -n1)${NC}"
}

# Function to show existing remotes
show_remotes() {
    echo -e "${YELLOW}Remotos configurados actualmente:${NC}"
    if [ -f "$RCLONE_CONFIG_FILE" ]; then
        rclone listremotes 2>/dev/null || echo "Ninguno configurado"
    else
        echo "Ninguno configurado"
    fi
    echo ""
}

# Function to configure OneDrive
configure_onedrive() {
    echo -e "${BLUE}=== Configurando OneDrive ===${NC}"
    echo "Esto abrirá tu navegador para autenticación..."
    echo ""
    
    rclone config create onedrive onedrive \
        --config="$RCLONE_CONFIG_FILE" \
        --non-interactive=false || {
        echo -e "${RED}Error configurando OneDrive${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ OneDrive configurado exitosamente${NC}"
    echo ""
}

# Function to configure Google Drive
configure_gdrive() {
    echo -e "${BLUE}=== Configurando Google Drive ===${NC}"
    echo "Esto abrirá tu navegador para autenticación..."
    echo ""
    
    rclone config create gdrive drive \
        --config="$RCLONE_CONFIG_FILE" \
        --non-interactive=false || {
        echo -e "${RED}Error configurando Google Drive${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ Google Drive configurado exitosamente${NC}"
    echo ""
}

# Function to configure MEGA
configure_mega() {
    echo -e "${BLUE}=== Configurando MEGA ===${NC}"
    echo "Necesitarás tu email y contraseña de MEGA"
    echo ""
    
    read -p "Email de MEGA: " mega_email
    read -sp "Contraseña de MEGA: " mega_password
    echo ""
    
    rclone config create mega mega \
        user="$mega_email" \
        pass="$(rclone obscure "$mega_password")" \
        --config="$RCLONE_CONFIG_FILE" || {
        echo -e "${RED}Error configurando MEGA${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ MEGA configurado exitosamente${NC}"
    echo ""
}

# Function to test mounts
test_mounts() {
    echo -e "${BLUE}=== Probando montajes ===${NC}"
    
    for remote in onedrive gdrive mega; do
        if rclone listremotes --config="$RCLONE_CONFIG_FILE" | grep -q "^${remote}:"; then
            echo "Probando $remote..."
            mkdir -p "/tmp/test-$remote"
            
            if timeout 30 rclone ls "$remote:" --config="$RCLONE_CONFIG_FILE" --max-depth 1 >/dev/null 2>&1; then
                echo -e "${GREEN}✓ $remote: Conexión exitosa${NC}"
            else
                echo -e "${RED}✗ $remote: Error de conexión${NC}"
            fi
        fi
    done
    echo ""
}

# Function to create mount directories
create_mount_dirs() {
    echo -e "${BLUE}=== Creando directorios de montaje ===${NC}"
    
    for dir in onedrive gdrive mega; do
        if [ ! -d "/mnt/$dir" ]; then
            mkdir -p "/mnt/$dir"
            echo -e "${GREEN}✓ Creado /mnt/$dir${NC}"
        else
            echo -e "${YELLOW}✓ /mnt/$dir ya existe${NC}"
        fi
    done
    echo ""
}

# Main menu
main_menu() {
    while true; do
        echo -e "${BLUE}=== Menú de configuración ===${NC}"
        echo "1) Configurar OneDrive"
        echo "2) Configurar Google Drive"
        echo "3) Configurar MEGA"
        echo "4) Probar conexiones"
        echo "5) Mostrar remotos configurados"
        echo "6) Crear directorios de montaje"
        echo "7) Salir"
        echo ""
        
        read -p "Selecciona una opción (1-7): " choice
        
        case $choice in
            1) configure_onedrive ;;
            2) configure_gdrive ;;
            3) configure_mega ;;
            4) test_mounts ;;
            5) show_remotes ;;
            6) create_mount_dirs ;;
            7) echo -e "${GREEN}¡Configuración completada!${NC}"; break ;;
            *) echo -e "${RED}Opción inválida${NC}" ;;
        esac
    done
}

# Main execution
check_rclone
show_remotes
create_mount_dirs
main_menu

echo ""
echo -e "${GREEN}=== Configuración finalizada ===${NC}"
echo "Para montar las unidades, usa los servicios systemd:"
echo "  systemctl enable rclone-mount@onedrive"
echo "  systemctl enable rclone-mount@gdrive"  
echo "  systemctl enable rclone-mount@mega"
echo "  systemctl start rclone-mount@onedrive"
echo "  systemctl start rclone-mount@gdrive"
echo "  systemctl start rclone-mount@mega"