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
OFFLINE_MODE=false
SKIP_NETWORK_CHECK=false

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
    
# Función para verificar requisitos
check_requirements() {
    log "INFO" "${BLUE}🔍 Verificando requisitos del sistema...${NC}"
    
    # Verificar Ubuntu 22.04
    if ! grep -q "22.04" /etc/lsb-release 2>/dev/null; then
        log "WARN" "${YELLOW}⚠️  Este script está optimizado para Ubuntu 22.04 LTS${NC}"
        echo "Sistema detectado: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Desconocido")"
        read -p "¿Continuar de todas formas? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Verificar usuario root
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "${RED}❌ Este script debe ejecutarse como root${NC}"
        echo "Ejecuta con: sudo $0"
        exit 1
    fi
    
    # Verificar conexión a internet (solo si no se omite)
    if [ "$SKIP_NETWORK_CHECK" = false ]; then
        log "INFO" "${BLUE}🌐 Verificando conexión a internet...${NC}"
        
        # Función para probar conectividad
        test_connectivity() {
            local host="$1"
            local description="$2"
            
            if ping -c 1 -W 5 "$host" &> /dev/null; then
                log "INFO" "${GREEN}✅ Conectividad OK - $description${NC}"
                return 0
            else
                log "WARN" "${YELLOW}⚠️  No se puede conectar a $description ($host)${NC}"
                return 1
            fi
        }
        
        # Probar múltiples servidores
        connectivity_ok=false
        
        # Probar Google DNS
        if test_connectivity "8.8.8.8" "Google DNS"; then
            connectivity_ok=true
        fi
        
        # Probar Cloudflare DNS si Google falla
        if [ "$connectivity_ok" = false ] && test_connectivity "1.1.1.1" "Cloudflare DNS"; then
            connectivity_ok=true
        fi
        
        # Probar resolución DNS
        if [ "$connectivity_ok" = true ]; then
            if nslookup google.com &> /dev/null; then
                log "INFO" "${GREEN}✅ Resolución DNS funcionando${NC}"
            else
                log "WARN" "${YELLOW}⚠️  Problemas con resolución DNS${NC}"
            fi
        fi
        
        # Si no hay conectividad, dar opciones
        if [ "$connectivity_ok" = false ]; then
            log "ERROR" "${RED}❌ No se puede verificar conexión a internet${NC}"
            echo ""
            echo -e "${YELLOW}💡 Opciones disponibles:${NC}"
            echo "   1. Verificar y arreglar la red, luego reintentar"
            echo "   2. Ejecutar diagnóstico: bash <(wget -qO- https://raw.githubusercontent.com/robertfenyiner/lat-team-stream/main/scripts/diagnostico.sh)"
            echo "   3. Continuar sin verificar red (puede fallar)"
            echo "   4. Usar modo offline (requiere archivos locales)"
            echo ""
            echo -e "${BLUE}Comandos de diagnóstico rápido:${NC}"
            echo "   • ip addr show"
            echo "   • ip route show"
            echo "   • cat /etc/resolv.conf"
            echo "   • systemctl restart networking"
            echo ""
            
            read -p "¿Qué deseas hacer? (1=Salir, 2=Diagnóstico, 3=Continuar, 4=Offline): " -n 1 -r
            echo
            case $REPLY in
                1|""|"N"|"n")
                    log "INFO" "${BLUE}Instalación cancelada. Arregla la red y reintenta.${NC}"
                    exit 0
                    ;;
                2)
                    log "INFO" "${BLUE}Ejecutando diagnóstico...${NC}"
                    bash <(curl -fsSL https://raw.githubusercontent.com/robertfenyiner/lat-team-stream/main/scripts/diagnostico.sh) || {
                        echo "No se pudo descargar el diagnóstico. Verifica la conectividad."
                        exit 1
                    }
                    exit 0
                    ;;
                3|"Y"|"y")
                    log "WARN" "${YELLOW}⚠️  Continuando sin verificar conectividad${NC}"
                    SKIP_NETWORK_CHECK=true
                    ;;
                4)
                    log "INFO" "${BLUE}Activando modo offline${NC}"
                    OFFLINE_MODE=true
                    SKIP_NETWORK_CHECK=true
                    ;;
                *)
                    log "ERROR" "${RED}Opción inválida${NC}"
                    exit 1
                    ;;
            esac
        fi
    fi
    
    # Verificar espacio en disco (mínimo 20GB)
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 20971520 ]; then  # 20GB in KB
        log "WARN" "${YELLOW}⚠️  Espacio en disco bajo. Se recomiendan al menos 20GB libres${NC}"
        echo "Disponible: $(df -h / | tail -1 | awk '{print $4}')"
        read -p "¿Continuar de todas formas? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "INFO" "${GREEN}✅ Requisitos del sistema verificados${NC}"
}
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
    
    # Intentar instalar FFmpeg del repositorio oficial primero
    log "INFO" "${BLUE}📦 Intentando instalación desde repositorio oficial...${NC}"
    if apt install -y -qq ffmpeg; then
        local version=$(ffmpeg -version 2>&1 | head -n1 | cut -d' ' -f3)
        log "INFO" "${GREEN}✅ FFmpeg instalado desde repositorio oficial: $version${NC}"
        return 0
    fi
    
    # Si falla, intentar agregar PPA con FFmpeg más reciente
    log "INFO" "${BLUE}📦 Intentando PPA de FFmpeg...${NC}"
    
    # Agregar repositorio para FFmpeg actualizado
    if add-apt-repository ppa:savoury1/ffmpeg4 -y; then
        apt update -qq
        
        # Instalar FFmpeg del PPA
        if apt install -y -qq ffmpeg; then
            local version=$(ffmpeg -version 2>&1 | head -n1 | cut -d' ' -f3)
            log "INFO" "${GREEN}✅ FFmpeg instalado desde PPA: $version${NC}"
            return 0
        fi
    fi
    
    # Si todo falla, mostrar error y sugerencias
    log "ERROR" "${RED}❌ Error instalando FFmpeg${NC}"
    echo ""
    echo -e "${YELLOW}💡 Soluciones alternativas:${NC}"
    echo "   1. Instalar manualmente:"
    echo "      apt update && apt install ffmpeg"
    echo ""
    echo "   2. Compilar desde fuente:"
    echo "      https://ffmpeg.org/download.html#build-linux"
    echo ""
    echo "   3. Usar snap:"
    echo "      snap install ffmpeg"
    echo ""
    
    read -p "¿Continuar sin FFmpeg? (NO recomendado) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "WARN" "${YELLOW}⚠️  Continuando sin FFmpeg - el streaming no funcionará${NC}"
        return 0
    else
        exit 1
    fi
}

# Función para instalar nginx-rtmp
install_nginx_rtmp() {
    log "INFO" "${BLUE}🌐 Instalando nginx y nginx-rtmp...${NC}"
    
    # Intentar instalación estándar
    if apt install -y -qq nginx libnginx-mod-rtmp; then
        log "INFO" "${GREEN}✅ nginx-rtmp instalado desde repositorio oficial${NC}"
    else
        log "WARN" "${YELLOW}⚠️  nginx-rtmp no disponible en repositorio oficial${NC}"
        log "INFO" "${BLUE}📦 Intentando nginx básico + compilación manual...${NC}"
        
        # Instalar nginx básico
        if ! apt install -y -qq nginx; then
            log "ERROR" "${RED}❌ Error instalando nginx básico${NC}"
            echo ""
            echo -e "${YELLOW}💡 Instalar manualmente:${NC}"
            echo "   apt install nginx"
            exit 1
        fi
        
        # Instalar dependencias para compilar nginx-rtmp
        apt install -y -qq build-essential libpcre3-dev libssl-dev zlib1g-dev
        
        # Crear directorio temporal
        mkdir -p /tmp/nginx-rtmp-build
        cd /tmp/nginx-rtmp-build
        
        log "INFO" "${BLUE}📥 Descargando nginx-rtmp-module...${NC}"
        if wget -q https://github.com/arut/nginx-rtmp-module/archive/master.zip; then
            unzip -q master.zip
            
            # Obtener versión de nginx instalada
            local nginx_version=$(nginx -v 2>&1 | cut -d'/' -f2)
            
            log "INFO" "${BLUE}📥 Descargando código fuente de nginx $nginx_version...${NC}"
            if wget -q http://nginx.org/download/nginx-$nginx_version.tar.gz; then
                tar -xzf nginx-$nginx_version.tar.gz
                cd nginx-$nginx_version
                
                # Obtener configuración actual de nginx
                local nginx_config=$(nginx -V 2>&1 | grep "configure arguments" | cut -d: -f2-)
                
                log "INFO" "${BLUE}🔧 Compilando nginx con módulo RTMP...${NC}"
                ./configure $nginx_config --add-dynamic-module=../nginx-rtmp-module-master
                
                if make modules; then
                    # Copiar módulo compilado
                    cp objs/ngx_rtmp_module.so /usr/lib/nginx/modules/
                    
                    # Agregar carga del módulo a nginx.conf
                    if ! grep -q "load_module.*ngx_rtmp_module" /etc/nginx/nginx.conf; then
                        sed -i '1i load_module modules/ngx_rtmp_module.so;' /etc/nginx/nginx.conf
                    fi
                    
                    log "INFO" "${GREEN}✅ nginx-rtmp compilado e instalado${NC}"
                else
                    log "ERROR" "${RED}❌ Error compilando nginx-rtmp${NC}"
                    manual_rtmp_instructions
                fi
            else
                log "ERROR" "${RED}❌ Error descargando código fuente de nginx${NC}"
                manual_rtmp_instructions
            fi
        else
            log "ERROR" "${RED}❌ Error descargando nginx-rtmp-module${NC}"
            manual_rtmp_instructions
        fi
        
        # Limpiar
        cd /
        rm -rf /tmp/nginx-rtmp-build
    fi
    
    # Verificar instalación
    if nginx -V 2>&1 | grep -q rtmp; then
        log "INFO" "${GREEN}✅ nginx-rtmp configurado correctamente${NC}"
    else
        log "WARN" "${YELLOW}⚠️  nginx-rtmp podría no estar disponible${NC}"
        echo ""
        echo -e "${YELLOW}💡 El streaming básico seguirá funcionando con HLS${NC}"
    fi
}

manual_rtmp_instructions() {
    echo ""
    echo -e "${YELLOW}💡 Instalación manual de nginx-rtmp:${NC}"
    echo "   1. Seguir guía oficial:"
    echo "      https://github.com/arut/nginx-rtmp-module"
    echo ""
    echo "   2. Usar Docker (alternativa):"
    echo "      docker run -d -p 1935:1935 -p 8080:8080 tiangolo/nginx-rtmp"
    echo ""
    read -p "¿Continuar sin nginx-rtmp? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
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
    local exit_code=$?
    log "ERROR" "${RED}❌ Error durante la instalación (código: $exit_code)${NC}"
    echo ""
    echo -e "${YELLOW}� DIAGNÓSTICO RÁPIDO:${NC}"
    
    # Mostrar información básica del error
    case $exit_code in
        1)
            echo "   • Error general - revisa los logs arriba"
            ;;
        127)
            echo "   • Comando no encontrado - verifica dependencias"
            ;;
        130)
            echo "   • Instalación cancelada por el usuario"
            ;;
        *)
            echo "   • Error inesperado ($exit_code)"
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}🛠️  SOLUCIONES SUGERIDAS:${NC}"
    echo "   1. Ejecutar diagnóstico:"
    echo "      wget -O- https://raw.githubusercontent.com/robertfenyiner/lat-team-stream/main/scripts/diagnostico.sh | bash"
    echo ""
    echo "   2. Verificar conexión de red:"
    echo "      ping -c 3 8.8.8.8"
    echo "      nslookup google.com"
    echo ""
    echo "   3. Actualizar sistema:"
    echo "      apt update && apt upgrade -y"
    echo ""
    echo "   4. Revisar espacio en disco:"
    echo "      df -h"
    echo ""
    echo -e "${YELLOW}📋 Para obtener ayuda:${NC}"
    echo "   1. Revisa el log completo: $LOG_FILE"
    echo "   2. Crea un issue en: https://github.com/robertfenyiner/lat-team-stream/issues"
    echo "   3. Incluye la salida del diagnóstico y este log"
    echo ""
    echo -e "${YELLOW}📁 Backups disponibles en: $BACKUP_DIR${NC}"
    echo ""
    
    # Limpiar archivos temporales si existen
    if [ -d "/tmp/lat-stream-install" ]; then
        rm -rf "/tmp/lat-stream-install" 2>/dev/null || true
    fi
    
    exit $exit_code
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
    install_nginx_rtmp
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
    "diagnosis"|"diag")
        # Ejecutar diagnóstico
        if [ -f "scripts/diagnostico.sh" ]; then
            bash scripts/diagnostico.sh
        else
            echo "Descargando diagnóstico..."
            bash <(curl -fsSL https://raw.githubusercontent.com/robertfenyiner/lat-team-stream/main/scripts/diagnostico.sh)
        fi
        ;;
    "--skip-network"|"-n")
        SKIP_NETWORK_CHECK=true
        main
        ;;
    "--offline"|"-o")
        OFFLINE_MODE=true
        SKIP_NETWORK_CHECK=true
        main
        ;;
    "uninstall")
        echo -e "${YELLOW}🗑️  Desinstalación de LAT Stream${NC}"
        echo ""
        read -p "¿Estás seguro? Esto eliminará todos los archivos (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Deteniendo servicios..."
            systemctl stop multi-stream nginx-stream 2>/dev/null || true
            systemctl disable multi-stream nginx-stream 2>/dev/null || true
            
            echo "Eliminando archivos..."
            rm -rf "$INSTALL_DIR" /var/hls /var/dash /var/www/stream /etc/stream
            rm -f /etc/systemd/system/multi-stream.service /etc/systemd/system/nginx-stream.service
            rm -f /etc/systemd/system/rclone-mount@.service /etc/systemd/system/stream-cleanup.*
            
            systemctl daemon-reload
            
            echo -e "${GREEN}✅ LAT Stream desinstalado${NC}"
        else
            echo "Desinstalación cancelada"
        fi
        ;;
    "--help"|"-h"|"help")
        echo "LAT Team Stream - Instalador v2.0"
        echo ""
        echo "Uso: $0 [opción]"
        echo ""
        echo "Opciones:"
        echo "  install            Instalar LAT Stream (por defecto)"
        echo "  verify             Verificar instalación existente"
        echo "  status             Mostrar estado del sistema"
        echo "  diagnosis, diag    Ejecutar diagnóstico del sistema"
        echo "  --skip-network, -n Omitir verificación de red"
        echo "  --offline, -o      Modo offline (requiere archivos locales)"
        echo "  uninstall          Desinstalar completamente"
        echo "  --help, -h         Mostrar esta ayuda"
        echo ""
        echo "Ejemplos:"
        echo "  $0                 # Instalación normal"
        echo "  $0 -n              # Instalar omitiendo verificación de red"
        echo "  $0 diagnosis       # Solo ejecutar diagnóstico"
        echo "  $0 status          # Ver estado del sistema"
        echo ""
        ;;
    *)
        echo "Opción desconocida: $1"
        echo "Usa '$0 --help' para ver opciones disponibles"
        exit 1
        ;;
esac