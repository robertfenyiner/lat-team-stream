# 🎬 LAT Team Stream - Sistema de Streaming Multi-Fuente

Sistema de streaming 24/7 que permite transmitir contenido desde múltiples proveedores de almacenamiento en la nube (OneDrive, Google Drive, MEGA) de forma simultánea y con rotación automática.

## ✨ Características

- **🌐 Multi-fuente**: Streaming desde OneDrive, Google Drive y MEGA
- **🔄 Rotación automática**: Cambio automático entre fuentes
- **📱 Interfaz web moderna**: Control y monitoreo en tiempo real
- **⚡ HLS/DASH**: Streaming adaptativo de alta calidad
- **🛡️ Seguridad**: Configuración segura con firewall y fail2ban
- **📊 Monitoreo**: Logs detallados y verificaciones de salud
- **🔧 Fácil instalación**: Script automático para Ubuntu 22.04

## 🚀 Instalación Rápida

### Opción 1: Instalador Automático (Recomendado)

```bash
# Conectar a tu VPS Ubuntu 22.04
ssh root@tu-ip-vps

# Instalar con una sola línea
curl -fsSL https://raw.githubusercontent.com/robertfenyiner/lat-team-stream/main/install.sh | bash
```

### Opción 2: Clonación + Instalador

```bash
# Clonar repositorio
git clone https://github.com/robertfenyiner/lat-team-stream.git
cd lat-team-stream

# Ejecutar instalador
chmod +x install.sh
sudo ./install.sh
```

### Opción 3: Instalación Manual

Consulta la [Guía de Instalación Completa](INSTALL.md) para instrucciones detalladas paso a paso.

## 📦 Componentes

- **[Rclone](https://rclone.org/)**: Monta las nubes como sistemas de archivos locales
- **[FFmpeg](https://ffmpeg.org/)**: Procesa y transmite el contenido de video
- **[Nginx-RTMP](https://github.com/arut/nginx-rtmp-module)**: Servidor RTMP que genera segmentos HLS/DASH
- **[HLS.js](https://github.com/video-dev/hls.js/)**: Reproductor web para visualización

## 🎯 Configuración Rápida

### 1. Configurar Rclone
```bash
cd /opt/lat-stream
./scripts/configure-rclone.sh
```

### 2. Crear Playlists
```bash
# OneDrive
echo "/mnt/onedrive/video1.mp4" > /mnt/onedrive/playlist.txt
echo "/mnt/onedrive/video2.mp4" >> /mnt/onedrive/playlist.txt

# Google Drive  
echo "/mnt/gdrive/movie1.mp4" > /mnt/gdrive/playlist.txt
echo "/mnt/gdrive/movie2.mp4" >> /mnt/gdrive/playlist.txt

# MEGA
echo "/mnt/mega/content1.mp4" > /mnt/mega/playlist.txt
echo "/mnt/mega/content2.mp4" >> /mnt/mega/playlist.txt
```

### 3. Iniciar Servicios
```bash
# Montar unidades de nube
systemctl start rclone-mount@onedrive
systemctl start rclone-mount@gdrive  
systemctl start rclone-mount@mega

# Iniciar streaming
systemctl start nginx-stream
systemctl start multi-stream
```

### 4. Acceder a la Interfaz
- **Interfaz web**: `http://tu-ip:8080`
- **Stream directo**: `http://tu-ip:8080/hls/stream/index.m3u8`

## 🔧 Configuración Avanzada

### Calidad de Video
Edita `/etc/stream/config.conf`:
```bash
# Para VPS básicos
VIDEO_BITRATE="800k"
VIDEO_PRESET="ultrafast" 

# Para VPS potentes
VIDEO_BITRATE="3000k"
VIDEO_PRESET="slow"
```

### Rotación de Fuentes
```bash
# Habilitar rotación automática cada hora
ROTATE_STREAMS=true
STREAM_ROTATION_INTERVAL=3600
```

### Múltiples Streams
```bash
# Stream específico de OneDrive
http://tu-ip:8080/hls/onedrive/index.m3u8

# Stream específico de Google Drive
http://tu-ip:8080/hls/gdrive/index.m3u8

# Stream específico de MEGA
http://tu-ip:8080/hls/mega/index.m3u8
```

## 📊 Monitoreo y Control

### Comandos Útiles
```bash
# Estado general del sistema
lat-stream-status

# Logs en tiempo real
journalctl -f -u multi-stream

# Estado de montajes
df -h | grep /mnt

# Control del streaming
/opt/lat-stream/scripts/multi-stream.sh status
/opt/lat-stream/scripts/multi-stream.sh stop
/opt/lat-stream/scripts/multi-stream.sh start

# Actualizar desde GitHub
cd /opt/lat-stream && git pull && systemctl restart multi-stream
```

### Logs Importantes
- **Sistema**: `/var/log/stream/multi-stream.log`
- **FFmpeg**: `/var/log/stream/ffmpeg-*.log`
- **Rclone**: `/var/log/rclone-*.log`
- **Nginx**: `/var/log/nginx/error.log`

## 🌐 URLs de Acceso

| Servicio | URL | Descripción |
|----------|-----|-------------|
| Interfaz Web | `http://ip:8080` | Panel de control principal |
| Stream Principal | `http://ip:8080/hls/stream/index.m3u8` | Stream con rotación automática |
| OneDrive | `http://ip:8080/hls/onedrive/index.m3u8` | Stream exclusivo de OneDrive |
| Google Drive | `http://ip:8080/hls/gdrive/index.m3u8` | Stream exclusivo de Google Drive |
| MEGA | `http://ip:8080/hls/mega/index.m3u8` | Stream exclusivo de MEGA |
| Estado Sistema | `http://ip:8080/health` | Endpoint de salud |

## 📁 Estructura del Proyecto

```
/opt/lat-stream/
├── 📄 nginx.conf                    # Configuración optimizada de Nginx
├── 📄 install.sh                    # Instalador automático
├── 📄 INSTALL.md                    # Guía de instalación manual
├── 📂 scripts/
│   ├── 🔧 configure-rclone.sh      # Configurador interactivo de rclone
│   ├── 🎬 multi-stream.sh          # Script principal de streaming multi-fuente
│   └── 📜 stream.sh                 # Script original (legacy)
├── 📂 systemd/
│   ├── ⚙️ multi-stream.service      # Servicio principal de streaming
│   ├── 🌐 nginx-stream.service      # Servicio de Nginx optimizado
│   ├── ☁️ rclone-mount@.service     # Servicio de montaje de rclone (template)
│   ├── 🧹 stream-cleanup.service    # Servicio de limpieza
│   └── ⏰ stream-cleanup.timer      # Timer para limpieza automática
└── 📂 web/
    ├── 🏠 index.html                # Interfaz básica
    ├── 🎛️ stream.html               # Interfaz avanzada con controles
    └── 🧪 test.html                 # Página de pruebas

/var/
├── 📂 hls/                          # Segmentos HLS generados
├── 📂 dash/                         # Segmentos DASH (opcional)
├── 📂 log/stream/                   # Logs del sistema
└── 📂 www/stream/                   # Archivos web públicos

/mnt/
├── 📂 onedrive/                     # Montaje OneDrive
├── 📂 gdrive/                       # Montaje Google Drive
└── 📂 mega/                         # Montaje MEGA
```

## 🔒 Seguridad

- **Firewall**: UFW configurado automáticamente
- **Fail2ban**: Protección contra ataques de fuerza bruta
- **Acceso RTMP**: Solo desde localhost
- **Logs rotados**: Para evitar uso excesivo de disco
- **Servicios aislados**: Configuración de seguridad en systemd

## 🔧 Solución de Problemas

### Stream no se reproduce
```bash
# Verificar que los servicios estén activos
systemctl status multi-stream nginx-stream

# Comprobar montajes de rclone
df -h | grep /mnt

# Ver logs de FFmpeg
tail -f /var/log/stream/ffmpeg-*.log
```

### Problemas de montaje
```bash
# Verificar configuración de rclone
rclone config show

# Probar conexión manual
rclone ls onedrive: --max-depth 1

# Reiniciar montaje
systemctl restart rclone-mount@onedrive
```

### Problemas de red
```bash
# Verificar puertos abiertos
netstat -tulpn | grep -E ':(80|8080|1935)'

# Comprobar firewall
ufw status verbose

# Test de stream
curl -I http://localhost:8080/hls/stream/index.m3u8
```

## 🚀 Características Avanzadas

### Calidades Múltiples
El sistema genera automáticamente múltiples calidades:
- **720p**: 1280x720 @ 2Mbps
- **480p**: 854x480 @ 1Mbps
- **Auto**: Calidad adaptativa

### Monitoreo en Tiempo Real
- Estado de conexiones de nube
- Uso de recursos del servidor
- Estadísticas de streaming
- Logs centralizados

### API REST (Futuro)
- Control remoto de streams
- Gestión de playlists
- Estadísticas en JSON
- Webhooks para eventos

## 📞 Soporte

### Logs para Diagnóstico
```bash
# Recopilar información de diagnóstico
tar -czf lat-stream-logs.tar.gz \
  /var/log/stream/ \
  /var/log/nginx/ \
  /etc/stream/ \
  /opt/lat-stream/

# Enviar lat-stream-logs.tar.gz para soporte
```

### Información del Sistema
```bash
# Estado completo del sistema
lat-stream-status > sistema-estado.txt
```

## 📜 Licencia

Este proyecto está bajo licencia MIT. Ver archivo `LICENSE` para detalles.

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-caracteristica`)
3. Commit tus cambios (`git commit -am 'Agregar nueva característica'`)
4. Push a la rama (`git push origin feature/nueva-caracteristica`)
5. Crea un Pull Request

## 📈 Roadmap

- [ ] 🔌 API REST completa
- [ ] 📱 App móvil para control
- [ ] 🎮 Integración con Discord/Twitch
- [ ] 📊 Dashboard de analytics
- [ ] 🌍 Multi-idioma
- [ ] 🐳 Soporte Docker
- [ ] ☸️ Kubernetes deployment

---

**¡Disfruta tu sistema de streaming multi-fuente!** 🎉

Para obtener ayuda adicional, consulta la [documentación completa](INSTALL.md) o crea un issue en GitHub.
