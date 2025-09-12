#!/usr/bin/env bash
# LAT Team Stream - Script de Actualización
# Actualiza el proyecto desde GitHub y reinicia servicios

set -euo pipefail

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Variables
PROJECT_DIR="/opt/lat-stream"
BACKUP_DIR="/root/lat-stream-backup-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}🔄 LAT Team Stream - Actualizador${NC}"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}❌ Proyecto no encontrado en $PROJECT_DIR${NC}"
    echo "Ejecuta primero el instalador"
    exit 1
fi

cd "$PROJECT_DIR"

# Verificar que es un repositorio git
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ No es un repositorio git válido${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Estado actual:${NC}"
git log --oneline -3
echo ""

# Crear backup de configuración
echo -e "${BLUE}💾 Creando backup...${NC}"
mkdir -p "$BACKUP_DIR"
cp -r /etc/stream/ "$BACKUP_DIR/" 2>/dev/null || true
cp -r /root/.config/rclone/ "$BACKUP_DIR/" 2>/dev/null || true
echo -e "${GREEN}✅ Backup creado en: $BACKUP_DIR${NC}"

# Verificar si hay cambios locales
if ! git diff --quiet HEAD; then
    echo -e "${YELLOW}⚠️  Hay cambios locales no commiteados${NC}"
    echo "¿Deseas continuar? Los cambios se perderán (y/N):"
    read -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Actualización cancelada"
        exit 0
    fi
    git stash
fi

# Actualizar desde GitHub
echo -e "${BLUE}📥 Descargando actualizaciones...${NC}"
git fetch origin
git reset --hard origin/main

# Mostrar cambios
echo -e "${BLUE}📋 Nuevos cambios:${NC}"
git log --oneline -5
echo ""

# Hacer scripts ejecutables
chmod +x scripts/*.sh
chmod +x install.sh

# Verificar si hay cambios en servicios systemd
if git diff HEAD~1 --name-only | grep -q "systemd/"; then
    echo -e "${YELLOW}🔄 Detectados cambios en servicios systemd${NC}"
    
    # Detener servicios
    systemctl stop multi-stream nginx-stream 2>/dev/null || true
    
    # Actualizar servicios
    cp systemd/*.service /etc/systemd/system/
    cp systemd/*.timer /etc/systemd/system/ 2>/dev/null || true
    
    systemctl daemon-reload
    
    echo -e "${GREEN}✅ Servicios systemd actualizados${NC}"
fi

# Verificar si hay cambios en nginx.conf
if git diff HEAD~1 --name-only | grep -q "nginx.conf"; then
    echo -e "${YELLOW}🔄 Detectados cambios en nginx.conf${NC}"
    
    # Hacer backup de nginx actual
    cp /etc/nginx/nginx.conf "$BACKUP_DIR/nginx.conf.old" 2>/dev/null || true
    
    # Verificar nueva configuración
    if nginx -t -c "$PROJECT_DIR/nginx.conf"; then
        cp nginx.conf /etc/nginx/nginx.conf
        echo -e "${GREEN}✅ Nginx configuración actualizada${NC}"
    else
        echo -e "${RED}❌ Error en nueva configuración de nginx${NC}"
        echo "Restaurando configuración anterior..."
        cp "$BACKUP_DIR/nginx.conf.old" /etc/nginx/nginx.conf 2>/dev/null || true
    fi
fi

# Actualizar interfaz web
if git diff HEAD~1 --name-only | grep -q "web/"; then
    echo -e "${YELLOW}🔄 Actualizando interfaz web${NC}"
    cp -r web/* /var/www/stream/
    echo -e "${GREEN}✅ Interfaz web actualizada${NC}"
fi

# Reiniciar servicios
echo -e "${BLUE}🔄 Reiniciando servicios...${NC}"

# Reiniciar nginx si está corriendo
if systemctl is-active --quiet nginx-stream; then
    systemctl restart nginx-stream
    echo -e "${GREEN}✅ nginx-stream reiniciado${NC}"
fi

# Reiniciar multi-stream si está corriendo
if systemctl is-active --quiet multi-stream; then
    systemctl restart multi-stream
    echo -e "${GREEN}✅ multi-stream reiniciado${NC}"
fi

# Verificar estado
echo ""
echo -e "${BLUE}📊 Estado después de la actualización:${NC}"

# Estado de servicios
echo -e "${BLUE}Servicios:${NC}"
systemctl is-active multi-stream nginx-stream 2>/dev/null || echo "Servicios no activos"

# Estado de montajes
echo -e "${BLUE}Montajes:${NC}"
df -h | grep /mnt || echo "No hay montajes activos"

# Test de conectividad
echo -e "${BLUE}Conectividad:${NC}"
if curl -s http://localhost:8080/health >/dev/null; then
    echo -e "${GREEN}✅ Servidor web responde correctamente${NC}"
else
    echo -e "${YELLOW}⚠️  Servidor web no responde${NC}"
fi

echo ""
echo -e "${GREEN}🎉 ¡Actualización completada!${NC}"
echo ""
echo -e "${BLUE}📋 Información útil:${NC}"
echo "  Backup: $BACKUP_DIR"
echo "  Logs: tail -f /var/log/stream/multi-stream.log"
echo "  Estado: lat-stream-status"
echo "  Web: http://$(curl -s ifconfig.me 2>/dev/null || echo 'tu-ip'):8080"
echo ""

# Mostrar versión/commit actual
echo -e "${BLUE}📍 Versión actual:${NC}"
git log --oneline -1

echo ""
echo -e "${GREEN}✅ Sistema actualizado y funcionando${NC}"