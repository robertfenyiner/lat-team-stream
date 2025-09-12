# 🚀 LAT Team Stream - Inicio Rápido

Guía rápida para poner en marcha tu sistema de streaming en 10 minutos.

## 📋 Antes de Empezar

✅ **VPS Ubuntu 22.04** con acceso root
✅ **Al menos una cuenta de nube**: OneDrive, Google Drive o MEGA
✅ **Videos subidos** a tu almacenamiento en la nube

## ⚡ Instalación Express (Una Línea)

```bash
curl -fsSL https://raw.githubusercontent.com/robertfenyiner/lat-team-stream/main/install.sh | bash
```

## 🔧 Configuración en 3 Pasos

### 1️⃣ Configurar Rclone (5 min)

```bash
cd /opt/lat-stream
./scripts/configure-rclone.sh
```

Sigue el menú:
- Selecciona tu proveedor (OneDrive/GDrive/MEGA)
- Autentica en el navegador
- Confirma la configuración

### 2️⃣ Crear Playlist (2 min)

```bash
# Para OneDrive
echo "/mnt/onedrive/tu-video.mp4" > /mnt/onedrive/playlist.txt

# Para Google Drive
echo "/mnt/gdrive/tu-video.mp4" > /mnt/gdrive/playlist.txt

# Para MEGA  
echo "/mnt/mega/tu-video.mp4" > /mnt/mega/playlist.txt
```

### 3️⃣ Iniciar Streaming (1 min)

```bash
# Montar tu nube (ejemplo OneDrive)
systemctl start rclone-mount@onedrive

# Iniciar streaming
systemctl start nginx-stream
systemctl start multi-stream
```

## 🌐 ¡Listo!

**Tu stream está disponible en:**
- 🖥️ **Interfaz Web**: `http://tu-ip:8080`
- 📱 **Stream Directo**: `http://tu-ip:8080/hls/stream/index.m3u8`

## 🔍 Verificar que Funciona

```bash
# Estado del sistema
lat-stream-status

# Ver logs en tiempo real
journalctl -f -u multi-stream
```

## 🆘 ¿Problemas?

### Stream no aparece:
```bash
systemctl status multi-stream
tail -f /var/log/stream/multi-stream.log
```

### No se monta la nube:
```bash
systemctl status rclone-mount@onedrive
rclone ls onedrive: --max-depth 1
```

### No se accede por web:
```bash
systemctl status nginx-stream
curl http://localhost:8080/health
```

## 📚 Documentación Completa

- [**Instalación Detallada**](INSTALL.md) - Guía paso a paso completa
- [**README Principal**](README.md) - Documentación completa del proyecto
- [**Repositorio**](https://github.com/robertfenyiner/lat-team-stream) - Código fuente y issues

---

**¡En 10 minutos tienes tu streaming multi-fuente funcionando!** 🎉