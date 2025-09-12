#!/usr/bin/env bash
# LAT Team Stream - Solucionador de Problemas de Red
# Automatiza la solución de problemas comunes de conectividad

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              🔧 LAT STREAM - REPARAR RED                     ║"
echo "║            Solucionador Automático de Red                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Verificar que somos root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Función de logging
log() {
    local level="$1"
    shift
    local message="$*"
    echo -e "[$(date '+%H:%M:%S')] [$level] $message"
}

# Función para probar conectividad
test_ping() {
    local host="$1"
    local description="$2"
    
    echo -n "  Probando $description ($host)... "
    if ping -c 1 -W 3 "$host" &> /dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FALLO${NC}"
        return 1
    fi
}

# Diagnóstico inicial
initial_diagnosis() {
    log "INFO" "${BLUE}🔍 Diagnóstico inicial de red...${NC}"
    echo ""
    
    # Información básica
    echo -e "${BLUE}Configuración actual:${NC}"
    echo "  IP: $(ip addr show eth0 | grep 'inet ' | awk '{print $2}' || echo "No configurada")"
    echo "  Gateway: $(ip route show default | awk '{print $3}' || echo "No configurado")"
    echo "  DNS: $(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ' || echo "No configurado")"
    echo ""
    
    # Probar conectividad básica
    local gateway=$(ip route show default | awk '{print $3}' | head -1)
    local gateway_ok=false
    local internet_ok=false
    
    test_ping "127.0.0.1" "Loopback"
    
    if [ -n "$gateway" ]; then
        if test_ping "$gateway" "Gateway"; then
            gateway_ok=true
            if test_ping "8.8.8.8" "Internet"; then
                internet_ok=true
            fi
        fi
    else
        echo "  ❌ No hay gateway configurado"
    fi
    
    echo ""
    
    # Determinar el problema
    if [ "$gateway_ok" = false ]; then
        return 1  # Problema de gateway
    elif [ "$internet_ok" = false ]; then
        return 2  # Problema de internet
    else
        return 0  # Todo OK
    fi
}

# Solución 1: Reiniciar servicios de red
restart_network_services() {
    log "INFO" "${BLUE}🔄 Reiniciando servicios de red...${NC}"
    
    echo "  Deteniendo servicios..."
    systemctl stop networking 2>/dev/null || true
    systemctl stop systemd-networkd 2>/dev/null || true
    
    sleep 2
    
    echo "  Reiniciando interfaz..."
    ip link set eth0 down 2>/dev/null || true
    sleep 1
    ip link set eth0 up 2>/dev/null || true
    
    sleep 2
    
    echo "  Iniciando servicios..."
    systemctl start systemd-networkd 2>/dev/null || true
    systemctl start networking 2>/dev/null || true
    
    sleep 3
    
    echo "  Reiniciando systemd-resolved..."
    systemctl restart systemd-resolved 2>/dev/null || true
    
    sleep 2
    
    log "INFO" "${GREEN}✅ Servicios reiniciados${NC}"
}

# Solución 2: Reconfigurar red con DHCP
reconfigure_dhcp() {
    log "INFO" "${BLUE}🌐 Reconfigurando red con DHCP...${NC}"
    
    # Crear backup de configuración actual
    local backup_dir="/root/network-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    if [ -d /etc/netplan ]; then
        cp -r /etc/netplan "$backup_dir/" 2>/dev/null || true
    fi
    
    # Crear configuración DHCP básica
    cat > /etc/netplan/01-network-manager-all.yaml << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
      optional: true
EOF
    
    echo "  Aplicando configuración..."
    netplan apply
    
    sleep 5
    
    log "INFO" "${GREEN}✅ Red reconfigurada${NC}"
    echo "  Backup guardado en: $backup_dir"
}

# Solución 3: Configurar DNS manualmente
fix_dns() {
    log "INFO" "${BLUE}🔍 Configurando DNS...${NC}"
    
    # Backup de resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true
    
    # Configurar DNS público
    cat > /etc/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 208.67.222.222
EOF
    
    # Reiniciar systemd-resolved
    systemctl restart systemd-resolved 2>/dev/null || true
    
    log "INFO" "${GREEN}✅ DNS configurado${NC}"
}

# Solución 4: Verificar y arreglar hardware
check_hardware() {
    log "INFO" "${BLUE}🔌 Verificando hardware de red...${NC}"
    
    # Verificar si ethtool está disponible
    if command -v ethtool &> /dev/null; then
        echo "  Estado del enlace:"
        ethtool eth0 | grep -E "Link detected|Speed|Duplex" | sed 's/^/    /'
        
        # Si el enlace está down, intentar activarlo
        if ethtool eth0 | grep -q "Link detected: no"; then
            echo "  Enlace detectado como down, intentando activar..."
            ip link set eth0 down
            sleep 1
            ip link set eth0 up
            sleep 2
            
            # Verificar de nuevo
            if ethtool eth0 | grep -q "Link detected: yes"; then
                log "INFO" "${GREEN}✅ Enlace activado${NC}"
            else
                log "WARN" "${YELLOW}⚠️  Enlace sigue down - posible problema de hardware${NC}"
            fi
        fi
    else
        echo "  ethtool no disponible, instalando..."
        apt update -qq && apt install -y ethtool 2>/dev/null || true
    fi
}

# Función principal de reparación
repair_network() {
    echo "Iniciando proceso de reparación automática..."
    echo ""
    
    # Paso 1: Diagnóstico inicial
    initial_diagnosis
    local diagnosis_result=$?
    
    case $diagnosis_result in
        0)
            log "INFO" "${GREEN}✅ Red funcionando correctamente${NC}"
            return 0
            ;;
        1)
            log "WARN" "${YELLOW}⚠️  Problema de gateway detectado${NC}"
            ;;
        2)
            log "WARN" "${YELLOW}⚠️  Problema de internet detectado${NC}"
            ;;
    esac
    
    # Paso 2: Verificar hardware
    check_hardware
    sleep 2
    
    # Paso 3: Reiniciar servicios
    restart_network_services
    sleep 3
    
    # Verificar si se solucionó
    log "INFO" "${BLUE}🔍 Verificando reparación...${NC}"
    initial_diagnosis
    if [ $? -eq 0 ]; then
        log "INFO" "${GREEN}🎉 ¡Red reparada exitosamente!${NC}"
        return 0
    fi
    
    # Paso 4: Reconfigurar con DHCP
    log "INFO" "${BLUE}🔧 Intentando reconfiguración DHCP...${NC}"
    reconfigure_dhcp
    sleep 5
    
    # Verificar de nuevo
    initial_diagnosis
    if [ $? -eq 0 ]; then
        log "INFO" "${GREEN}🎉 ¡Red reparada con DHCP!${NC}"
        return 0
    fi
    
    # Paso 5: Arreglar DNS
    log "INFO" "${BLUE}🔧 Intentando arreglar DNS...${NC}"
    fix_dns
    sleep 3
    
    # Verificar final
    if test_ping "8.8.8.8" "Internet final" && nslookup google.com &>/dev/null; then
        log "INFO" "${GREEN}🎉 ¡Red completamente reparada!${NC}"
        return 0
    else
        log "ERROR" "${RED}❌ No se pudo reparar automáticamente${NC}"
        return 1
    fi
}

# Función para mostrar estado actual
show_status() {
    echo -e "${BLUE}📊 Estado actual de la red:${NC}"
    echo ""
    
    echo "Interfaces:"
    ip addr show | grep -E "^[0-9]+:|inet " | sed 's/^/  /'
    echo ""
    
    echo "Rutas:"
    ip route show | sed 's/^/  /'
    echo ""
    
    echo "DNS:"
    cat /etc/resolv.conf | grep nameserver | sed 's/^/  /'
    echo ""
    
    echo "Pruebas de conectividad:"
    test_ping "127.0.0.1" "Loopback"
    
    local gateway=$(ip route show default | awk '{print $3}' | head -1)
    if [ -n "$gateway" ]; then
        test_ping "$gateway" "Gateway"
    fi
    
    test_ping "8.8.8.8" "Internet"
    
    echo -n "  Resolución DNS... "
    if nslookup google.com &>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FALLO${NC}"
    fi
}

# Menú principal
main_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}🔧 ¿Qué deseas hacer?${NC}"
        echo "1) Diagnóstico y estado actual"
        echo "2) Reparación automática completa"
        echo "3) Solo reiniciar servicios de red"
        echo "4) Solo reconfigurar DHCP"
        echo "5) Solo arreglar DNS"
        echo "6) Verificar hardware de red"
        echo "7) Salir"
        echo ""
        
        read -p "Selecciona una opción (1-7): " choice
        
        case $choice in
            1)
                show_status
                ;;
            2)
                repair_network
                if [ $? -eq 0 ]; then
                    echo ""
                    echo -e "${GREEN}🎉 ¡Red reparada! Ahora puedes continuar con la instalación:${NC}"
                    echo "curl -fsSL https://raw.githubusercontent.com/robertfenyiner/lat-team-stream/main/install.sh | bash"
                    break
                fi
                ;;
            3)
                restart_network_services
                ;;
            4)
                reconfigure_dhcp
                ;;
            5)
                fix_dns
                ;;
            6)
                check_hardware
                ;;
            7)
                echo -e "${GREEN}¡Hasta luego!${NC}"
                break
                ;;
            *)
                echo -e "${RED}Opción inválida${NC}"
                ;;
        esac
    done
}

# Ejecutar menú principal o comando directo
case "${1:-menu}" in
    "menu"|"")
        show_status
        main_menu
        ;;
    "repair"|"fix")
        repair_network
        ;;
    "status")
        show_status
        ;;
    "restart")
        restart_network_services
        ;;
    "dhcp")
        reconfigure_dhcp
        ;;
    "dns")
        fix_dns
        ;;
    "--help"|"-h")
        echo "LAT Stream - Reparador de Red"
        echo ""
        echo "Uso: $0 [comando]"
        echo ""
        echo "Comandos:"
        echo "  menu     Mostrar menú interactivo (por defecto)"
        echo "  repair   Reparación automática completa"
        echo "  status   Mostrar estado actual"
        echo "  restart  Solo reiniciar servicios"
        echo "  dhcp     Solo reconfigurar DHCP"
        echo "  dns      Solo arreglar DNS"
        echo ""
        ;;
    *)
        echo "Comando desconocido: $1"
        echo "Usa '$0 --help' para ver opciones"
        exit 1
        ;;
esac