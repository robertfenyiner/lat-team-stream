# Pruebas locales del streaming (Ubuntu 22.04)

Este documento contiene pasos rápidos para desplegar y probar localmente la solución de streaming en un VPS Ubuntu 22.04.

Resumen rápido
- Montar tu remoto rclone `imagenes` en `/mnt/imagenes`.
- Asegurar `/var/hls` y configurar nginx (archivo `nginx.conf` en este repo está preparado para escuchar en el puerto 8080).
- Copiar `scripts/stream.sh` a `/usr/local/bin/stream.sh`, hacerlo ejecutable y lanzar manualmente o via `systemd`.
- Abrir `web/test.html` en un navegador (o copiar al servidor web) para probar el HLS.

1) Preparar rclone mount

Si ya tienes rclone configurado y el remoto se llama `imagenes` (como mostraste), usa el unit systemd incluido:

```bash
sudo mkdir -p /mnt/imagenes
sudo systemctl daemon-reload
sudo cp systemd/rclone-mount@.service /etc/systemd/system/rclone-mount@.service
sudo systemctl enable --now rclone-mount@imagenes.service
```

Verifica que el montaje esté disponible:

```bash
ls -lah /mnt/imagenes
```

2) Preparar carpeta HLS y nginx

```bash
# crear carpeta para segmentos HLS
sudo mkdir -p /var/hls
sudo chown www-data:www-data /var/hls

# Instalar nginx con rtmp (si no lo has hecho)
sudo apt update
sudo apt install -y nginx libnginx-mod-rtmp

# Copia la configuración nginx desde el repo (revisa antes)
sudo cp nginx.conf /etc/nginx/nginx.conf
sudo nginx -t
sudo systemctl restart nginx
```

3) Preparar el streamer

```bash
# Copiar el script y hacerlo ejecutable
sudo cp scripts/stream.sh /usr/local/bin/stream.sh
sudo chmod +x /usr/local/bin/stream.sh

# (Opcional) Copiar el servicio systemd incluido
sudo cp stream.service /etc/systemd/system/stream.service
sudo systemctl daemon-reload
sudo systemctl enable --now stream.service

# Si prefieres probar manualmente, crea una playlist dentro del montaje rclone:
echo "/mnt/imagenes/video1.mp4" > /mnt/imagenes/playlist.txt
# Ajusta la ruta a tus archivos reales dentro del montaje

# Lanzar manualmente (para ver logs en la terminal):
/usr/local/bin/stream.sh /mnt/imagenes/playlist.txt rtmp://localhost:1935/live/stream

# O ver logs si iniciaste el servicio
sudo journalctl -u stream.service -f
tail -f /var/log/ffmpeg-stream.log
```

4) Probar el HLS

- Ver que el .m3u8 está disponible:

```bash
curl -I http://localhost:8080/hls/stream/stream.m3u8
```

- Abrir `web/test.html` en un navegador. Si estás en el servidor puedes usar `lynx` o copiar el HTML a tu servidor web; lo más simple es abrirlo localmente desde tu máquina y apuntar la URL al servidor (ej. `http://<VPS_IP>:8080/hls/stream/stream.m3u8`).

5) Firewall

Abre puertos si es necesario:

```bash
sudo ufw allow 1935/tcp
sudo ufw allow 8080/tcp
```

Notas
- Si nginx ya usa el puerto 80 para otro proyecto, este `nginx.conf` está preparado para escuchar en 8080 para la parte HTTP de HLS. Ajusta según tu despliegue.
- Para producción considera proteger el acceso a `/hls/` con `X-Accel-Redirect` desde tu app (Laravel/unit3d) o usar signed URLs.
