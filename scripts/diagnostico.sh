#!/usr/bin/env bash
# LAT Team Stream - Diagnóstico de Red y Sistema
# Ayuda a identificar problemas antes de la instalación

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
echo "║                🔍 LAT STREAM - DIAGNÓSTICO                   ║"
echo "║              Verificación de Sistema y Red                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Función de logging
log() {
    local level="$1"
    shift
    local message="$*"
    echo -e "[$(date '+%H:%M:%S')] [$level] $message"
}

# Verificar información del sistema
check_system_info() {
    log "INFO" "${BLUE}📋 Información del Sistema${NC}"
    echo ""
    
    echo -e "${BLUE}OS:${NC} $(lsb_release -d 2>/dev/null | cut -f2 || echo "Desconocido")"
    echo -e "${BLUE}Kernel:${NC} $(uname -r)"
    echo -e "${BLUE}Arquitectura:${NC} $(uname -m)"
    echo -e "${BLUE}Usuario actual:${NC} $(whoami) (UID: $EUID)"
    echo -e "${BLUE}Hostname:${NC} $(hostname)"
    echo -e "${BLUE}Uptime:${NC} $(uptime -p 2>/dev/null || uptime)"
    echo ""
    
    # Verificar Ubuntu 22.04
    if grep -q "22.04" /etc/lsb-release 2>/dev/null; then
        log "INFO" "${GREEN}✅ Ubuntu 22.04 detectado${NC}"
    else
        log "WARN" "${YELLOW}⚠️  No es Ubuntu 22.04 - puede haber problemas${NC}"
    fi
    
    # Verificar usuario root
    if [ "$EUID" -eq 0 ]; then
        log "INFO" "${GREEN}✅ Ejecutándose como root${NC}"
    else
        log "WARN" "${YELLOW}⚠️  No es root - necesitarás sudo${NC}"
    fi
    
    echo ""
}

# Verificar recursos del sistema
check_resources() {
    log "INFO" "${BLUE}💻 Recursos del Sistema${NC}"
    echo ""
    
    # RAM
    local ram_total=$(free -h | awk '/^Mem:/ {print $2}')
    local ram_used=$(free -h | awk '/^Mem:/ {print $3}')
    local ram_free=$(free -h | awk '/^Mem:/ {print $7}')
    echo -e "${BLUE}RAM:${NC} $ram_used / $ram_total (Disponible: $ram_free)"
    
    # Verificar RAM mínima
    local ram_mb=$(free -m | awk '/^Mem:/ {print $2}')
    if [ "$ram_mb" -lt 2048 ]; then
        log "WARN" "${YELLOW}⚠️  RAM insuficiente (< 2GB) - puede afectar rendimiento${NC}"
    else
        log "INFO" "${GREEN}✅ RAM suficiente${NC}"
    fi
    
    # CPU
    local cpu_cores=$(nproc)
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
    echo -e "${BLUE}CPU:${NC} $cpu_cores cores - $cpu_model"
    
    if [ "$cpu_cores" -lt 2 ]; then
        log "WARN" "${YELLOW}⚠️  Pocos cores de CPU (< 2) - considera calidad baja${NC}"
    else
        log "INFO" "${GREEN}✅ CPU adecuada${NC}"
    fi
    
    # Disco
    local disk_info=$(df -h / | tail -1)
    local disk_used=$(echo "$disk_info" | awk '{print $3}')
    local disk_avail=$(echo "$disk_info" | awk '{print $4}')
    local disk_percent=$(echo "$disk_info" | awk '{print $5}')
    echo -e "${BLUE}Disco /:${NC} $disk_used usado, $disk_avail disponible ($disk_percent)"
    
    local disk_avail_gb=$(df --output=avail / | tail -1)
    if [ "$disk_avail_gb" -lt 20971520 ]; then  # 20GB en KB
        log "WARN" "${YELLOW}⚠️  Poco espacio disponible (< 20GB)${NC}"
    else
        log "INFO" "${GREEN}✅ Espacio en disco suficiente${NC}"
    fi
    
    echo ""
}

# Verificar configuración de red
check_network_config() {
    log "INFO" "${BLUE}🌐 Configuración de Red${NC}"
    echo ""
    
    # Interfaces de red
    echo -e "${BLUE}Interfaces de red:${NC}"
    ip addr show | grep -E "^[0-9]+:|inet " | sed 's/^/  /'
    echo ""
    
    # Gateway
    echo -e "${BLUE}Gateway por defecto:${NC}"
    ip route show default | sed 's/^/  /' || echo "  No configurado"
    echo ""
    
    # DNS
    echo -e "${BLUE}Servidores DNS:${NC}"
    if [ -f /etc/resolv.conf ]; then
        grep nameserver /etc/resolv.conf | sed 's/^/  /' || echo "  No configurados"
    else
        echo "  /etc/resolv.conf no existe"
    fi
    echo ""
}

# Verificar conectividad de red
check_connectivity() {
    log "INFO" "${BLUE}🔗 Pruebas de Conectividad${NC}"
    echo ""
    
    # Función helper para probar conectividad
    test_connection() {
        local host="$1"
        local description="$2"
        local timeout=5
        
        echo -n "  Probando $description ($host)... "
        if ping -c 1 -W "$timeout" "$host" &> /dev/null; then
            echo -e "${GREEN}✅ OK${NC}"
            return 0
        else
            echo -e "${RED}❌ FALLO${NC}"
            return 1
        fi
    }
    
    # Variables para tracking
    local connectivity_issues=()
    local gateway_ok=false
    local dns_ok=false
    local internet_ok=false
    
    # Probar IP locales
    test_connection "127.0.0.1" "Loopback local"
    
    # Probar gateway
    local gateway=$(ip route show default | awk '{print $3}' | head -1)
    if [ -n "$gateway" ]; then
        if test_connection "$gateway" "Gateway ($gateway)"; then
            gateway_ok=true
        else
            connectivity_issues+=("GATEWAY")
        fi
    else
        echo "  ❌ No hay gateway configurado"
        connectivity_issues+=("NO_GATEWAY")
    fi
    
    # Solo continuar con pruebas externas si el gateway funciona
    if [ "$gateway_ok" = true ]; then
        # Probar DNS públicos
        if test_connection "8.8.8.8" "Google DNS"; then
            internet_ok=true
        else
            connectivity_issues+=("INTERNET")
        fi
        
        test_connection "1.1.1.1" "Cloudflare DNS"
        test_connection "208.67.222.222" "OpenDNS"
        
        echo ""
        
        # Probar resolución DNS
        echo "  Probando resolución DNS..."
        local dns_targets=("google.com" "github.com" "ubuntu.com")
        local dns_success=0
        
        for target in "${dns_targets[@]}"; do
            echo -n "    $target... "
            if nslookup "$target" &> /dev/null; then
                echo -e "${GREEN}✅ OK${NC}"
                ((dns_success++))
                dns_ok=true
            else
                echo -e "${RED}❌ FALLO${NC}"
            fi
        done
        
        if [ $dns_success -eq 0 ]; then
            connectivity_issues+=("DNS")
        fi
    else
        echo ""
        echo -e "${RED}  ⚠️  Saltando pruebas externas - Gateway no alcanzable${NC}"
        connectivity_issues+=("INTERNET" "DNS")
    fi
    
    echo ""
    
    # Diagnóstico específico basado en los problemas encontrados
    if [ ${#connectivity_issues[@]} -gt 0 ]; then
        log "ERROR" "${RED}🚨 Problemas de conectividad detectados${NC}"
        echo ""
        
        for issue in "${connectivity_issues[@]}"; do
            case $issue in
                "GATEWAY"|"NO_GATEWAY")
                    echo -e "${RED}📡 PROBLEMA DE GATEWAY:${NC}"
                    echo "   • No se puede alcanzar el gateway de red"
                    echo "   • Esto impide toda conectividad externa"
                    echo ""
                    echo -e "${YELLOW}🔧 SOLUCIONES:${NC}"
                    echo "   1. Verificar configuración de red:"
                    echo "      cat /etc/netplan/*.yaml"
                    echo ""
                    echo "   2. Verificar cable/enlace de red:"
                    echo "      ethtool eth0 | grep 'Link detected'"
                    echo "      ip link show eth0"
                    echo ""
                    echo "   3. Reiniciar interfaz de red:"
                    echo "      ip link set eth0 down && ip link set eth0 up"
                    echo ""
                    echo "   4. Reiniciar servicios de red:"
                    echo "      systemctl restart networking"
                    echo "      systemctl restart systemd-networkd"
                    echo ""
                    echo "   5. Verificar con el proveedor del VPS:"
                    echo "      - ¿El servidor está correctamente configurado?"
                    echo "      - ¿Hay problemas en la red del datacenter?"
                    echo ""
                    break
                    ;;
                "INTERNET")
                    if [ "$gateway_ok" = true ]; then
                        echo -e "${YELLOW}🌐 PROBLEMA DE INTERNET:${NC}"
                        echo "   • Gateway alcanzable, pero sin acceso a internet"
                        echo "   • Posible problema del proveedor o firewall"
                        echo ""
                        echo -e "${YELLOW}🔧 SOLUCIONES:${NC}"
                        echo "   1. Verificar firewall:"
                        echo "      iptables -L"
                        echo "      ufw status"
                        echo ""
                        echo "   2. Probar traceroute:"
                        echo "      traceroute 8.8.8.8"
                        echo ""
                        echo "   3. Contactar al proveedor del VPS"
                    fi
                    ;;
                "DNS")
                    if [ "$internet_ok" = true ]; then
                        echo -e "${BLUE}🔍 PROBLEMA DE DNS:${NC}"
                        echo "   • Internet funciona, pero DNS no resuelve"
                        echo ""
                        echo -e "${YELLOW}🔧 SOLUCIONES:${NC}"
                        echo "   1. Configurar DNS manualmente:"
                        echo "      echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
                        echo "      echo 'nameserver 1.1.1.1' >> /etc/resolv.conf"
                        echo ""
                        echo "   2. Reiniciar systemd-resolved:"
                        echo "      systemctl restart systemd-resolved"
                    fi
                    ;;
            esac
        done
        
        # Verificación específica para VPS
        echo -e "${BLUE}🖥️  VERIFICACIONES ESPECÍFICAS PARA VPS:${NC}"
        echo ""
        echo "1. Verificar estado del enlace físico:"
        echo "   ethtool eth0 2>/dev/null | grep -E 'Link detected|Speed|Duplex' || echo 'ethtool no disponible'"
        echo ""
        
        echo "2. Verificar configuración de red actual:"
        echo "   ip addr show eth0"
        echo "   ip route show"
        echo ""
        
        echo "3. Verificar configuración persistente:"
        echo "   ls -la /etc/netplan/"
        echo "   cat /etc/netplan/*.yaml 2>/dev/null || echo 'No hay archivos netplan'"
        echo ""
        
        echo "4. Ver logs de red:"
        echo "   journalctl -u networking --no-pager -n 20"
        echo "   journalctl -u systemd-networkd --no-pager -n 20"
        echo ""
        
        return 1
    else
        log "INFO" "${GREEN}✅ Todas las pruebas de conectividad pasaron${NC}"
        return 0
    fi
}

# Verificar puertos necesarios
check_ports() {
    log "INFO" "${BLUE}🔌 Verificación de Puertos${NC}"
    echo ""
    
    local ports=("22:SSH" "80:HTTP" "8080:Stream-HTTP" "1935:RTMP")
    
    for port_info in "${ports[@]}"; do
        IFS=':' read -r port desc <<< "$port_info"
        echo -n "  Puerto $port ($desc)... "
        
        if netstat -tlpn 2>/dev/null | grep -q ":$port "; then
            echo -e "${YELLOW}⚠️  EN USO${NC}"
            netstat -tlpn 2>/dev/null | grep ":$port " | sed 's/^/    /'
        else
            echo -e "${GREEN}✅ LIBRE${NC}"
        fi
    done
    
    echo ""
}

# Verificar dependencias básicas
check_basic_deps() {
    log "INFO" "${BLUE}📦 Dependencias Básicas${NC}"
    echo ""
    
    local deps=("curl" "wget" "git" "ping" "nslookup" "netstat")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        echo -n "  $dep... "
        if command -v "$dep" &> /dev/null; then
            echo -e "${GREEN}✅ Instalado${NC}"
        else
            echo -e "${RED}❌ No encontrado${NC}"
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        log "WARN" "${YELLOW}⚠️  Dependencias faltantes: ${missing_deps[*]}${NC}"
        echo "Instala con: apt update && apt install -y ${missing_deps[*]}"
    else
        log "INFO" "${GREEN}✅ Todas las dependencias básicas están instaladas${NC}"
    fi
    
    echo ""
}

# Verificar firewall
check_firewall() {
    log "INFO" "${BLUE}🛡️  Estado del Firewall${NC}"
    echo ""
    
    if command -v ufw &> /dev/null; then
        local ufw_status=$(ufw status 2>/dev/null | head -1)
        echo "  UFW: $ufw_status"
        
        if echo "$ufw_status" | grep -q "active"; then
            echo "  Reglas activas:"
            ufw status numbered 2>/dev/null | grep -E "^\[" | sed 's/^/    /'
        fi
    else
        echo "  UFW no está instalado"
    fi
    
    # Verificar iptables
    if command -v iptables &> /dev/null; then
        local iptables_rules=$(iptables -L 2>/dev/null | wc -l)
        echo "  iptables: $iptables_rules reglas configuradas"
    fi
    
    echo ""
}

# Función principal de diagnóstico
run_diagnosis() {
    check_system_info
    check_resources
    check_network_config
    check_connectivity
    check_ports
    check_basic_deps
    check_firewall
}

# Generar reporte
generate_report() {
    log "INFO" "${BLUE}📄 Generando reporte...${NC}"
    
    local report_file="/tmp/lat-stream-diagnostico-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "LAT Team Stream - Reporte de Diagnóstico"
        echo "Fecha: $(date)"
        echo "========================================"
        echo ""
        
        run_diagnosis
        
    } | tee "$report_file"
    
    echo ""
    log "INFO" "${GREEN}✅ Reporte guardado en: $report_file${NC}"
}

# Función de ayuda
show_help() {
    echo "LAT Team Stream - Diagnóstico de Sistema"
    echo ""
    echo "Uso: $0 [opción]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  -r, --report   Generar reporte completo"
    echo "  -q, --quick    Diagnóstico rápido"
    echo "  -n, --network  Solo verificar red"
    echo ""
}

# Procesar argumentos
case "${1:-}" in
    "-h"|"--help")
        show_help
        exit 0
        ;;
    "-r"|"--report")
        generate_report
        ;;
    "-q"|"--quick")
        check_system_info
        check_connectivity
        ;;
    "-n"|"--network")
        check_network_config
        check_connectivity
        ;;
    "")
        run_diagnosis
        ;;
    *)
        echo "Opción desconocida: $1"
        show_help
        exit 1
        ;;
esac

echo ""
log "INFO" "${GREEN}🏁 Diagnóstico completado${NC}"
echo ""
echo -e "${BLUE}💡 Si hay problemas de red:${NC}"
echo "   1. Verifica configuración: sudo nano /etc/netplan/00-installer-config.yaml"
echo "   2. Aplica cambios: sudo netplan apply"
echo "   3. Reinicia red: sudo systemctl restart networking"
echo "   4. Verifica DNS: sudo systemctl restart systemd-resolved"
echo ""
echo -e "${BLUE}�️  SOLUCIÓN RÁPIDA PARA PROBLEMA DE GATEWAY:${NC}"
echo "   # Si el gateway no responde, intenta:"
echo "   systemctl restart networking"
echo "   systemctl restart systemd-networkd"
echo "   ip link set eth0 down && ip link set eth0 up"
echo ""
echo -e "${BLUE}�📚 Para continuar con la instalación:${NC}"
echo "   # Después de arreglar la red:"
echo "   curl -fsSL https://raw.githubusercontent.com/robertfenyiner/lat-team-stream/main/install.sh | bash"
echo ""
echo "   # O si no puedes arreglar la red:"
echo "   curl -fsSL https://raw.githubusercontent.com/robertfenyiner/lat-team-stream/main/install.sh | bash -s -- --skip-network"