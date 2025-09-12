# 📚 LAT Team Stream - Guía de Instalación Completa

Esta guía te ayudará a instalar y configurar el sistema de streaming multi-fuente en tu VPS Ubuntu 22.04.

## 🚀 Instalación Rápida (Recomendada)

### Método 1: Instalador Automático desde GitHub

```bash
# Conectar a tu VPS
ssh root@tu-ip-vps

# Descargar e ejecutar instalador
curl -fsSL https://raw.githubusercontent.com/robertfenyiner/lat-team-stream/main/install.sh | bash
```

### Método 2: Clonación Manual + Instalador

```bash
# Conectar a tu VPS
ssh root@tu-ip-vps

# Clonar repositorio
git clone https://github.com/robertfenyiner/lat-team-stream.git /tmp/lat-stream
cd /tmp/lat-stream

# Ejecutar instalador
chmod +x install.sh
./install.sh
```

## 📋 Requisitos Previos

### Sistema
- **OS**: Ubuntu 22.04 LTS
- **Usuario**: root o sudo
- **RAM**: Mínimo 2GB (recomendado 4GB+)
- **CPU**: 2 cores mínimo
- **Disco**: 20GB libres mínimo
- **Red**: Conexión estable a internet

### Cuentas de Nube
- OneDrive (Microsoft)
- Google Drive
- MEGA
- Al menos una cuenta configurada
- **RAM**: Mínimo 2GB, recomendado 4GB+
- **Almacenamiento**: 20GB+ libres
- **Ancho de banda**: 10 Mbps+ subida para streaming de calidad
- **CPU**: 2+ cores recomendado

## 🚀 Instalación Rápida

### 1. Preparación del Sistema

```bash
# Actualizar sistema
apt update && apt upgrade -y

# Instalar dependencias básicas
apt install -y curl wget git unzip software-properties-common

# Instalar fuse para rclone
apt install -y fuse

# Permitir montajes para usuarios no privilegiados
echo 'user_allow_other' >> /etc/fuse.conf
```

### 2. Instalar FFmpeg

```bash
# Agregar repositorio para FFmpeg actualizado
add-apt-repository ppa:savoury1/ffmpeg4 -y
apt update

# Instalar FFmpeg
apt install -y ffmpeg

# Verificar instalación
ffmpeg -version
```

### 3. Instalar Nginx con módulo RTMP

```bash
# Instalar Nginx y módulo RTMP
apt install -y nginx libnginx-mod-rtmp

# Verificar instalación
nginx -V 2>&1 | grep -o with-http_ssl_module
nginx -V 2>&1 | grep -o rtmp
```

### 4. Instalar Rclone

```bash
# Instalar rclone
curl https://rclone.org/install.sh | bash

# Verificar instalación
rclone version
```

### 5. Clonar y Configurar el Proyecto

```bash
# Crear directorio de proyecto
mkdir -p /opt/lat-stream
cd /opt/lat-stream

# Clonar repositorio (o subir archivos manualmente)
git clone https://github.com/robertfenyiner/lat-team-stream.git .

# O si subes archivos manualmente:
# scp -r /ruta/local/lat-team-stream/* root@tu-ip:/opt/lat-stream/

# Hacer scripts ejecutables
chmod +x scripts/*.sh
```

### 6. Configurar Rclone

```bash
# Ejecutar configurador interactivo
./scripts/configure-rclone.sh
```

Sigue las instrucciones del script para configurar:
- **OneDrive**: Autenticación OAuth
- **Google Drive**: Autenticación OAuth  
- **MEGA**: Email y contraseña

### 7. Crear Directorios del Sistema

```bash
# Crear directorios necesarios
mkdir -p /var/hls /var/dash /var/log/stream /etc/stream /var/www/stream

# Permisos adecuados
chown -R www-data:www-data /var/hls /var/dash /var/www/stream
chmod 755 /var/hls /var/dash /var/www/stream
```

### 8. Configurar Servicios Systemd

```bash
# Copiar servicios systemd
cp systemd/*.service /etc/systemd/system/
cp systemd/*.timer /etc/systemd/system/

# Recargar systemd
systemctl daemon-reload

# Habilitar servicios de montaje
systemctl enable rclone-mount@onedrive
systemctl enable rclone-mount@gdrive
systemctl enable rclone-mount@mega

# Habilitar servicios principales
systemctl enable multi-stream
systemctl enable nginx-stream
systemctl enable stream-cleanup.timer
```

### 9. Configurar Nginx

```bash
# Hacer backup de configuración original
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

# Copiar nueva configuración
cp nginx.conf /etc/nginx/nginx.conf

# Verificar configuración
nginx -t

# Si hay error, usar configuración dedicada:
# cp nginx.conf /etc/nginx/sites-available/stream
# ln -s /etc/nginx/sites-available/stream /etc/nginx/sites-enabled/
# systemctl restart nginx
```

### 10. Configurar Interfaz Web

```bash
# Copiar archivos web
cp web/* /var/www/stream/

# Permisos
chown -R www-data:www-data /var/www/stream
chmod -R 644 /var/www/stream/*
```

### 11. Crear Configuración de Stream

```bash
# Generar configuración por defecto
/opt/lat-stream/scripts/multi-stream.sh config

# Editar configuración según tus necesidades
nano /etc/stream/config.conf
```

### 12. Crear Playlists de Ejemplo

```bash
# Crear playlist para OneDrive
mkdir -p /mnt/onedrive
echo "/mnt/onedrive/video1.mp4" > /mnt/onedrive/playlist.txt
echo "/mnt/onedrive/video2.mp4" >> /mnt/onedrive/playlist.txt

# Repetir para otras fuentes...
```

### 13. Iniciar Servicios

```bash
# Iniciar montajes
systemctl start rclone-mount@onedrive
systemctl start rclone-mount@gdrive
systemctl start rclone-mount@mega

# Verificar montajes
systemctl status rclone-mount@onedrive
df -h | grep /mnt

# Iniciar streaming
systemctl start nginx-stream
systemctl start multi-stream

# Iniciar limpieza automática
systemctl start stream-cleanup.timer
```

## 🔧 Configuración Avanzada

### Configuración de Stream (/etc/stream/config.conf)

```bash
# Calidad de video
VIDEO_BITRATE="2000k"        # Bitrate de video
VIDEO_MAXRATE="2400k"        # Bitrate máximo
VIDEO_BUFSIZE="4000k"        # Buffer size
VIDEO_PRESET="medium"        # Preset de codificación (ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow)
VIDEO_PROFILE="high"         # Perfil H.264 (baseline, main, high)

# Calidad de audio
AUDIO_BITRATE="192k"         # Bitrate de audio
AUDIO_SAMPLERATE="48000"     # Sample rate

# Fuentes de streaming
STREAM_SOURCES=(
    "onedrive:/mnt/onedrive:/mnt/onedrive/playlist.txt:onedrive"
    "gdrive:/mnt/gdrive:/mnt/gdrive/playlist.txt:gdrive"
    "mega:/mnt/mega:/mnt/mega/playlist.txt:mega"
)

# Rotación automática
ROTATE_STREAMS=true
STREAM_ROTATION_INTERVAL=3600  # 1 hora en segundos
```

### Configuración de Nginx

Para usar puerto 80 en lugar de 8080, edita `/etc/nginx/nginx.conf`:

```nginx
server {
    listen 80;  # Cambiar de 8080 a 80
    # ... resto de configuración
}
```

### Configuración de Firewall

```bash
# Permitir puertos necesarios
ufw allow 80/tcp      # HTTP
ufw allow 8080/tcp    # Stream HTTP (si usas puerto 8080)
ufw allow 1935/tcp    # RTMP
ufw allow 22/tcp      # SSH
ufw enable
```

## 📊 Monitoreo y Administración

### Comandos Útiles

```bash
# Ver estado de servicios
systemctl status multi-stream
systemctl status rclone-mount@onedrive

# Ver logs en tiempo real
journalctl -f -u multi-stream
tail -f /var/log/stream/multi-stream.log

# Verificar montajes
df -h | grep /mnt
ls -la /mnt/*/

# Verificar streams activos
ps aux | grep ffmpeg

# Estado del stream
/opt/lat-stream/scripts/multi-stream.sh status

# Detener streaming
/opt/lat-stream/scripts/multi-stream.sh stop

# Reiniciar streaming
systemctl restart multi-stream
```

### URLs de Acceso

- **Stream HLS**: `http://tu-ip:8080/hls/stream/index.m3u8`
- **Interfaz Web**: `http://tu-ip:8080/`
- **Stream OneDrive**: `http://tu-ip:8080/hls/onedrive/index.m3u8`
- **Stream Google Drive**: `http://tu-ip:8080/hls/gdrive/index.m3u8`
- **Stream MEGA**: `http://tu-ip:8080/hls/mega/index.m3u8`

### Estructura de Archivos

```
/opt/lat-stream/
├── nginx.conf                 # Configuración de Nginx
├── scripts/
│   ├── configure-rclone.sh   # Configurador de rclone
│   ├── multi-stream.sh       # Script principal de streaming
│   └── stream.sh             # Script original (legacy)
├── systemd/
│   ├── multi-stream.service
│   ├── nginx-stream.service
│   ├── rclone-mount@.service
│   ├── stream-cleanup.service
│   └── stream-cleanup.timer
└── web/
    ├── index.html            # Interfaz básica
    ├── stream.html           # Interfaz avanzada
    └── test.html             # Página de pruebas

/var/
├── hls/                      # Segmentos HLS generados
├── dash/                     # Segmentos DASH (opcional)
├── log/stream/               # Logs del sistema
└── www/stream/               # Archivos web

/mnt/
├── onedrive/                 # Montaje OneDrive
├── gdrive/                   # Montaje Google Drive
└── mega/                     # Montaje MEGA

/etc/stream/
└── config.conf               # Configuración principal
```

## 🔧 Solución de Problemas

### Problema: Rclone no monta

```bash
# Verificar configuración
rclone config show

# Probar conexión manual
rclone ls onedrive: --max-depth 1

# Verificar logs
journalctl -u rclone-mount@onedrive
```

### Problema: FFmpeg falla

```bash
# Verificar códecs disponibles
ffmpeg -codecs | grep h264
ffmpeg -encoders | grep aac

# Probar comando manual
ffmpeg -i /mnt/onedrive/test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/multi/test
```

### Problema: Nginx no inicia

```bash
# Verificar configuración
nginx -t

# Ver logs de error
tail -f /var/log/nginx/error.log

# Verificar puertos en uso
netstat -tulpn | grep :1935
netstat -tulpn | grep :8080
```

### Problema: Sin video en navegador

1. Verificar que el stream esté activo: `http://tu-ip:8080/hls/stream/index.m3u8`
2. Abrir consola del navegador para ver errores de JavaScript
3. Verificar CORS en nginx
4. Probar con VLC: `vlc http://tu-ip:8080/hls/stream/index.m3u8`

## 🔐 Seguridad

### Recomendaciones Básicas

```bash
# Cambiar puerto SSH por defecto
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
systemctl restart ssh

# Configurar fail2ban
apt install fail2ban
systemctl enable fail2ban

# Actualización automática de seguridad
apt install unattended-upgrades
dpkg-reconfigure unattended-upgrades
```

### Configurar HTTPS (Opcional)

```bash
# Instalar certbot
apt install certbot python3-certbot-nginx

# Obtener certificado (requiere dominio)
certbot --nginx -d tu-dominio.com

# Renovación automática
crontab -e
# Agregar: 0 12 * * * /usr/bin/certbot renew --quiet
```

## 📈 Optimización de Rendimiento

### Para VPS con recursos limitados:

```bash
# En /etc/stream/config.conf
VIDEO_BITRATE="800k"
VIDEO_MAXRATE="1000k"
VIDEO_PRESET="ultrafast"
AUDIO_BITRATE="96k"
```

### Para VPS potentes:

```bash
# En /etc/stream/config.conf
VIDEO_BITRATE="3000k"
VIDEO_MAXRATE="3600k"
VIDEO_PRESET="slow"
AUDIO_BITRATE="256k"
```

### Limitar uso de CPU de FFmpeg:

```bash
# Agregar a la configuración de ffmpeg en multi-stream.sh
-threads 2 -cpu-used 4
```

## 📞 Soporte

Para problemas o mejoras:
1. Revisar logs: `/var/log/stream/`
2. Verificar estado: `./scripts/multi-stream.sh status`
3. Documentar el error y configuración utilizada

## 🔄 Actualizaciones

```bash
# Backup de configuración
cp /etc/stream/config.conf /etc/stream/config.conf.backup
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

# Actualizar código
cd /opt/lat-stream
git pull origin main

# Restaurar configuración personalizada si es necesario
# Reiniciar servicios
systemctl restart multi-stream nginx-stream
```

---

**¡Tu sistema de streaming multi-fuente está listo!** 🎉

Accede a `http://tu-ip:8080` para ver la interfaz web y comenzar a transmitir contenido desde tus múltiples fuentes en la nube.