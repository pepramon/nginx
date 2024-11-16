#!/bin/bash

# Función para manejar una salida limpia del script
salida_limpia() {
    echo "Iniciando proceso de apagado..."
    
    # Detener procesos de vigilancia de directorios
    if [ ${#PID_DIRS[@]} -gt 0 ]; then
        for pid in "${PID_DIRS[@]}"; do
            kill -SIGTERM "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
        done
    fi
    
    # Limpiar archivos temporales de bloqueo
    echo "Limpiando archivos temporales..."
    rm -f /tmp/nginx_reload_*_lock
    
    # Detener el proceso de Nginx
    if kill -0 "${NGINX_PID}" 2>/dev/null; then
        echo "Deteniendo Nginx..."
        kill -SIGTERM "${NGINX_PID}"
        wait "${NGINX_PID}"
    fi
    
    echo "Apagado completo."
    exit
}

# Configurar manejo de señales para salida ordenada
# TERM, INT: Parar contenedor (ej.: señal de Docker o Ctrl+C)
# QUIT: Señal adicional de interrupción
trap "exit" TERM INT QUIT
trap "salida_limpia" EXIT SIGINT SIGTERM

# Explicación:
# - TERM: Señal enviada por Docker al detener un contenedor de forma controlada.
# - INT: Señal enviada cuando un usuario presiona Ctrl+C en la terminal.
# - QUIT: Señal de interrupción, útil como alternativa en algunos sistemas.
# - EXIT: Ejecuta la función `salida_limpia` al cerrar el script, garantizando la limpieza.
# 
# Este bloque asegura que el contenedor o script detenga los procesos internos de manera ordenada,
# limpiando recursos y cerrando procesos secundarios como los vigilantes de directorios o Nginx.


# Se lanza nginx con sus parametros y se guarda el PID
echo "Iniciando Nginx..."
/docker-entrypoint.sh "$@" &
NGINX_PID=$!

# Función para recargar Nginx tras detectar cambios en un directorio
recargar_una_vez() {
    # Saber que directorio ha emitido el cambio
    local dir="$1" # Directorio que desencadenó el evento
    local lock_file="/tmp/nginx_reload_${dir//\//-}_lock"

    # Evitar recargas múltiples simultáneas
    if [ ! -f "$lock_file" ]; then
        touch "$lock_file"
        echo "Esperando 10 minutos antes de recargar Nginx..."
        sleep 600s  # Se espera 10 min para recargar nginx
        echo "Recargando Nginx debido a cambios en: $dir"
        kill -HUP ${NGINX_PID}
        rm "$lock_file"
    fi
}

# Compatibilidad con imágenes anteriores (alias para la variable DIRECTORIES)
if [ -n "$DIRECTORIES" ]; then
        DIRECTORIOS=$DIRECTORIES
fi

# Declarar un arreglo para almacenar los PIDs de los procesos de vigilancia
declare -A PID_DIRS

# Configurar vigilancia para los directorios especificados
for DIR in $DIRECTORIES; do
    if [ -d "$DIR" ]; then
        echo "Configurando vigilancia en: $DIR"
        (
        # Bucle para vigilar eventos en el directorio
        while true; do
            inotifywait -m -r -e modify,create,delete,move "$DIR" | 
            while read -r directory event filename; do
                echo "Evento detectado: $event en $directory/$filename"
                recargar_una_vez "$DIR" &
            done
        done
        ) &
        PID_DIRS[$DIR]=$! # Guardar el PID del proceso de vigilancia
    else
        echo "El directorio $DIR no existe. Finalizando..."
        sleep 5s
        exit 1
    fi
done

# Esperar a que los procesos terminen (incluyendo Nginx y los vigilantes)
if [ ${#PID_DIRS[@]} -gt 0 ]; then
    wait -n "${NGINX_PID}" "${PID_DIRS[@]}"
    EXIT_CODE=$?
else
    wait -n "${NGINX_PID}"
    EXIT_CODE=$?
fi

# Informar sobre la salida del script
echo "Saliendo con código ${EXIT_CODE}"
exit ${EXIT_CODE}
