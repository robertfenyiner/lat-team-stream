# Proyecto de Streaming 24/7 con OneDrive y HLS

Este proyecto monta una carpeta de OneDrive en un VPS y utiliza `ffmpeg` como broadcaster para emitir una lista de videos de forma continua hacia un servidor de streaming. El servidor convierte la señal en HLS para incrustarla en una página web.

## Componentes

- **rclone**: monta OneDrive como si fuese un disco local.
- **ffmpeg**: reproduce en bucle los videos y envía la señal al servidor de streaming.
- **nginx-rtmp**: recibe la señal RTMP y genera segmentos HLS (`m3u8` y `ts`).
- **hls.js**: reproductor web para visualizar la transmisión.

## Uso rápido

1. Configura `rclone` con tu cuenta de OneDrive.
2. Monta tu nube:
   ```bash
   rclone mount onedrive: /mnt/onedrive &
   ```
3. Instala Nginx con el módulo RTMP (en Debian/Ubuntu):
   ```bash
   sudo apt install nginx libnginx-mod-rtmp
   ```
4. Copia `nginx.conf` a `/etc/nginx/nginx.conf` o incluye su contenido en tu configuración y reinicia el servicio:
   ```bash
   sudo cp nginx.conf /etc/nginx/nginx.conf
   sudo systemctl restart nginx
   ```
5. Ejecuta el script de emisión (o instala `stream.service` para correrlo como servicio):
   ```bash
   ./scripts/stream.sh /mnt/onedrive/playlist.txt rtmp://localhost:1935/live/stream
   ```
6. Abre `web/index.html` en tu navegador para reproducir la transmisión.

## Estructura

- `scripts/stream.sh`: script que usa `ffmpeg` para emitir en bucle.
- `nginx.conf`: configuración mínima para `nginx-rtmp`.
- `stream.service`: ejemplo de unidad `systemd` para el script de emisión.
- `web/index.html`: página de ejemplo con `hls.js`.

## Requisitos

- `rclone`
- `ffmpeg`
- `nginx` con módulo `rtmp`
- Navegador moderno compatible con `hls.js`
