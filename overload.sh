#!/bin/bash

# Este script simula descargas simultáneas para probar el throughput de un firewall.
# Realiza dos pruebas: una con un archivo de test grande y otra con un "virus" simulado.
# Ignora errores de certificado y mide la velocidad de escritura en /dev/null para estimar el throughput.
# ¡Novedad!: Mata los procesos wget de cada prueba tras el período de medición y suprime todos los mensajes 'Killed'.

# --- Variables configurables ---
NUM_SIMULACIONES=1000 # Número de descargas simultáneas. Ajusta según tus necesidades.
URL_NORMAL="http://proof.ovh.net/files/1Gb.dat" # URL de test de alta capacidad (1GB)
URL_VIRUS="http://66.63.187.190/work/addon.exe" # URL del archivo que simula un virus
TIEMPO_MEDICION_SEGUNDOS=45 # Duración en segundos durante la cual se medirán las descargas activas.
# -------------------------------

echo "Preparando el entorno para las pruebas de throughput del firewall."
echo "URL de test normal: ${URL_NORMAL}"
echo "URL de test con 'virus': ${URL_VIRUS}"
echo "La salida de wget se redireccionará a /dev/null y se ignorarán los errores de certificado."
echo "La medición de throughput se realizará durante ${TIEMPO_MEDICION_SEGUNDOS} segundos para cada prueba."
echo "¡Los procesos de wget se terminarán automáticamente después de cada período de medición, sin mensajes de 'Killed'!"
echo ""

# Ajustar límites del sistema para permitir muchas conexiones
echo "Ajustando límites del sistema para permitir más conexiones..."
ulimit -n 65535 # Límite de descriptores de archivo abiertos
ulimit -u 65535 # Límite de procesos/hilos de usuario
echo "Límites actuales: open files=$(ulimit -n), max user processes=$(ulimit -u)"
echo ""

# --- Preparación de la medición de throughput (única para ambas pruebas) ---
# Detectar la interfaz de red principal
echo "Detectando interfaz de red principal..."
IFACE=$(ip route | awk '/default/ {print $5; exit}')
if [ -z "$IFACE" ]; then
    echo "ERROR: No se pudo detectar la interfaz de red predeterminada. Por favor, especifica una manualmente (ej. 'eth0', 'ens33')."
    echo "Saliendo..."
    exit 1
fi
echo "Interfaz de red principal: ${IFACE}"

# Verificar si 'ip' está disponible
if ! command -v ip &> /dev/null; then
    echo "ERROR: El comando 'ip' (parte de iproute2) no se encuentra. Es necesario para medir el throughput."
    echo "Por favor, instálalo (ej. 'sudo apt install iproute2' en Debian/Ubuntu)."
    echo "Saliendo..."
    exit 1
fi

# --- Función para ejecutar una prueba ---
run_test() {
    local test_name="$1"
    local url="$2"
    local pids_array_name="$3" # Nombre de la variable array para PIDs
    local -n pids_array=$pids_array_name # Referencia a la variable array (Bash 4.3+)

    echo ""
    echo "==================================================="
    echo "INICIANDO PRUEBA: ${test_name} (${url})"
    echo "==================================================="
    if [[ "${test_name}" == *"Virus"* ]]; then
        echo "¡ADVERTENCIA: Esta prueba usa una URL de un posible archivo malicioso!"
        echo "Asegúrate de que tu firewall/antivirus esté activo y en un entorno seguro."
    fi
    echo ""

    # Limpiar el array de PIDs para la nueva prueba
    pids_array=()

    echo "Iniciando ${NUM_SIMULACIONES} descargas en segundo plano de ${url}..."
    # La clave para suprimir los mensajes "Killed" es redirigir la salida del bucle for.
    # El ( ... ) crea un subshell, y redirigir su salida estándar y de error silencia todo.
    (
    for (( i=1; i<=${NUM_SIMULACIONES}; i++ ))
    do
        # Redirigir la salida de error de wget a /dev/null para suprimir cualquier mensaje interno
        # La salida de wget es silenciosa con -q, pero el 2>&1 es por robustez.
        wget -q -O /dev/null --no-check-certificate "${url}" >/dev/null 2>&1 &
        PIDS_GLOBAL_TEMP+=($!) # Usamos un array temporal global para PIDs dentro del subshell
    done
    ) >/dev/null 2>&1 # Redirige toda la salida del subshell a /dev/null

    # Capturar los PIDs de los wgets lanzados, ya que el array local dentro del subshell no es accesible.
    # Una forma más fiable es usar `pgrep` con un patrón específico que solo este script usaría.
    # Para esto, podemos pasar la URL como parte del patrón de pgrep.
    # El `sleep 0.5` es para dar tiempo a los procesos de wget a aparecer en la tabla de procesos.
    sleep 0.5
    PIDS_LANZADOS=$(pgrep -f "wget -q -O /dev/null --no-check-certificate ${url}")
    if [ -z "$PIDS_LANZADOS" ]; then
        echo "ADVERTENCIA: No se pudieron encontrar procesos de wget para ${url} después de iniciarlos. Podría haber un problema."
    fi
    # Convertir la cadena de PIDs a un array de Bash para facilitar la iteración.
    IFS=$'\n' read -r -d '' -a pids_array <<< "$PIDS_LANZADOS"

    echo ""
    echo "Todas las descargas han sido iniciadas. Ejecutando la medición de throughput..."

    # --- Bloque de Medición de Throughput ---
    BYTES_RX_START=$(cat "/sys/class/net/$IFACE/statistics/rx_bytes")
    echo "Midiendo el throughput durante ${TIEMPO_MEDICION_SEGUNDOS} segundos..."
    sleep "$TIEMPO_MEDICION_SEGUNDOS"
    BYTES_RX_END=$(cat "/sys/class/net/$IFACE/statistics/rx_bytes")

    BYTES_TRANSFERIDOS=$((BYTES_RX_END - BYTES_RX_START))

    if (( TIEMPO_MEDICION_SEGUNDOS > 0 )); then
        VELOCIDAD_BPS=$(echo "scale=2; ${BYTES_TRANSFERIDOS} * 8 / ${TIEMPO_MEDICION_SEGUNDOS}" | bc -l)
        VELOCIDAD_MBPS=$(echo "scale=2; ${VELOCIDAD_BPS} / 1000000" | bc -l)
        echo ""
        echo "--- RESULTADOS DE THROUGHPUT (${test_name}) ---"
        echo "Bytes transferidos en la interfaz ${IFACE} durante ${TIEMPO_MEDICION_SEGUNDOS} segundos: ${BYTES_TRANSFERIDOS} Bytes"
        echo "Velocidad promedio: ${VELOCIDAD_MBPS} Mb/s"
        echo "--------------------------------------------------------"
    else
        echo "ERROR: El tiempo de medición debe ser mayor que cero."
    fi
    # --- Fin del Bloque de Medición ---

    echo ""
    echo "Terminando procesos wget de ${test_name}..."
    # Dar un pequeño tiempo para asegurar que la medición ha terminado y los procesos están listos para ser matados
    sleep 1
    
    # Matar por PID primero (con salida suprimida)
    for PID in "${pids_array[@]}"; do
        if ps -p "$PID" >/dev/null; then # Verificar si el proceso sigue corriendo
            kill -9 "$PID" &>/dev/null # Forzar terminación y suprimir salida
        fi
    done
    
    # Múltiples killall -9 wget para asegurar que no quede ninguno, silenciando la salida
    for i in {1..5}; do # Repetir 5 veces
        killall -9 wget &>/dev/null
        sleep 0.1 # Pequeña pausa entre intentos
    done

    echo "Procesos de ${test_name} terminados."
}

# Declarar los arrays de PIDs a nivel global para que la referencia `local -n` funcione
declare -a PIDS_NORMAL_GLOBAL
declare -a PIDS_VIRUS_GLOBAL

# Ejecutar las pruebas
run_test "Prueba 1: Carga Normal" "${URL_NORMAL}" PIDS_NORMAL_GLOBAL
run_test "Prueba 2: Carga con 'Virus'" "${URL_VIRUS}" PIDS_VIRUS_GLOBAL

echo ""
echo "Simulación completa. Ambas pruebas han finalizado."