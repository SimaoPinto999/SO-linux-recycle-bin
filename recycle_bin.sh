#################################################
# Linux Recycle Bin Simulation
# Author: Simão Pinto
# Date: 13/10/2025
# Description: Shell-based recycle bin system
#################################################

# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
MAX_SIZE_MB=1024
RETENTION_DAYS=30 #ainda nao usado
#teste123

# Color codes for output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#################################################
# Function: initialize_recyclebin
# Description: Creates recycle bin directory structure
# Parameters: None
# Returns: 0 on success, 1 on failure
#################################################
initialize_recyclebin() {
    if [ ! -d "$RECYCLE_BIN_DIR" ]; then
	echo "Creating recycle_bin directory..."
        mkdir -p "$FILES_DIR"
        touch "$METADATA_FILE"
        echo "# Recycle Bin Metadata" > "$METADATA_FILE"
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"
	touch "$LOG_FILE"
	echo "# Recycle Bin Log" > "$LOG_FILE"
	touch "$CONFIG_FILE"
	echo "# Recycle Bin Config" > "$CONFIG_FILE"
        echo "Recycle bin initialized at $RECYCLE_BIN_DIR"
	#TODO: implementar limpeza automatica dos ficheiros com mais de 30 dias
        return 0
    fi
    return 0
}

#################################################
# Function: generate_unique_id
# Description: Generates unique ID for deleted files
# Parameters: None
# Returns: Prints unique ID to stdout
#################################################
generate_unique_id() {
    local timestamp=$(date +%s)
    local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
    echo "${timestamp}_${random}"
}

#################################################
# Function: delete_file
# Description: Moves file/directory to recycle bin
# Parameters: $1 - path to file/directory
# Returns: 0 on success, 1 on failure
#################################################
delete_file() { 
    if [ "$#" -eq 0 ]; then
        echo -e "${RED}Error: No file specified${NC}"
        return 1
    fi
    
    # Your code here
    # Hint: Get file metadata using stat command
    # Hint: Generate unique ID
    # Hint: Move file to FILES_DIR with unique ID
    # Hint: Add entry to metadata file

    local exit_code=0
    local paths=("$@")

    for file_path in "${paths[@]}"; do
        echo "Delete function called with: $file_path"

            if [ ! -e "$file_path" ]; then
                echo -e "${RED}Error: File '$file_path' does not exist${NC}"
                exit_code=1
                continue
            fi

        #verifica as permissoes do ficheiro
        if [ ! -r "$file_path" ] || [ ! -w "$file_path" ]; then
                echo -e "${RED}Error: No read/write permission for '$file_path'${NC}"
                exit_code=1
                continue
        fi

        file_realpath=$(realpath "$file_path")
        recycle_bin_realpath=$(realpath "$RECYCLE_BIN_DIR")

        #verifica se é o recycle bin
            if [[ "$file_realpath" == "$recycle_bin_realpath"* ]]; then
                echo -e "${RED}Error: Cannot delete the recycle bin directory itself or its contents.${NC}"
                exit_code=1
                continue
        fi

        #Calcular o tamanho do ficheiro/diretorio
        if [ -d "$file_path" ]; then
                file_size_bytes=$(du -sb "$file_path" | cut -f1)
        else
                file_size_bytes=$(stat -c %s "$file_path")
        fi

        file_size_mb=$((file_size_bytes / 1024 / 1024))

        if [ "$file_size_mb" -gt "$MAX_SIZE_MB" ]; then
                echo -e "${RED}Error: File/Directory '$file_path' exceeds maximum size limit of ${MAX_SIZE_MB}MB (${file_size_mb}MB)${NC}"
                exit_code=1
                continue
        fi

        # obtem o espaço livre (em bytes) na partição onde esta o ficheiro
        # --output=avail: mostra apenas a coluna do espaco disponível
        # -B1: define a unidade em bytes
        # tail -1: corta o cabeçalho
        available_space=$(df --output=avail -B1 "$FILES_DIR" | tail -1)
        if [ "$available_space" -lt "$file_size_bytes" ]; then
                echo -e "${RED}Error: Insufficient disk space to move '$file_path'${NC}"
                exit_code=1
                continue
            fi

        #atributos para escrever no metadata
        file_id=$(generate_unique_id)
        file_name=$(basename "$file_path")
        deletion_date=$(date "+%Y-%m-%d %H:%M:%S")
        file_size=$(stat -c %s "$file_path")
        file_type=$([ -d "$file_path" ] && echo "directory" || echo "file")
        file_perms=$(stat -c %a "$file_path")
        file_owner=$(stat -c "%U:%G" "$file_path")
        
        local escaped_path=$(echo "$file_realpath" | sed 's/[\/&]/\\&/g')
        sed -i "/$escaped_path/d" "$METADATA_FILE" 2>/dev/null

        mv "$file_realpath" "$FILES_DIR/$file_id"
        retcode=$?
        if [ $retcode -eq 0 ]; then
            echo -e "${GREEN}Sucessful $file_name delete!${NC}"
            echo "$file_id,$file_name,$file_realpath,$deletion_date,$file_size,$file_type,$file_perms,$file_owner" >> "$METADATA_FILE"
            echo "[$deletion_date] Successful [DELETE] $file_name ($file_realpath) ID:$file_id USER:$file_owner" >> "$LOG_FILE"
        else
            echo -e "${RED}mv funcion failed with $retcode code error${NC}"
        fi
    done

    return $exit_code
}

#################################################
# Function: list_recycled
# Description: Lists all items in recycle bin
# Parameters: None
# Returns: 0 on success
#################################################
list_recycled() {
    local detailed=false
    local total_size=0
    local item_count=0

    if [ "$2" == "--detailed" ]; then
        detailed=true
    fi

    #verifica se o lixo está vazio a partir do ficheiro metadata
    if [ ! -s "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE") -le 2 ]; then
        echo -e "${YELLOW}The recycle bin is empty. Nothing to show.${NC}"
        return 0
    fi

    echo -e "\n=============== Recycle Bin Contents ===============\n"

    if [ "$detailed" = false ]; then
        printf "${GREEN}%-18s${NC} | ${GREEN}%-30s${NC} | ${GREEN}%-20s${NC} | ${GREEN}%-10s${NC}\n" "Unique ID" "Original Filename" "Deletion Date" "File Size"
        printf "%-18s-+-%-30s-+-%-20s-+-%-10s\n" "------------------" "------------------------------" "--------------------" "----------"
    fi

    while IFS=',' read -r id name path date size type perms owner; do
        [ -z "$id" ] && continue

        item_count=$((item_count + 1))
        total_size=$((total_size + size))
        
        local human_size=$(human_readable_size "$size")

        if [ "$detailed" = true ]; then
            echo -e "${GREEN}--------------- Item $item_count ---------------${NC}"
            echo "ID:                 $id"
            echo "Nome Original:      $name"
            echo "Caminho Original:   $path"
            echo "Data de Eliminação: $date"
            echo "Tamanho:            $human_size ($size B)"
            echo "Tipo:               $type"
            echo "Permissões:         $perms"
            echo "Proprietário:       $owner"
        else
            local display_name=$(echo "$name" | cut -c 1-25)
            if [ "${#name}" -gt 25 ]; then
                display_name="${display_name}..."
            fi

            printf "%-18s | %-30s | %-20s | %-10s\n" "$id" "$display_name" "$date" "$human_size"
        fi
    done < <(tail -n +3 "$METADATA_FILE")
    
    local total_size_hr=$(human_readable_size "$total_size")
    echo ""
    echo -e "Total item count: ${GREEN}$item_count${NC}"
    echo -e "Total storage used: ${GREEN}$total_size_hr ($total_size B)${NC}"
    echo ""

    return 0
}

#################################################
# Function: human_readable_size
# Description: Helper funcion which converts file size in bytes to human-readable format (B, KB, MB, GB)
# Parameters: $1 - file size in bytes
# Returns: Human-readable file size depending on size
#################################################
human_readable_size() {
        local size=$1   
        if [ "$size" -lt 1024 ]; then
            echo "${size}B"
        elif [ "$size" -lt 1048576 ]; then #1024**2
            echo "$((size / 1024))KB"
        elif [ "$size" -lt 1073741824 ]; then #1024**3
            echo "$((size / 1048576))MB"
        else
            echo "$((size / 1073741824))GB"
        fi
}

#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
    local file_id="$1"
    if [ -z "$file_id" ]; then
        echo -e "${RED}Error: No file ID specified${NC}"
        return 1
    fi

    local input="$1"
    local entry

    entry=$(awk -F',' -v q="$input" '
        NR>2 {
            name=$2
            gsub(/^"|"$/, "", name)
            
            if ($1==q || name==q) {
                print; exit
            }
        }
    ' "$METADATA_FILE")

    if [[ -z "$entry" ]]; then
        echo -e "${RED}Error: No file found with ID or name '$input'${NC}"
        return 1
    fi

    echo "Input encontrado: $entry"

    IFS=',' read -r id name path date size type perms owner <<< "$entry"
    
    name=$(echo "$name" | tr -d '"')
    echo "$FILES_DIR/$id"
    
    id=${id// /}
    id=${id//[$'\r']/}

    if [[ ! -e "$FILES_DIR/$id" ]]; then
        echo -e "${RED}Error: File data not found in recycle bin (ID: $id)${NC}"
        return 1
    fi

    local restore_dir
    restore_dir=$(dirname "$path")
    
    if [[ ! -d "$restore_dir" ]]; then
        mkdir -p "$restore_dir" || {
            echo -e "${RED}Error: failed to create parent directory $restore_dir${NC}"
            return 1
        }
    fi
    
    local move_successful=0

    if [[ -e "$path" ]]; then 
        
        echo -e "${YELLOW}Warning: A file already exists at $path. Choose an action:${NC}"
        PS3="Chose action (1-3): "
        options=("Overwrite existing file" "Restore with modified name (append timestamp)" "Cancel restore")
        
        select opt in "${options[@]}"; do
            case $REPLY in
                1)
                    if mv -f -- "$FILES_DIR/$id" "$path"; then
                        echo -e "${GREEN}Overwrote existing file and restored to $path${NC}"
                        move_successful=1
                        break
                    else 
                        echo -e "${RED}Error: failed to overwrite and restore.${NC}"
                        return 1
                    fi
                    ;;
                2) 
                    local dir="$(dirname -- "$path")"
                    local newpath=""
                    local valid_name=0

                    while [[ "$valid_name" -eq 0 ]]; do
                        read -r -p "Enter new filename (e.g., nome_novo.txt): " newbase
                        
                        if [[ -z "$newbase" ]]; then
                            echo -e "${YELLOW}Filename cannot be empty. Please try again.${NC}"
                            continue
                        fi

                        newpath="$dir/$newbase"
                        
                        if [[ -e "$newpath" ]]; then
                            echo -e "${YELLOW}A file/directory named '$newbase' already exists in the destination. Choose another name or press Enter to try again.${NC}"
                            continue
                        fi
                        
                        valid_name=1 
                    done
                    
                    if mv -- "$FILES_DIR/$id" "$newpath"; then
                        echo -e "${GREEN}Restored as $newpath${NC}"
                        path="$newpath"
                        move_successful=1
                        break
                    else
                        echo -e "${RED}Error: failed to restore with modified name.${NC}"
                        return 1
                    fi
                    ;;
                3)
                    echo -e "${YELLOW}Restore cancelled by user.${NC}"
                    return 1
                    ;;
                *)
                    echo "Invalid choice. Enter 1, 2 or 3."
                    ;;
            esac
        done
    else
        if mv "$FILES_DIR/$id" "$path"; then
            echo -e "${GREEN}File restored successfully to $path${NC}"
            move_successful=1
        else
            echo -e "${RED}Error: Failed to restore file (mv command failed).${NC}"
            return 1 
        fi
    fi

    if [[ "$move_successful" -eq 0 ]]; then
        echo -e "${RED}Internal Error: File was not moved successfully.${NC}"
        return 1
    fi
    
    
    chmod "$perms" "$path" 2>/dev/null
    if [[ $? -eq 0 ]]; then 
        echo -e "${GREEN}Restored original permissions: $perms${NC}"
    else
        echo -e "${YELLOW}Warning: Failed to restore permissions (${perms}). Check execution user.${NC}"
    fi

    if chown "$owner" "$path" 2>/dev/null; then 
        echo -e "${GREEN}Restored original owner: $owner${NC}"
    else
        echo -e "${YELLOW}Warning: Could not restore ownership to ${owner}. Elevated permissions (root) are required for this step.${NC}"
    fi
    
    
    if grep -q "^$id," "$METADATA_FILE"; then
        sed -i "/^$id,/d" "$METADATA_FILE"
        echo -e "${GREEN}Metadata entry for ID '$id' removed.${NC}"
    else
        echo -e "${YELLOW}Warning: Metadata entry not found for ID '$id'.${NC}"
    fi

    return 0
}


#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
    local target="$1"

    local skip_confirmation=false
    
    #verifica se o primeiro argumento é --force
    if [[ "$target" == "--force" ]]; then
        skip_confirmation=true
        target=""
    fi

    if [ ! -s "$METADATA_FILE" ] || [[ $(wc -l < "$METADATA_FILE" 2>/dev/null) -le 2 ]]; then
        echo -e "${YELLOW}The recycle bin is already empty.${NC}"
        return 0
    fi
    
    #modo1: apaga pelo id
    if [ -n "$target" ]; then 
        local id_target="$target"
        
        echo -e "${BLUE}Attempting to permanently delete item with ID: $id_target...${NC}"

        local entry
        entry=$(awk -F',' -v q="$id_target" '
            # Pesquisa por ID na coluna 1
            NR>2 && $1==q {
                print; exit
            }
        ' "$METADATA_FILE")

        if [[ -z "$entry" ]]; then
            echo -e "${RED}Error: No item found with ID '$id_target' in the recycle bin metadata.${NC}"
            return 1
        fi

        #extrair e limpar dados
        IFS=',' read -r id name path date size type perms owner <<< "$entry"
        
        id=$(echo "$id" | tr -d '[:space:]')
        id=${id//[$'\r']/}
        name=$(echo "$name" | tr -d '"')

        #apagar o ficheiro
        local file_path_in_trash="$FILES_DIR/$id"
        
        if [[ -e "$file_path_in_trash" ]]; then
            if rm -rf "$file_path_in_trash" 2>/dev/null; then
                echo -e "${GREEN}Successfully deleted physical file: $name (ID: $id).${NC}"
            else
                echo -e "${RED}Error: Failed to delete physical file $name. Check permissions or file lock.${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}Warning: Physical file for ID '$id' not found in storage. Cleaning metadata.${NC}"
        fi

        #remove dados do metadata
        if grep -q "^$id," "$METADATA_FILE"; then
            sed -i "/^$id,/d" "$METADATA_FILE" 2>/dev/null
            echo -e "${GREEN}Metadata entry for '$name' (ID: $id) removed.${NC}"
        else
            echo -e "${YELLOW}Warning: Metadata entry for ID '$id' not found after processing.${NC}"
        fi
        
        #log
        local deletion_date=$(date "+%Y-%m-%d %H:%M:%S")
        echo "[$deletion_date] Successful [PERMANENT DELETE] $name (ID:$id) from recycle bin." >> "$LOG_FILE"
        
    #modo2: apagar tudo
    else 
        #confirmação
        if [[ "$skip_confirmation" != true ]]; then
            echo -e "${YELLOW}WARNING: This action is irreversible and will permanently delete ALL contents of the recycle bin.${NC}"
            read -r -p "Are you sure you want to empty the ENTIRE recycle bin? (yes/no): " confirmation

            if [[ ! "$confirmation" =~ ^[Yy][Ee][Ss]$ ]]; then
                echo -e "${GREEN}Operation cancelled.${NC}"
                return 0
            fi
        fi
        
        #apagar ficheiros
        echo -e "${BLUE}Deleting physical files from $FILES_DIR...${NC}"
        
        if find "$FILES_DIR" -mindepth 1 -delete 2>/dev/null; then
            echo -e "${GREEN}Successfully deleted all files from the recycle bin storage.${NC}"
        else
            echo -e "${RED}Error: Failed to delete all physical files from $FILES_DIR. Check permissions.${NC}"
        fi

        #lmpar metadata
        if sed -i '3,$d' "$METADATA_FILE" 2>/dev/null; then
            echo -e "${GREEN}Metadata file successfully cleared.${NC}"
        else
            echo -e "${RED}Error: Failed to clear metadata file ($METADATA_FILE).${NC}"
            return 1
        fi

        echo -e "${GREEN}Recycle bin successfully emptied.${NC}"
        
        #log
        local deletion_date=$(date "+%Y-%m-%d %H:%M:%S")
        echo "[$deletion_date] Successful [EMPTY ALL] Recycle bin emptied." >> "$LOG_FILE"
    fi
    return 0
}

#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
search_recycled() {
    local pattern="$1"
    local search_results
    local item_count=0

    if [ -z "$pattern" ]; then
        echo -e "${RED}Error: No search pattern specified.${NC}"
        return 1
    fi
    
    if [ ! -s "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE") -le 2 ]; then
        echo -e "${YELLOW}The recycle bin is empty. Nothing to search.${NC}"
        return 0
    fi

    echo -e "\n=============== Search Results for '${GREEN}$pattern${NC}' ==============\n"

    local safe_pattern=$(escape_regex "$pattern")
    search_results=$(tail -n +3 "$METADATA_FILE" | grep -iE "$safe_pattern" || true)

    if [ -z "$search_results" ]; then
        echo -e "${YELLOW}No items found matching the pattern '$pattern'.${NC}"
        return 0
    fi
    
    printf "${GREEN}%-18s${NC} | ${GREEN}%-30s${NC} | ${GREEN}%-20s${NC} | ${GREEN}%-10s${NC}\n" "Unique ID" "Original Filename" "Deletion Date" "File Size"
    printf "%-18s-+-%-30s-+-%-20s-+-%-10s\n" "------------------" "------------------------------" "--------------------" "----------"

    while IFS=',' read -r id name path date size type perms owner; do
        [ -z "$id" ] && continue
        
        name=$(echo "$name" | tr -d '"')
        
        item_count=$((item_count + 1))
        local human_size=$(human_readable_size "$size")
        
        local display_name=$(echo "$name" | cut -c 1-25)
        if [ "${#name}" -gt 25 ]; then
            display_name="${display_name}..."
        fi

        printf "%-18s | %-30s | %-20s | %-10s\n" "$id" "$display_name" "$date" "$human_size"
    done <<< "$search_results"

    echo ""
    echo -e "Total items found: ${GREEN}$item_count${NC}"
    echo ""

    return 0
}

#################################################
# Function: escape_regex
# Description: Helper function that escapes regex special characters for literal search
# Parameters: $1 - string to escape
# Returns: Prints escaped string to stdout
#################################################
escape_regex() {
    # Lista de caracteres de regex a escapar:
    # . \ + * ? [ ] ^ $ ( ) { } | /
    local escaped_pattern=$(echo "$1" | sed 's/[.\[\]\*\+\?\\\/\^$(){}|]/\\&/g')
    echo "$escaped_pattern"
}

#################################################
# Function: show_statistics
# Description: Displays statistics about the recycle bin contents.
# Parameters: None
# Returns: 0 on success
#################################################

show_statistics(){
    local item_count=0
    local total_size_bytes=0
    local file_count=0
    local dir_count=0
    local oldest_date=""
    local newest_date=""
    local newest_item=""
    local oldest_item=""
    local count_loop=0 # Para calcular a média

    if [ ! -s "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE") -le 2 ]; then
        echo -e "${YELLOW}The recycle bin is empty. Nothing to show.${NC}"
        return 0
    fi

    echo -e "\n=============== Recycle Bin Statistics ==============="

    while IFS=',' read -r id name path date size type perms owner; do
        if [ "$id" = "ID" ] || [ "$id" = "# Recycle Bin Metadata" ]; then
            continue
        fi

        if ! [[ "$size" =~ ^[0-9]+$ ]]; then
            size=0
        fi

        item_count=$((item_count + 1))
        total_size_bytes=$((total_size_bytes + size))
        count_loop=$((count_loop + 1))

        if [ "$type" = "file" ]; then
            file_count=$((file_count + 1))
        elif [ "$type" = "directory" ]; then
            dir_count=$((dir_count + 1))
        fi

        local current_timestamp=$(date -d "$date" +%s)
        
        if [ -z "$oldest_date" ] || [ "$current_timestamp" -lt "$(date -d "$oldest_date" +%s)" ]; then
            oldest_date="$date"
            oldest_item="$name"
        fi

        if [ -z "$newest_date" ] || [ "$current_timestamp" -gt "$(date -d "$newest_date" +%s)" ]; then
            newest_date="$date"
            newest_item="$name"
        fi

    done < "$METADATA_FILE"

    echo -e "${GREEN}Total Items:${NC} $item_count"
    
    echo "- Files: $file_count ($(calculate_percentage $file_count $item_count)%)"
    echo "- Directories: $dir_count ($(calculate_percentage $dir_count $item_count)%)"

    local avg_size_bytes=0
    if [ "$item_count" -gt 0 ]; then
        # Nota: Usamos 'bc' para garantir a divisão correta (ponto flutuante)
        avg_size_bytes=$(echo "scale=0; $total_size_bytes / $item_count" | bc)
    fi
    local avg_size_hr=$(human_readable_size "$avg_size_bytes")
    echo -e "${GREEN}Average Item Size:${NC} $avg_size_hr"

    local max_size_bytes=$((MAX_SIZE_MB * 1024 * 1024))
    local usage_percentage=$(calculate_percentage $total_size_bytes $max_size_bytes)
    local total_size_hr=$(human_readable_size "$total_size_bytes")

    echo -e "${GREEN}Storage Used:${NC} $total_size_hr"
    echo "- Max Size: ${MAX_SIZE_MB}MB"
    echo "- Usage Percentage: ${usage_percentage}%"

    # Requisito 4: Show oldest and newest items
    echo -e "${GREEN}Age Analysis:${NC}"
    echo "- Oldest Change: $oldest_item (Date: $oldest_date)"
    echo "- Newest Change: $newest_item (Date: $newest_date)"

    echo "===================================================="

    return 0
}

#################################################
# Function: calculate_percentage
# Description: Helper function which calculates the percentage of a value relative to a total
# Parameters: $1 - value, $2 - total
# Returns: Prints percentage rounded to 2 decimal places
#################################################
calculate_percentage() {
    local value=$1
    local total=$2
    if [ "$total" -eq 0 ]; then
        echo "0.00"
        return
    fi

    echo "scale=2; ($value / $total) * 100" | bc
}

#################################################
# Function: auto_cleanup
# Description: Permanently deletes files older than RETENTION_DAYS
# Parameters: None
# Returns: 0 on success
#################################################
auto_cleanup() {
    local deletion_date=$(date "+%Y-%m-%d %H:%M:%S")
    local removed_count=0
    
    echo "[$deletion_date] Running [AUTO CLEANUP] for items older than $RETENTION_DAYS days..." >> "$LOG_FILE"
    
    find "$FILES_DIR" -type f -mtime +"$RETENTION_DAYS" -print0 | while IFS= read -r -d $'\0' expired_path; do
        local expired_id=$(basename "$expired_path")
        
        if grep -q "^$expired_id," "$METADATA_FILE"; then
            sed -i "/^$expired_id,/d" "$METADATA_FILE" 2>/dev/null
            
            if rm -rf "$expired_path" 2>/dev/null; then
                removed_count=$((removed_count + 1))
                echo "[$deletion_date] Successful [CLEANUP] Item ID: $expired_id permanently removed." >> "$LOG_FILE"
            else
                echo "[$deletion_date] ERROR [CLEANUP] Failed to remove physical file: $expired_path." >> "$LOG_FILE"
            fi
        else
            if rm -rf "$expired_path" 2>/dev/null; then
                echo "[$deletion_date] Successful [CLEANUP] Removed orphan file: $expired_id." >> "$LOG_FILE"
            fi
        fi

    done

    if [ "$removed_count" -gt 0 ]; then
        echo -e "${GREEN}Cleanup finished! $removed_count item(s) older than $RETENTION_DAYS days were permanently deleted.${NC}"
    else
        echo -e "${YELLOW}Cleanup finished! No items older than $RETENTION_DAYS days found for deletion.${NC}"
    fi
    
    return 0
}

check_quota() {
    #o MAX_SIZE_MB está em MB, mas o du -sb dá a saída em bytes.
    local max_size_bytes=$((MAX_SIZE_MB * 1024 * 1024))
    local current_size_bytes=0

    #calcular o tamanho atual
    if [ -d "$FILES_DIR" ]; then
        current_size_bytes=$(du -sb "$FILES_DIR" 2>/dev/null | cut -f1)
    fi

    #verificar se o size for 0, ou seja, se for zero está vazio 
    if [ -z "$current_size_bytes" ]; then
        current_size_bytes=0
    fi
    
    #converter o current sizer de bytes para megabytes 
    local current_size_mb=$((current_size_bytes / 1024 / 1024))
    
    #verificar se o current size é maior que o maximo size bytes 
    if [ "$current_size_bytes" -gt "$max_size_bytes" ]; then
        
        echo -e "\n${RED}================== QUOTA EXCEDIDA ===================${NC}"
        echo -e "${RED}WARNING:${NC} O Recycle Bin excedeu o limite máximo de ${MAX_SIZE_MB}MB."
        echo -e "${RED}Uso Atual:${NC} ${current_size_mb}MB (Limite: ${MAX_SIZE_MB}MB)"
        echo -e "${RED}=====================================================${NC}\n"

        #usar auto_cleanup 
        if command -v auto_cleanup >/dev/null 2>&1; then
            echo -e "${YELLOW}A iniciar limpeza automática (auto_cleanup) para liberar espaço...${NC}"
            
            if auto_cleanup; then
                echo -e "${GREEN}Limpeza automática concluída com sucesso. Por favor, verifique o quota novamente.${NC}"
            else
                echo -e "${RED}Erro: A limpeza automática falhou em liberar espaço. Quota continua excedida.${NC}"
                return 2
            fi
            
        else
            echo -e "${YELLOW}AVISO: A função auto_cleanup não está acessível. A limpeza automática não pode ser executada.${NC}"
        fi
        
        return 1
    else
        #quota ok
        local current_size_hr=$(human_readable_size "$current_size_bytes")
        echo -e "${BLUE}Quota Check OK:${NC} Uso atual: ${current_size_hr} (Limite: ${MAX_SIZE_MB}MB)"
        return 0 
    fi
}

preview_file() {
    local id_target="$1"

    if [ -z "$id_target" ]; then
        echo -e "${RED}Error: No file ID specified for preview.${NC}"
        return 1
    fi

    #pesquisar no metadata, se não for encontrado um id_target igual ao $1 do metadata dá erro 
    local entry
    entry=$(awk -F',' -v q="$id_target" '
        NR>2 && $1==q {
            print; exit
        }
    ' "$METADATA_FILE")

    if [[ -z "$entry" ]]; then
        echo -e "${RED}Error: Item with ID '$id_target' not found in the recycle bin.${NC}"
        return 1
    fi

    #extrair info
    IFS=',' read -r id name path date size type perms owner <<< "$entry"
    
    id=$(echo "$id" | tr -d '[:space:]')
    id=${id//[$'\r']/}
    name=$(echo "$name" | tr -d '"')

    local file_path_in_trash="$FILES_DIR/$id"
    
    #verificar se o ficheiro realmente existe no lixo
    if [[ ! -e "$file_path_in_trash" ]]; then
        echo -e "${RED}Error: File data for ID '$id' is missing from storage (${FILES_DIR}).${NC}"
        return 1
    fi


    #preview do ficheiro
    echo -e "\n${BLUE}========== Preview for ${name} (ID: ${id}) ==========${NC}"
    echo "Tipo: $type"
    echo "Caminho Original: $path"
    echo "Data de Eliminação: $date"
    echo "Tamanho: $(human_readable_size "$size")"

    #determinar o tipo de ficheiro e mostrar o conteudo
    local file_type_info=$(file -b "$file_path_in_trash")

    #verifica se é um ficheiro texto
    if [[ "$file_type_info" =~ text|script ]]; then
        echo -e "${GREEN}--- Primeiras 10 linhas (Texto/Script) ---${NC}"
        head -n 10 "$file_path_in_trash"
        echo -e "${GREEN}------------------------------------------${NC}"
        
    #trata de ficheiro binário
    else
        echo -e "${YELLOW}--- Ficheiro Binário/Não-Texto Detectado ---${NC}"
        echo "Informação Detalhada do Ficheiro (comando 'file'):"
        echo -e "-> ${file_type_info}"
        echo -e "${YELLOW}--- Não é possível mostrar o conteúdo ---${NC}"
    fi

    echo -e "${BLUE}===================================================${NC}\n"
    
    return 0
}

#################################################
# Function: display_help
# Description: Shows usage information
# Parameters: None
# Returns: 0
#################################################
display_help() {
    cat << EOF
Linux Recycle Bin - Usage Guide

SYNOPSIS:
	$0 [OPTION] [ARGUMENTS]

OPTIONS:
	1. delete <file>-------------------Move file/directory to recycle bin
	2. list----------------------------List all items in recycle bin
	3. restore <id> or <filename>------Restore file by ID or Name
	4. search <pattern>----------------Search for files by name
	5. preview <ID>--------------------Show first 10 lines of a text file
	6. quota---------------------------Check storage usage against MAX_SIZE 
	7. empty---------------------------Permanently delete all items
	    8. empty <ID>----------------------Delete single item by ID
	    9. empty --force ------------------Flag to skip delete confirmation  
	10. help----------------------------Display this help message
EXAMPLES:
	$0 delete myfile.txt
	$0 list
	$0 restore 1696234567_abc123
	$0 search "*.pdf"
	$0 empty
EOF
    return 0
}

#################################################
# Function: main
# Description: Main program logic
# Parameters: Command line arguments
# Returns: Exit code
#################################################
main() {
    # Initialize recycle bin
    initialize_recyclebin

    # Parse command line arguments
    case "$1" in
        delete)
            shift
            delete_file "$@"
            ;;
        list)
            list_recycled "$@"
            ;;
        restore)
            shift
            restore_file "$@"
            ;;
        search)
            search_recycled "$2"
            ;;
        preview)
            preview_file "$2"
            ;;
        quota)
            check_quota
            ;;
        empty)
            empty_recyclebin "$2"
            ;;
        help|--help|-h)
            display_help
            ;;
        statistics|stats)
            show_statistics
            ;;
        *)
            echo "Invalid option. Use 'help' for usage information."
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"