#!/bin/bash

# Función para la enumeración rápida de subdominios
quick_enum(){
    mkdir -p "$domain/subdomains"
    
    echo "[$(date +%T)] Iniciando subfinder."
    subfinder -d "$domain" -nc -silent -o "$domain/subdomains/subfinder.txt"  > /dev/null 2>&1
    echo "[$(date +%T)] subfinder completado."
    
    echo "[$(date +%T)] Iniciando assetfinder"
    assetfinder -subs-only "$domain" | tee "$domain/subdomains/assetfinder.txt"  > /dev/null 2>&1
    echo "[$(date +%T)] assetfinder completado."
    
    # Consolidar resultados de subfinder y assetfinder
    cat "$domain/subdomains"/*.txt | sort -u > "$domain/subdomains/all.txt"
}

# Función para la enumeración completa de subdominios
full_enum(){
    mkdir -p "$domain/subdomains"
    
    echo "[$(date +%T)] Iniciando subfinder."
    subfinder -d "$domain" -nc -silent -o "$domain/subdomains/subfinder.txt"  > /dev/null 2>&1
    echo "[$(date +%T)] subfinder completado."
    
    echo "[$(date +%T)] Iniciando assetfinder"
    assetfinder -subs-only "$domain" | tee "$domain/subdomains/assetfinder.txt"  > /dev/null 2>&1
    echo "[$(date +%T)] assetfinder completado."
    
    # Enumeración pasiva con amass, con timeout y modo silencioso, se guarda en amass_raw.txt
    echo "[$(date +%T)] Iniciando amass, Este puede ser detenido con Ctrl + C, tiene timeout de 10 minutos"
    amass enum -passive -nocolor -timeout 10 -silent -d "$domain" -o "$domain/subdomains/amass_raw.txt" > /dev/null 2>&1
    
    # Obtener el primer dominio en cada línea  de amass_raw.txt
    awk '{print $1}' "$domain/subdomains/amass_raw.txt" > "$domain/subdomains/amass_first.txt"
    
    # Obtener el último dominio en cada línea de amass_raw.txt 
    awk '{print $(NF-1)}' "$domain/subdomains/amass_raw.txt" > "$domain/subdomains/amass_last.txt"
    

    # Combinar amass_first.txt y amass_last.txt en amass_combined.txt, una línea por dominio
    paste -d '\n' "$domain/subdomains/amass_first.txt" "$domain/subdomains/amass_last.txt" > "$domain/subdomains/amass_combined.txt"
    
    # Filtrar líneas que terminan con ".$domain" y guardar en amass_filtered.txt
    awk -v domain="$domain" '$0 ~ "\\."domain"$"' "$domain/subdomains/amass_combined.txt" > "$domain/subdomains/amass_filtered.txt"
    echo "[$(date +%T)] amass completado."

    
    # Eliminar archivos temporales utilizados en el proceso de amass
    rm "$domain/subdomains/amass_raw.txt" "$domain/subdomains/amass_first.txt" "$domain/subdomains/amass_last.txt" "$domain/subdomains/amass_combined.txt" 
    
    # Consolidar todos los resultados en un solo archivo
    cat "$domain/subdomains"/*.txt | sort -u > "$domain/subdomains/all.txt" 
}

# Función para ejecutar httpx-toolkit con filtros específicos y guardar el resultado en un archivo de texto
run_httpx(){
    echo "[$(date +%T)] Iniciando httpx."
    # Ejecutar httpx-toolkit y guardar el resultado en un archivo
    cat "$domain/subdomains/all.txt" | httpx-toolkit -nc -silent > "$domain/subdomains/httpx_all.txt"
    
    # Ejecutar httpx-toolkit y guardar el resultado en un archivo, solo los que responden con los códigos de respuesta especificados
    cat "$domain/subdomains/all.txt" | httpx-toolkit -nc -silent -mc 200,302 > "$domain/subdomains/httpx_200_300.txt"    
    echo "[$(date +%T)] httpx completado."
}

# Verificar que las herramientas necesarias estén instaladas
missing_tools=()
for tool in subfinder assetfinder amass httpx-toolkit; do
    if ! command -v "$tool" &> /dev/null; then
        missing_tools+=("$tool")
    fi
done

# Salir si alguna herramienta no está instalada
if [ ${#missing_tools[@]} -ne 0 ]; then
    echo "Error: Las siguientes herramientas no están instaladas: $(IFS=,; echo "${missing_tools[*]}" | sed 's/,/, /g')"
    exit 1
fi


# Pedir al usuario que ingrese el dominio
read -p "Introduce el dominio para buscar subdominios(sin www.): " domain

# Función para mostrar el menú de opciones y pedir una elección válida
choose_option(){
    echo "Elige el tipo de enumeración:"
    echo "1. Rápida (recomendada)"
    echo "2. Completa (con amass/tiene problemas)"
    echo "3. Salir"
    read -p "Opción [1/2/3]: " option
}

# Mostrar el menú y pedir la elección hasta que sea válida
choose_option
while [[ "$option" != "1" && "$option" != "2" && "$option" != "3" ]]; do
    echo "Opción no válida. Por favor, elige una opción válida."
    choose_option
done

# Ejecutar la función correspondiente según la elección del usuario
case $option in
    1)
        quick_enum
        ;;
    2)
        full_enum
        ;;
    3)
        echo "Saliendo..."
        exit 0
        ;;
esac

# Ejecutar httpx-toolkit después de la enumeración
run_httpx

echo "[$(date +%T)] Proceso completado. Los resultados están en $domain/subdomains/"
