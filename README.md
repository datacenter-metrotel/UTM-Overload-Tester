Script de Medición de Throughput para NGFW (Bruto, Neto con SSL Deep Inspection y AV)
Este script de Bash está diseñado para medir el throughput (rendimiento) de un Next-Generation Firewall (NGFW) de cualquier vendor, evaluando su capacidad en diferentes escenarios:

Throughput Bruto (o casi bruto): Con tráfico de alta velocidad que el firewall debería permitir sin inspección profunda o con una inspección SSL/TLS optimizada.

Throughput Neto (con SSL Deep Inspection): Evalúa el impacto en el rendimiento cuando el firewall realiza una inspección profunda del tráfico SSL/TLS.

Throughput con Detección de Antivirus (AV): Mide el impacto cuando el firewall, además de la inspección SSL/TLS, analiza y potencialmente bloquea la descarga de archivos identificados como maliciosos.

⚠️ Advertencia de Seguridad Importante ⚠️
Este script está diseñado para probar las capacidades de seguridad de un firewall, lo que implica interactuar con archivos que simulan amenazas o, en algunos casos, virus reales.

¡UTILÍZALO EXCLUSIVAMENTE EN ENTORNOS DE PRUEBA Y AISLADOS!

NO LO EJECUTES EN ENTREDORES DE PRODUCCIÓN NI EN MÁQUINAS NO SEGURAS.

Asegúrate de que tu firewall y tu solución antivirus estén activos y actualizados.

Prefiera ejecutarlo en entornos Linux/Unix para evitar la ejecución accidental de archivos .exe de Windows. El script descarga los archivos a /dev/null (un "agujero negro" para datos), lo que evita que se guarden en disco, pero la detección a nivel de red y el impacto en el firewall siguen ocurriendo.

¿Cómo Funciona?
El script lanza un número configurable de descargas concurrentes utilizando wget. Cada descarga es dirigida a /dev/null para evitar llenar el disco duro del cliente. Se ignoran los errores de certificado para que la inspección SSL/TLS del firewall no sea impedimento.

El throughput se mide monitoreando el tráfico de bytes recibidos en la interfaz de red principal del sistema cliente durante un período de tiempo definido. Esto ofrece una visión real del rendimiento del firewall.

Se realizan dos pruebas secuenciales:

Carga Normal: Descarga masiva de un archivo grande y legítimo desde un servidor de alta capacidad. Esta prueba representa el throughput "bruto" o de referencia del firewall con inspección SSL/TLS activa.

Carga con 'Virus' Simulado: Descarga masiva de un archivo conocido por los motores antivirus como malicioso. Esta prueba evalúa el impacto adicional del motor AV del firewall en el throughput.

Requisitos
Un sistema operativo basado en Linux/Unix (probado en Debian/Ubuntu).

wget: Herramienta de descarga de archivos (generalmente preinstalada).

bc: Calculadora de línea de comandos para operaciones de punto flotante (sudo apt install bc o sudo yum install bc).

iproute2: Para la detección de la interfaz de red (sudo apt install iproute2 o sudo yum install iproute2).

Acceso a una interfaz de red de alta velocidad (2.5 GbE, 5 GbE, 10 GbE) en tu máquina cliente para saturar enlaces de más de 1 Gbps.

Configuración y Uso
Descarga el script:

Bash

git clone https://github.com/rubino/ngfw-throughput-test.git
cd ngfw-throughput-test
O simplemente copia el contenido del script a un archivo llamado overload.sh.

Haz el script ejecutable:

Bash

chmod +x overload.sh
Edita las variables configurables dentro del script overload.sh:

Bash

# --- Variables configurables ---
NUM_SIMULACIONES=1000 # Número de descargas simultáneas. ¡Aumenta este valor para saturar conexiones más rápidas!
URL_NORMAL="http://proof.ovh.net/files/1Gb.dat" # URL de test de alta capacidad. Prueba con otras si esta no es suficiente.
URL_VIRUS="http://66.63.187.190/work/addon.exe" # URL del archivo que simula un virus.
TIEMPO_MEDICION_SEGUNDOS=45 # Duración en segundos de cada período de medición.
# -------------------------------
NUM_SIMULACIONES: Es crucial para generar suficiente carga. Para enlaces de Gigabit, considera valores de 500 a 2000 o más, dependiendo de la capacidad de tu máquina cliente.

URL_NORMAL: http://proof.ovh.net/files/1Gb.dat es un excelente punto de partida. Si necesitas más, busca archivos de test en CDNs (Content Delivery Networks) cercanas a tu ubicación.

URL_VIRUS: Es la URL de un archivo que se espera que sea detectado por un antivirus.

Ajusta los límites del sistema (opcional pero recomendado):
Para que tu máquina cliente pueda manejar miles de conexiones simultáneas, es bueno aumentar los límites de descriptores de archivo y procesos. El script intenta hacer esto, pero puedes verificarlos manualmente:

Bash

ulimit -n 65535 # Límite de archivos abiertos
ulimit -u 65535 # Límite de procesos/hilos de usuario
Estos cambios son temporales para la sesión de terminal actual.

Ejecuta el script:

Bash

sudo ./overload.sh
(Se requiere sudo para que ip route pueda funcionar, aunque el script intenta detectar la interfaz, y para asegurar que ulimit pueda aplicarse si no eres root).

Ejemplo de Salida Limpia
Preparando el entorno para las pruebas de throughput del firewall.
URL de test normal: http://proof.ovh.net/files/1Gb.dat
URL de test con 'virus': http://66.63.187.190/work/addon.exe
La salida de wget se redireccionará a /dev/null y se ignorarán los errores de certificado.
La medición de throughput se realizará durante 45 segundos para cada prueba.
¡Los procesos de wget se terminarán automáticamente después de cada período de medición, sin mensajes de 'Killed'!

Ajustando límites del sistema para permitir más conexiones...
Límites actuales: open files=65535, max user processes=65535

Detectando interfaz de red principal...
Interfaz de red principal: eno1

===================================================
INICIANDO PRUEBA: Prueba 1: Carga Normal (http://proof.ovh.net/files/1Gb.dat)
===================================================

Iniciando 1000 descargas en segundo plano de http://proof.ovh.net/files/1Gb.dat...

Todas las descargas han sido iniciadas. Ejecutando la medición de throughput...
Midiendo el throughput durante 45 segundos...

--- RESULTADOS DE THROUGHPUT (Prueba 1: Carga Normal) ---
Bytes transferidos en la interfaz eno1 durante 45 segundos: 3796753596 Bytes
Velocidad promedio: 674.97 Mb/s
--------------------------------------------------------

Terminando procesos wget de Prueba 1: Carga Normal...
Procesos de Prueba 1: Carga Normal terminados.

===================================================
INICIANDO PRUEBA: Prueba 2: Carga con 'Virus' (http://66.63.187.190/work/addon.exe)
===================================================
¡ADVERTENCIA: Esta prueba usa una URL de un posible archivo malicioso!
Asegúrate de que tu firewall/antivirus esté activo y en un entorno seguro.

Iniciando 1000 descargas en segundo plano de http://66.63.187.190/work/addon.exe...

Todas las descargas han sido iniciadas. Ejecutando la medición de throughput...
Midiendo el throughput durante 45 segundos...

--- RESULTADOS DE THROUGHPUT (Prueba 2: Carga con 'Virus') ---
Bytes transferidos en la interfaz eno1 durante 45 segundos: 3131584944 Bytes
Velocidad promedio: 556.72 Mb/s
--------------------------------------------------------

Terminando procesos wget de Prueba 2: Carga con 'Virus'...
Procesos de Prueba 2: Carga con 'Virus' terminados.

Simulación completa. Ambas pruebas han finalizado.
Análisis de Resultados
En el ejemplo anterior:

Carga Normal: Se alcanzó una velocidad promedio de 674.97 Mb/s. Esto representa el rendimiento base del firewall con la inspección SSL/TLS activa, demostrando que tu conexión de 600 Mb/s puede ser superada (lo cual es normal, ya que la velocidad medida en la interfaz puede ser ligeramente superior a la "nominal" del ISP o puede haber picos).

Carga con 'Virus': La velocidad promedio descendió a 556.72 Mb/s. Esta caída de aproximadamente (674.97 - 556.72) = 118.25 Mb/s indica el overhead (carga adicional) que introduce el motor antivirus del firewall al inspeccionar y potencialmente bloquear el tráfico malicioso.

La URL del 'Virus'
La URL http://66.63.187.190/work/addon.exe se utiliza por su alta probabilidad de ser detectada por motores antivirus. Para verificar cómo diferentes motores AV ven esta URL, puedes consultar:

VirusTotal Report for http://66.63.187.190/work/addon.exe: https://www.virustotal.com/gui/url/cd74370b3b8888f43cac32d919dd0de684170eb1a6828ee94b7165e7526b9f40
(Nota: Los reportes de VirusTotal pueden cambiar con el tiempo a medida que los motores AV actualizan sus firmas.)

Contribuciones
Las contribuciones son bienvenidas. Si tienes sugerencias para mejorar el script, añadir más pruebas, o hacerlo más robusto, por favor, abre un issue o un pull request.
