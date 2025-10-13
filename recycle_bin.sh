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
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELE-
TION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"
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
    # TODO: Implement this function
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
    # TODO: Implement this function
    echo "=== Recycle Bin Contents ==="
    # Your code here
    # Hint: Read metadata file and format output
    # Hint: Use printf for formatted table
    # Hint: Skip header line

    return 0
}

#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
    # TODO: Implement this function

    local file_id="$1"
    if [ -z "$file_id" ]; then
        echo -e "${RED}Error: No file ID specified${NC}"
        return 1
    fi

    # Your code here
    # Hint: Search metadata for matching ID
    # Hint: Get original path from metadata
    # Hint: Check if original path exists
    # Hint: Move file back and restore permissions
    # Hint: Remove entry from metadata
    return 0
}

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
	restore <id>		Restore file by ID
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
            list_recycled
            ;;
        restore)
            restore_file "$2"
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
