#!/usr/bin/env bash
# Multi-source streamer with cloud storage support
# Usage: ./multi-stream.sh [CONFIG_FILE]
# Default config: /etc/stream/config.conf

set -euo pipefail

# Default configuration
CONFIG_FILE="${1:-/etc/stream/config.conf}"
LOG_DIR="/var/log/stream"
RTMP_BASE_URL="rtmp://localhost:1935/multi"
DEFAULT_STREAM_NAME="stream"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] $message" | tee -a "$LOG_DIR/multi-stream.log"
}

# Check if required tools are available
check_dependencies() {
    local deps=("ffmpeg" "rclone")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_message "ERROR" "${RED}$dep no está instalado${NC}"
            exit 1
        fi
    done
    
    log_message "INFO" "${GREEN}✓ Dependencias verificadas${NC}"
}

# Load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR" "${RED}Archivo de configuración no encontrado: $CONFIG_FILE${NC}"
        create_default_config
        exit 1
    fi
    
    # Source the config file
    source "$CONFIG_FILE"
    log_message "INFO" "${GREEN}✓ Configuración cargada desde $CONFIG_FILE${NC}"
}

# Create default configuration file
create_default_config() {
    log_message "INFO" "${YELLOW}Creando configuración por defecto...${NC}"
    
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    cat > "$CONFIG_FILE" << 'EOF'
# Multi-source streaming configuration

# Stream quality settings
VIDEO_BITRATE="1500k"
VIDEO_MAXRATE="1800k"
VIDEO_BUFSIZE="3000k"
VIDEO_PRESET="veryfast"
VIDEO_PROFILE="main"
AUDIO_BITRATE="128k"
AUDIO_SAMPLERATE="44100"

# Stream sources (OneDrive, Google Drive, MEGA)
# Format: SOURCE_NAME:MOUNT_PATH:PLAYLIST_FILE:STREAM_KEY
STREAM_SOURCES=(
    "onedrive:/mnt/onedrive:/mnt/onedrive/playlist.txt:onedrive"
    "gdrive:/mnt/gdrive:/mnt/gdrive/playlist.txt:gdrive"
    "mega:/mnt/mega:/mnt/mega/playlist.txt:mega"
)

# RTMP settings
RTMP_BASE_URL="rtmp://localhost:1935/multi"

# Retry settings
MAX_RETRIES=3
RETRY_DELAY=5
FILE_RETRY_DELAY=3

# Playlist refresh interval (seconds)
PLAYLIST_REFRESH=300

# Stream rotation settings
ROTATE_STREAMS=true
STREAM_ROTATION_INTERVAL=3600  # 1 hour
EOF

    log_message "INFO" "${GREEN}✓ Configuración creada en $CONFIG_FILE${NC}"
    log_message "INFO" "${YELLOW}Edita el archivo y ejecuta el script nuevamente${NC}"
}

# Check if mounts are available
check_mounts() {
    log_message "INFO" "${BLUE}Verificando montajes...${NC}"
    
    for source_config in "${STREAM_SOURCES[@]}"; do
        IFS=':' read -r source_name mount_path playlist_file stream_key <<< "$source_config"
        
        if ! mountpoint -q "$mount_path" 2>/dev/null; then
            log_message "WARN" "${YELLOW}⚠ $source_name no está montado en $mount_path${NC}"
        else
            log_message "INFO" "${GREEN}✓ $source_name montado correctamente${NC}"
        fi
    done
}

# Get available playlists
get_available_playlists() {
    local available_playlists=()
    
    for source_config in "${STREAM_SOURCES[@]}"; do
        IFS=':' read -r source_name mount_path playlist_file stream_key <<< "$source_config"
        
        if [ -f "$playlist_file" ] && mountpoint -q "$mount_path" 2>/dev/null; then
            available_playlists+=("$source_config")
            log_message "INFO" "${GREEN}✓ Playlist disponible: $source_name${NC}"
        else
            log_message "WARN" "${YELLOW}⚠ Playlist no disponible: $source_name${NC}"
        fi
    done
    
    echo "${available_playlists[@]}"
}

# Stream a single file with ffmpeg
stream_file() {
    local file="$1"
    local rtmp_url="$2"
    local source_name="$3"
    
    log_message "INFO" "${BLUE}🎬 Streaming: $(basename "$file") desde $source_name${NC}"
    
    local ffmpeg_log="$LOG_DIR/ffmpeg-$source_name.log"
    
    # Enhanced ffmpeg command with better error handling
    ffmpeg -re -hide_banner -loglevel warning -i "$file" \
        -c:v libx264 -preset "$VIDEO_PRESET" -profile:v "$VIDEO_PROFILE" -level 3.1 \
        -pix_fmt yuv420p -b:v "$VIDEO_BITRATE" -maxrate "$VIDEO_MAXRATE" \
        -bufsize "$VIDEO_BUFSIZE" -vf "scale='min(1280,iw)':'-2'" \
        -c:a aac -b:a "$AUDIO_BITRATE" -ar "$AUDIO_SAMPLERATE" \
        -f flv "$rtmp_url" >> "$ffmpeg_log" 2>&1
}

# Process playlist from a source
process_playlist() {
    local source_config="$1"
    IFS=':' read -r source_name mount_path playlist_file stream_key <<< "$source_config"
    
    local rtmp_url="$RTMP_BASE_URL/$stream_key"
    
    log_message "INFO" "${BLUE}📋 Procesando playlist: $source_name${NC}"
    
    if [ ! -f "$playlist_file" ]; then
        log_message "ERROR" "${RED}Playlist no encontrada: $playlist_file${NC}"
        return 1
    fi
    
    local retry_count=0
    
    while IFS= read -r file_line || [ -n "$file_line" ]; do
        # Process line: remove comments and trim whitespace
        local file_path="${file_line%%#*}"
        file_path="${file_path## }"
        file_path="${file_path%% }"
        
        [ -z "$file_path" ] && continue
        
        # Convert relative paths to absolute
        if [[ ! "$file_path" =~ ^/ ]]; then
            file_path="$mount_path/$file_path"
        fi
        
        if [ ! -f "$file_path" ]; then
            log_message "WARN" "${YELLOW}⚠ Archivo no encontrado: $file_path${NC}"
            continue
        fi
        
        # Stream the file with retry logic
        retry_count=0
        while [ $retry_count -lt $MAX_RETRIES ]; do
            if stream_file "$file_path" "$rtmp_url" "$source_name"; then
                break
            else
                retry_count=$((retry_count + 1))
                log_message "WARN" "${YELLOW}⚠ Error streaming $file_path (intento $retry_count/$MAX_RETRIES)${NC}"
                
                if [ $retry_count -lt $MAX_RETRIES ]; then
                    sleep $FILE_RETRY_DELAY
                fi
            fi
        done
        
        # Small delay between files
        sleep 1
        
    done < "$playlist_file"
}

# Main streaming loop with rotation
main_streaming_loop() {
    local current_playlist_index=0
    local last_rotation_time=$(date +%s)
    
    log_message "INFO" "${GREEN}🚀 Iniciando streaming multi-fuente...${NC}"
    
    while true; do
        local available_playlists=($(get_available_playlists))
        
        if [ ${#available_playlists[@]} -eq 0 ]; then
            log_message "ERROR" "${RED}No hay playlists disponibles. Esperando...${NC}"
            sleep 30
            continue
        fi
        
        # Check if we should rotate streams
        local current_time=$(date +%s)
        if [ "$ROTATE_STREAMS" = true ] && [ $((current_time - last_rotation_time)) -ge $STREAM_ROTATION_INTERVAL ]; then
            current_playlist_index=$(((current_playlist_index + 1) % ${#available_playlists[@]}))
            last_rotation_time=$current_time
            log_message "INFO" "${BLUE}🔄 Rotando a fuente ${current_playlist_index}${NC}"
        fi
        
        # Ensure index is within bounds
        if [ $current_playlist_index -ge ${#available_playlists[@]} ]; then
            current_playlist_index=0
        fi
        
        local current_source="${available_playlists[$current_playlist_index]}"
        
        # Process the current playlist
        if ! process_playlist "$current_source"; then
            log_message "ERROR" "${RED}Error procesando playlist. Reintentando en ${RETRY_DELAY}s...${NC}"
            sleep $RETRY_DELAY
        fi
        
        # Small delay before looping playlist again
        sleep 2
    done
}

# Signal handlers
cleanup() {
    log_message "INFO" "${YELLOW}🛑 Deteniendo streaming...${NC}"
    # Kill any remaining ffmpeg processes
    pkill -f "ffmpeg.*$RTMP_BASE_URL" 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

# Status function
show_status() {
    echo -e "${BLUE}=== Estado del Streaming Multi-Fuente ===${NC}"
    echo "Configuración: $CONFIG_FILE"
    echo "Logs: $LOG_DIR"
    echo ""
    
    check_mounts
    
    local available_playlists=($(get_available_playlists))
    echo ""
    echo -e "${BLUE}Playlists disponibles: ${#available_playlists[@]}${NC}"
    
    echo ""
    echo -e "${BLUE}Procesos ffmpeg activos:${NC}"
    pgrep -f "ffmpeg.*$RTMP_BASE_URL" >/dev/null && pgrep -af "ffmpeg.*$RTMP_BASE_URL" || echo "Ninguno"
}

# Main execution
case "${1:-start}" in
    "start")
        check_dependencies
        load_config
        check_mounts
        main_streaming_loop
        ;;
    "status")
        check_dependencies
        load_config
        show_status
        ;;
    "stop")
        log_message "INFO" "${YELLOW}Deteniendo todos los streams...${NC}"
        pkill -f "ffmpeg.*$RTMP_BASE_URL" 2>/dev/null || true
        echo "Streams detenidos"
        ;;
    "config")
        create_default_config
        ;;
    *)
        echo "Uso: $0 [start|stop|status|config]"
        echo ""
        echo "Comandos:"
        echo "  start   - Iniciar streaming (por defecto)"
        echo "  stop    - Detener todos los streams"
        echo "  status  - Mostrar estado del sistema"
        echo "  config  - Crear configuración por defecto"
        exit 1
        ;;
esac