#!/usr/bin/env bash
# LAT Team Stream - Instalador Automático
# Ubuntu 22.04 LTS - Usuario root
# Autor: LAT Team
# Versión: 2.0

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
INSTALL_DIR="/opt/lat-stream"
LOG_FILE="/var/log/lat-stream-install.log"
BACKUP_DIR="/root/lat-stream-backup-$(date +%Y%m%d-%H%M%S)"
REPO_URL="https://github.com/robertfenyiner/lat-team-stream.git"
REPO_BRANCH="main"

# Función de logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] $message" | tee -a "$LOG_FILE"
}

# Función para mostrar banner
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🎬 LAT TEAM STREAM                        ║"
    echo "║                  Instalador Automático v2.0                 ║"
    echo "║                                                              ║"
    echo "║         Sistema de Streaming Multi-Fuente desde la Nube     ║"
    echo "║                Ubuntu 22.04 LTS - Usuario root              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Función para verificar requisitos
check_requirements() {
    log "INFO" "${BLUE}🔍 Verificando requisitos del sistema...${NC}"
    
    # Verificar Ubuntu 22.04
    if ! grep -q "22.04" /etc/lsb-release 2>/dev/null; then
        log "ERROR" "${RED}❌ Este script está diseñado para Ubuntu 22.04 LTS${NC}"
        exit 1
    fi
    
    # Verificar usuario root
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "${RED}❌ Este script debe ejecutarse como root${NC}"
        exit 1
    fi
    
    # Verificar conexión a internet
    if ! ping -c 1 google.com &> /dev/null; then
        log "ERROR" "${RED}❌ No hay conexión a internet${NC}"
        exit 1
    fi
    
    # Verificar espacio en disco (mínimo 20GB)
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 20971520 ]; then  # 20GB in KB
        log "WARN" "${YELLOW}⚠️  Espacio en disco bajo. Se recomiendan al menos 20GB libres${NC}"
        read -p "¿Continuar de todas formas? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "INFO" "${GREEN}✅ Requisitos del sistema verificados${NC}"
}

# Función para crear backup
create_backup() {
    log "INFO" "${BLUE}💾 Creando backup de configuraciones existentes...${NC}"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup de nginx si existe
    if [ -f /etc/nginx/nginx.conf ]; then
        cp /etc/nginx/nginx.conf "$BACKUP_DIR/nginx.conf.backup"
    fi
    
    # Backup de configuración rclone si existe
    if [ -d /root/.config/rclone ]; then
        cp -r /root/.config/rclone "$BACKUP_DIR/rclone-backup"
    fi
    
    # Backup de servicios systemd existentes
    for service in multi-stream nginx-stream rclone-mount@; do
        if [ -f "/etc/systemd/system/${service}.service" ]; then
            cp "/etc/systemd/system/${service}.service" "$BACKUP_DIR/"
        fi
    done
    
    log "INFO" "${GREEN}✅ Backup creado en: $BACKUP_DIR${NC}"
}

# Función para actualizar sistema
update_system() {
    log "INFO" "${BLUE}🔄 Actualizando sistema...${NC}"
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt update -qq
    apt upgrade -y -qq
    apt autoremove -y -qq
    
    log "INFO" "${GREEN}✅ Sistema actualizado${NC}"
}

# Función para instalar dependencias básicas
install_basic_dependencies() {
    log "INFO" "${BLUE}📦 Instalando dependencias básicas...${NC}"
    
    apt install -y -qq \
        curl \
        wget \
        git \
        unzip \
        software-properties-common \
        fuse \
        htop \
        nano \
        ufw \
        fail2ban \
        logrotate
    
    # Configurar fuse para rclone
    if ! grep -q "user_allow_other" /etc/fuse.conf; then
        echo 'user_allow_other' >> /etc/fuse.conf
    fi
    
    log "INFO" "${GREEN}✅ Dependencias básicas instaladas${NC}"
}

# Función para instalar FFmpeg
install_ffmpeg() {
    log "INFO" "${BLUE}🎥 Instalando FFmpeg...${NC}"
    
    # Agregar repositorio para FFmpeg actualizado
    add-apt-repository ppa:savoury1/ffmpeg4 -y -qq
    apt update -qq
    
    # Instalar FFmpeg
    apt install -y -qq ffmpeg
    
    # Verificar instalación
    if ffmpeg -version >/dev/null 2>&1; then
        local version=$(ffmpeg -version 2>&1 | head -n1 | cut -d' ' -f3)
        log "INFO" "${GREEN}✅ FFmpeg instalado: $version${NC}"
    else
        log "ERROR" "${RED}❌ Error instalando FFmpeg${NC}"
        exit 1
    fi
}

# Función para instalar Nginx con RTMP
install_nginx() {
    log "INFO" "${BLUE}🌐 Instalando Nginx con módulo RTMP...${NC}"
    
    # Instalar Nginx y módulo RTMP
    apt install -y -qq nginx libnginx-mod-rtmp
    
    # Verificar instalación
    if nginx -V 2>&1 | grep -q "rtmp"; then
        log "INFO" "${GREEN}✅ Nginx con módulo RTMP instalado${NC}"
    else
        log "ERROR" "${RED}❌ Error: Nginx no tiene módulo RTMP${NC}"
        exit 1
    fi
    
    # Detener nginx por ahora
    systemctl stop nginx
}

# Función para instalar Rclone
install_rclone() {
    log "INFO" "${BLUE}☁️  Instalando Rclone...${NC}"
    
    curl -s https://rclone.org/install.sh | bash
    
    # Verificar instalación
    if rclone version >/dev/null 2>&1; then
        local version=$(rclone version 2>&1 | head -n1 | cut -d' ' -f2)
        log "INFO" "${GREEN}✅ Rclone instalado: $version${NC}"
    else
        log "ERROR" "${RED}❌ Error instalando Rclone${NC}"
        exit 1
    fi
}

# Función para configurar proyecto
setup_project() {
    log "INFO" "${BLUE}📂 Descargando y configurando proyecto LAT Stream...${NC}"
    
    # Eliminar directorio si existe
    if [ -d "$INSTALL_DIR" ]; then
        log "INFO" "${YELLOW}⚠️  Directorio existente, haciendo backup...${NC}"
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%s)"
    fi
    
    # Clonar repositorio
    log "INFO" "${BLUE}📥 Clonando repositorio desde GitHub...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
    
    if [ $? -ne 0 ]; then
        log "ERROR" "${RED}❌ Error clonando repositorio${NC}"
        exit 1
    fi
    
    cd "$INSTALL_DIR"
    
    # Cambiar a la rama especificada si no es main
    if [ "$REPO_BRANCH" != "main" ]; then
        git checkout "$REPO_BRANCH"
    fi
    
    # Hacer scripts ejecutables
    chmod +x scripts/*.sh
    chmod +x install.sh
    
    # Mostrar información del repositorio
    local commit_hash=$(git rev-parse --short HEAD)
    local commit_date=$(git show -s --format=%ci HEAD)
    log "INFO" "${GREEN}✅ Proyecto clonado - Commit: $commit_hash ($commit_date)${NC}"
    
    log "INFO" "${GREEN}✅ Estructura de proyecto configurada${NC}"
}

# Función para crear directorios del sistema
create_system_directories() {
    log "INFO" "${BLUE}📁 Creando directorios del sistema...${NC}"
    
    # Crear directorios necesarios
    mkdir -p /var/hls /var/dash /var/log/stream /etc/stream /var/www/stream
    mkdir -p /mnt/onedrive /mnt/gdrive /mnt/mega
    
    # Configurar permisos
    chown -R www-data:www-data /var/hls /var/dash /var/www/stream
    chmod 755 /var/hls /var/dash /var/www/stream
    chmod 755 /mnt/onedrive /mnt/gdrive /mnt/mega
    
    log "INFO" "${GREEN}✅ Directorios del sistema creados${NC}"
}

# Función para configurar firewall
configure_firewall() {
    log "INFO" "${BLUE}🛡️  Configurando firewall...${NC}"
    
    # Configurar UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir SSH (detectar puerto actual)
    local ssh_port=$(grep "^Port " /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
    ufw allow "$ssh_port"/tcp comment "SSH"
    
    # Permitir puertos del streaming
    ufw allow 80/tcp comment "HTTP"
    ufw allow 8080/tcp comment "Stream HTTP"
    ufw allow 1935/tcp comment "RTMP"
    
    # Habilitar firewall
    ufw --force enable
    
    log "INFO" "${GREEN}✅ Firewall configurado${NC}"
}

# Función para configurar fail2ban
configure_fail2ban() {
    log "INFO" "${BLUE}🔒 Configurando Fail2ban...${NC}"
    
    # Configuración básica de fail2ban
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log "INFO" "${GREEN}✅ Fail2ban configurado${NC}"
}

# Función para configurar logrotate
configure_logrotate() {
    log "INFO" "${BLUE}📋 Configurando rotación de logs...${NC}"
    
    cat > /etc/logrotate.d/lat-stream << EOF
/var/log/stream/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload multi-stream 2>/dev/null || true
    endscript
}

/var/log/rclone-*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    log "INFO" "${GREEN}✅ Rotación de logs configurada${NC}"
}

# Función para instalar servicios systemd
install_systemd_services() {
    log "INFO" "${BLUE}⚙️  Instalando servicios systemd...${NC}"
    
    # Copiar archivos de servicios desde el repositorio
    cd "$INSTALL_DIR"
    
    # Copiar servicios systemd
    cp systemd/*.service /etc/systemd/system/
    cp systemd/*.timer /etc/systemd/system/ 2>/dev/null || true
    
    # Copiar configuración de nginx
    cp nginx.conf /etc/nginx/nginx.conf
    
    # Copiar interfaz web
    cp -r web/* /var/www/stream/
    
    # Crear configuración por defecto del multi-stream
    mkdir -p /etc/stream
    if [ ! -f /etc/stream/config.conf ]; then
        $INSTALL_DIR/scripts/multi-stream.sh config
    fi
    
    systemctl daemon-reload
    
    # Habilitar servicios
    systemctl enable rclone-mount@onedrive 2>/dev/null || true
    systemctl enable rclone-mount@gdrive 2>/dev/null || true
    systemctl enable rclone-mount@mega 2>/dev/null || true
    systemctl enable multi-stream 2>/dev/null || true
    systemctl enable nginx-stream 2>/dev/null || true
    systemctl enable stream-cleanup.timer 2>/dev/null || true
    
    log "INFO" "${GREEN}✅ Servicios systemd configurados${NC}"
}

# Función para configurar monitoreo básico
setup_monitoring() {
    log "INFO" "${BLUE}📊 Configurando monitoreo básico...${NC}"
    
    # Script de estado del sistema
    cat > /usr/local/bin/lat-stream-status << 'EOF'
#!/bin/bash
echo "=== LAT Stream Status ==="
echo "Fecha: $(date)"
echo ""
echo "=== Servicios ==="
systemctl is-active multi-stream nginx-stream
echo ""
echo "=== Montajes ==="
df -h | grep /mnt
echo ""
echo "=== Procesos FFmpeg ==="
pgrep -af ffmpeg | wc -l
echo ""
echo "=== Uso de recursos ==="
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')"
echo "RAM: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
echo "Disco: $(df -h / | awk 'NR==2{printf "%s", $5}')"
EOF

    chmod +x /usr/local/bin/lat-stream-status
    
    # Cron para monitoreo (opcional)
    cat > /etc/cron.d/lat-stream-monitor << EOF
# LAT Stream monitoring (every 5 minutes)
*/5 * * * * root /usr/local/bin/lat-stream-status >> /var/log/stream/system-status.log 2>&1
EOF

    log "INFO" "${GREEN}✅ Monitoreo básico configurado${NC}"
}

# Función para mostrar configuración post-instalación
show_post_install_config() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   🎉 INSTALACIÓN COMPLETADA                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}📋 PASOS SIGUIENTES:${NC}"
    echo ""
    echo -e "${CYAN}1. Configurar Rclone:${NC}"
    echo "   cd $INSTALL_DIR"
    echo "   ./scripts/configure-rclone.sh"
    echo ""
    echo -e "${CYAN}2. Crear playlists de videos:${NC}"
    echo "   echo '/mnt/onedrive/video1.mp4' > /mnt/onedrive/playlist.txt"
    echo "   echo '/mnt/gdrive/video1.mp4' > /mnt/gdrive/playlist.txt"
    echo "   echo '/mnt/mega/video1.mp4' > /mnt/mega/playlist.txt"
    echo ""
    echo -e "${CYAN}3. Iniciar servicios:${NC}"
    echo "   systemctl start rclone-mount@onedrive"
    echo "   systemctl start rclone-mount@gdrive"
    echo "   systemctl start rclone-mount@mega"
    echo "   systemctl start nginx-stream"
    echo "   systemctl start multi-stream"
    echo ""
    echo -e "${CYAN}4. Verificar funcionamiento:${NC}"
    echo "   /usr/local/bin/lat-stream-status"
    echo "   journalctl -f -u multi-stream"
    echo ""
    echo -e "${CYAN}5. Acceder a la interfaz web:${NC}"
    echo "   http://$(curl -s ifconfig.me):8080"
    echo "   http://localhost:8080 (local)"
    echo ""
    echo -e "${YELLOW}📁 UBICACIONES IMPORTANTES:${NC}"
    echo "   Proyecto: $INSTALL_DIR"
    echo "   Logs: /var/log/stream/"
    echo "   Backup: $BACKUP_DIR"
    echo "   Configuración: /etc/stream/config.conf"
    echo ""
    echo -e "${YELLOW}🔧 COMANDOS ÚTILES:${NC}"
    echo "   Ver estado: lat-stream-status"
    echo "   Ver logs: tail -f /var/log/stream/multi-stream.log"
    echo "   Configurar stream: nano /etc/stream/config.conf"
    echo "   Reiniciar: systemctl restart multi-stream"
    echo "   Actualizar: cd $INSTALL_DIR && git pull && systemctl restart multi-stream"
    echo ""
    echo -e "${GREEN}✅ ¡Sistema listo para configurar Rclone y comenzar streaming!${NC}"
    echo ""
    echo -e "${BLUE}📚 Documentación completa: https://github.com/robertfenyiner/lat-team-stream${NC}"
}

# Función para limpiar en caso de error
cleanup_on_error() {
    log "ERROR" "${RED}❌ Error durante la instalación${NC}"
    echo ""
    echo -e "${YELLOW}📋 Para obtener ayuda:${NC}"
    echo "   1. Revisa el log: $LOG_FILE"
    echo "   2. Verifica los requisitos del sistema"
    echo "   3. Ejecuta nuevamente el instalador"
    echo ""
    echo -e "${YELLOW}📁 Backups disponibles en: $BACKUP_DIR${NC}"
    echo ""
    exit 1
}

# Función para verificar instalación
verify_installation() {
    log "INFO" "${BLUE}🔍 Verificando instalación...${NC}"
    
    local errors=0
    
    # Verificar comandos
    for cmd in ffmpeg nginx rclone; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "${RED}❌ $cmd no está instalado correctamente${NC}"
            ((errors++))
        fi
    done
    
    # Verificar directorios
    for dir in /var/hls /var/dash /var/log/stream /etc/stream; do
        if [ ! -d "$dir" ]; then
            log "ERROR" "${RED}❌ Directorio $dir no existe${NC}"
            ((errors++))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        log "INFO" "${GREEN}✅ Verificación exitosa${NC}"
        return 0
    else
        log "ERROR" "${RED}❌ Encontrados $errors errores${NC}"
        return 1
    fi
}

# Función principal
main() {
    # Configurar trap para cleanup en error
    trap cleanup_on_error ERR
    
    show_banner
    
    log "INFO" "${BLUE}🚀 Iniciando instalación de LAT Team Stream...${NC}"
    
    # Verificaciones iniciales
    check_requirements
    
    # Crear backup
    create_backup
    
    # Instalación paso a paso
    update_system
    install_basic_dependencies
    install_ffmpeg
    install_nginx
    install_rclone
    
    # Configuración del proyecto
    setup_project
    create_system_directories
    
    # Seguridad
    configure_firewall
    configure_fail2ban
    configure_logrotate
    
    # Servicios
    install_systemd_services
    
    # Monitoreo
    setup_monitoring
    
    # Verificación final
    if verify_installation; then
        show_post_install_config
    else
        log "ERROR" "${RED}❌ La instalación tiene errores${NC}"
        exit 1
    fi
    
    log "INFO" "${GREEN}🎉 ¡Instalación completada exitosamente!${NC}"
}

# Verificar argumentos
case "${1:-install}" in
    "install")
        main
        ;;
    "verify")
        verify_installation
        ;;
    "status")
        if [ -f /usr/local/bin/lat-stream-status ]; then
            /usr/local/bin/lat-stream-status
        else
            echo "Sistema no instalado"
            exit 1
        fi
        ;;
    "uninstall")
        echo -e "${YELLOW}🗑️  Función de desinstalación no implementada${NC}"
        echo "Para desinstalar manualmente:"
        echo "  systemctl stop multi-stream nginx-stream"
        echo "  systemctl disable multi-stream nginx-stream"
        echo "  rm -rf $INSTALL_DIR"
        echo "  apt remove nginx libnginx-mod-rtmp ffmpeg"
        ;;
    *)
        echo "Uso: $0 [install|verify|status|uninstall]"
        echo ""
        echo "Comandos:"
        echo "  install   - Instalar LAT Stream (por defecto)"
        echo "  verify    - Verificar instalación"
        echo "  status    - Mostrar estado del sistema"
        echo "  uninstall - Mostrar cómo desinstalar"
        exit 1
        ;;
esac