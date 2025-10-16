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
	echo "Criando pasta do recyle_bin..."
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


    local paths=("$@")

    for file_path in "${paths[@]}"; do
	echo "Delete function called with: $file_path"

    	# Check if file exists
    	if [ ! -e "$file_path" ]; then
            echo -e "${RED}Error: File '$file_path' does not exist${NC}"
            continue
    	fi

	#verifica as permissoes do ficheiro
	if [ ! -r "$file_path" ] || [ ! -w "$file_path" ]; then
            echo -e "${RED}Error: No read/write permission for '$file_path'${NC}"
            continue
   	fi

	file_realpath=$(realpath "$file_path")
	recycle_bin_realpath=$(realpath "$RECYCLE_BIN_DIR")

	#verifica se é o recycle bin
    	if [[ "$file_realpath" == "$recycle_bin_realpath"* ]]; then
        	echo -e "${RED}Error: Cannot delete the recycle bin directory itself or its contents.${NC}"
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
            continue
	fi

	# obtem o espaço livre (em bytes) na partição onde esta o ficheiro
	# --output=avail: mostra apenas a coluna do espaco disponível
	# -B1: define a unidade em bytes
	# tail -1: corta o cabeçalho
	available_space=$(df --output=avail -B1 "$FILES_DIR" | tail -1)
   	if [ "$available_space" -lt "$file_size_bytes" ]; then
            echo -e "${RED}Error: Insufficient disk space to move '$file_path'${NC}"
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
    return 0
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
        echo "O lixo está vazio."
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
        elif [ "$size" -lt 1048576 ]; then
            echo "$((size / 1024))KB"
        elif [ "$size" -lt 1073741824 ]; then
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

    # 2. CARREGAR VARIÁVEIS DE METADADOS
    # Note que a leitura precisa de usar aspas para lidar com caminhos que contenham vírgulas
    IFS=',' read -r id name path date size type perms owner <<< "$entry"
    
    name=$(echo "$name" | tr -d '"')
    echo "$FILES_DIR/$id"
    
    id=${id// /}
    id=${id//[$'\r']/}

    # 3. VERIFICAÇÃO E CRIAÇÃO DO DIRETÓRIO PAI (do seu #3 original)
    if [[ ! -e "$FILES_DIR/$id" ]]; then
        echo -e "${RED}Error: File data not found in recycle bin (ID: $id)${NC}"
        return 1
    fi

    local restore_dir
    restore_dir=$(dirname "$path")
    
    # Cria o diretório pai se não existir
    if [[ ! -d "$restore_dir" ]]; then
        mkdir -p "$restore_dir" || {
            echo -e "${RED}Error: failed to create parent directory $restore_dir${NC}"
            return 1
        }
    fi
    
    # 4. TRATAMENTO DE CONFLITO E MOVIMENTAÇÃO (Integração de #6 no fluxo de #3)
    local move_successful=0

    # Verifica se já existe um ficheiro no destino
    if [[ -e "$path" ]]; then 
        
        echo -e "${YELLOW}Warning: A file already exists at $path. Choose an action:${NC}"
        PS3="Chose action (1-3): "
        options=("Overwrite existing file" "Restore with modified name (append timestamp)" "Cancel restore")
        
        select opt in "${options[@]}"; do
            case $REPLY in
                1)
                    # Opção 1: Sobrescrever (Overwrite)
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
                    # Opção 2: Restaurar com Nome Personalizado
                    local dir="$(dirname -- "$path")"
                    local newpath=""
                    local valid_name=0

                    while [[ "$valid_name" -eq 0 ]]; do
                        # 1. Solicita o novo nome ao utilizador
                        read -r -p "Enter new filename (e.g., nome_novo.txt): " newbase
                        
                        if [[ -z "$newbase" ]]; then
                            echo -e "${YELLOW}Filename cannot be empty. Please try again.${NC}"
                            continue
                        fi

                        newpath="$dir/$newbase"
                        
                        # 2. Verifica se o nome escolhido já existe
                        if [[ -e "$newpath" ]]; then
                            echo -e "${YELLOW}A file/directory named '$newbase' already exists in the destination. Choose another name or press Enter to try again.${NC}"
                            # Permite que o loop repita e peça um nome diferente
                            continue
                        fi
                        
                        # Se não for vazio e não existir, o nome é válido
                        valid_name=1 
                    done
                    
                    # 3. Movimenta o ficheiro para o novo caminho
                    if mv -- "$FILES_DIR/$id" "$newpath"; then
                        echo -e "${GREEN}Restored as $newpath${NC}"
                        path="$newpath" # CRÍTICO: Atualiza $path para os passos seguintes (chmod/chown/metadata)
                        move_successful=1
                        break
                    else
                        echo -e "${RED}Error: failed to restore with modified name.${NC}"
                        return 1
                    fi
                    ;;
                3)
                    # Opção 3: Cancelar
                    echo -e "${YELLOW}Restore cancelled by user.${NC}"
                    return 1
                    ;;
                *)
                    echo "Invalid choice. Enter 1, 2 or 3."
                    ;;
            esac
        done
    else
        # Se NÃO houver conflito, faz a movimentação simples (do seu #3 original)
        if mv "$FILES_DIR/$id" "$path"; then
            echo -e "${GREEN}File restored successfully to $path${NC}"
            move_successful=1
        else
            echo -e "${RED}Error: Failed to restore file (mv command failed).${NC}"
            return 1 
        fi
    fi

    # Se a movimentação falhou por qualquer motivo não capturado, aborta.
    if [[ "$move_successful" -eq 0 ]]; then
        echo -e "${RED}Internal Error: File was not moved successfully.${NC}"
        return 1
    fi
    
    # 5. RESTAURAR PERMISSÕES E PROPRIETÁRIO (Se o ficheiro foi movido com sucesso)
    
    # Restaura Permissões (chmod)
    chmod "$perms" "$path" 2>/dev/null
    if [[ $? -eq 0 ]]; then 
        echo -e "${GREEN}Restored original permissions: $perms${NC}"
    else
        echo -e "${YELLOW}Warning: Failed to restore permissions (${perms}). Check execution user.${NC}"
    fi

    # Restaura Proprietário e Grupo (chown)
    # A chamada ao 'chown' é feita SEM sudo e o seu erro de sistema é descartado (2>/dev/null).
    # O script continua e o $? é usado para saber se a operação foi bem-sucedida ou não.
    if chown "$owner" "$path" 2>/dev/null; then 
        # Apenas mostra esta mensagem se o chown realmente conseguiu
        echo -e "${GREEN}Restored original owner: $owner${NC}"
    else
        # Se falhou (na maioria dos casos, por falta de root), mostra o nosso aviso
        echo -e "${YELLOW}Warning: Could not restore ownership to ${owner}. Elevated permissions (root) are required for this step.${NC}"
    fi
    
    # 6. REMOVER REGISTO DE METADADOS (O script chega sempre aqui, independentemente do chown)
    
    if grep -q "^$id," "$METADATA_FILE"; then
        sed -i "/^$id,/d" "$METADATA_FILE"
        echo -e "${GREEN}Metadata entry for ID '$id' removed.${NC}"
    else
        echo -e "${YELLOW}Warning: Metadata entry not found for ID '$id'.${NC}"
    fi

    return 0
}

    # Your code here
    # Hint: Search metadata for matching ID
    # Hint: Get original path from metadata
    # Hint: Check if original path exists
    # Hint: Move file back and restore permissions
    # Hint: Remove entry from metadata


#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
    # TODO: Implement this function

    # Your code here
    # Hint: Ask for confirmation
    # Hint: Delete all files in FILES_DIR
    # Hint: Reset metadata file
    return 0
}

#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
search_recycled() {
    # TODO: Implement this function
    local pattern="$1"

    # Your code here
    # Hint: Use grep to search metadata

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
	delete <file> 		Move file/directory to recycle bin
	list			List all items in recycle bin
	restore <id> or <filename>		Restore file by ID or Name
	search <pattern>	Search for files by name
	empty			Empty recycle bin permanently
	help			Display this help message
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
        empty)
            empty_recyclebin
            ;;
        help|--help|-h)
            display_help
            ;;
        *)
            echo "Invalid option. Use 'help' for usage information."
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
