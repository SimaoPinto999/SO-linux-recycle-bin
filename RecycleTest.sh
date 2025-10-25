#!/bin/bash
#################################################
# Linux Recycle Bin Simulation - Test Script
# INCLUI TESTES PARA DELETE, RESTORE, SEARCH, LIST/DETAILED E EMPTY
#################################################

# Configuração
RECYCLE_BIN_SCRIPT="./recycle_bin.sh"
if [ ! -f "$RECYCLE_BIN_SCRIPT" ]; then
    echo "Erro: Ficheiro do script principal ($RECYCLE_BIN_SCRIPT) não encontrado."
    exit 1
fi

# Variáveis globais de configuração do script principal
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Funções de Ajuda ---

# Função para resetar o ambiente antes de cada execução
reset_environment() {
    echo -e "\n${YELLOW}=====================================================${NC}"
    echo -e "${YELLOW}           REINICIANDO AMBIENTE DE TESTE             ${NC}"
    echo -e "${YELLOW}=====================================================${NC}"
    rm -rf "$RECYCLE_BIN_DIR"  # Apaga tudo para um ambiente limpo
    
    # Recria o ambiente necessário para a primeira execução
    $RECYCLE_BIN_SCRIPT help > /dev/null # Executa para garantir a inicialização
    
    # Cria ficheiros para teste
    echo "conteúdo A" > fileA.txt
    echo "conteúdo B" > FileB.DOC
    mkdir -p dir_to_delete/sub_folder
    echo "conteúdo em pasta" > dir_to_delete/sub_folder/subfile.log
    touch "file with spaces #@.pdf"
    
    # Ficheiro para testar o conflito no restore
    touch "file_to_restore_conflict.txt"
    echo "original content" > file_to_restore_conflict.txt
    
    # Ficheiro para o teste de empty individual (ID)
    touch file_to_empty.tmp 

    # Ficheiro grande (assumindo MAX_SIZE_MB=1024 no script principal)
    dd if=/dev/zero of=large_file.bin bs=1M count=15 2>/dev/null
    
    # Ficheiro sem permissão de escrita/leitura (para Edge Case)
    touch no_perm_file.txt
    chmod 444 no_perm_file.txt

    echo -e "${GREEN}Ambiente de teste pronto.${NC}"
}

# Função para buscar o ID de um ficheiro (simplificada)
get_file_id() {
    local filename="$1"
    # Usa grep para encontrar o nome (coluna 2) e cut para extrair o ID (coluna 1)
    grep -i "$filename" "$METADATA_FILE" | tail -n 1 | cut -d',' -f1 | tr -d '[:space:]' | tr -d '\r'
}

# --- Execução dos Testes ---
reset_environment

# === 1. Testes de DELETE (Edge Cases) ===
echo -e "\n${GREEN}=== 1. TESTES DE DELETE (EDGE CASES) ===${NC}"
$RECYCLE_BIN_SCRIPT delete 2>/dev/null # Sem argumentos
$RECYCLE_BIN_SCRIPT delete arquivo_inexistente.txt 2>/dev/null
$RECYCLE_BIN_SCRIPT delete "$RECYCLE_BIN_DIR" 2>/dev/null 
$RECYCLE_BIN_SCRIPT delete no_perm_file.txt 2>/dev/null

# === 2. Testes de DELETE (Sucesso) ===
echo -e "\n${GREEN}=== 2. TESTES DE DELETE (SUCESSO) ===${NC}"
$RECYCLE_BIN_SCRIPT delete fileA.txt
$RECYCLE_BIN_SCRIPT delete dir_to_delete
$RECYCLE_BIN_SCRIPT delete "file with spaces #@.pdf"
$RECYCLE_BIN_SCRIPT delete large_file.bin
$RECYCLE_BIN_SCRIPT delete file_to_empty.tmp
$RECYCLE_BIN_SCRIPT delete FileB.DOC
$RECYCLE_BIN_SCRIPT delete file_to_restore_conflict.txt

# --- Obter IDs para testes futuros ---
ID_FILE_TO_EMPTY=$(get_file_id "file_to_empty.tmp")
ID_CONFLICT=$(get_file_id "file_to_restore_conflict.txt")
ID_A_ORIGINAL=$(get_file_id "fileA.txt")

echo -e "${YELLOW}IDs importantes: ID_FILE_TO_EMPTY=$ID_FILE_TO_EMPTY${NC}"

# === 3. Testes de LIST ===
echo -e "\n${GREEN}=== 3. TESTES DE LIST ===${NC}"
echo "3.1. Listagem normal (Deve ter 7 itens):"
$RECYCLE_BIN_SCRIPT list
echo "3.2. Listagem detalhada (--detailed):"
$RECYCLE_BIN_SCRIPT list --detailed

# === 4. Testes de STATISTICS ===
echo -e "\n${GREEN}=== 4. TESTES DE STATISTICS ===${NC}"
$RECYCLE_BIN_SCRIPT statistics

# === 5. Testes de SEARCH (já verificados) ===
echo -e "\n${GREEN}=== 5. TESTES DE SEARCH (Verificação de ID e Nome) ===${NC}"
echo "5.1. Procura por nome parcial 'fileb':"
$RECYCLE_BIN_SCRIPT search "fileb"
echo "5.2. Procura por ID parcial 'large':"
$RECYCLE_BIN_SCRIPT search "${ID_FILE_TO_EMPTY:0:5}"

# === 6. Testes de RESTORE (Edge Cases) ===
echo -e "\n${GREEN}=== 6. TESTES DE RESTORE (Conflitos e Renomeação) ===${NC}"

echo "6.1. Restaurar item inexistente: Deve falhar."
$RECYCLE_BIN_SCRIPT restore "111_nonexistent"

echo "6.2. Restaurar item para destino ocupado (Overwrite):"
# Simulamos o restore e selecionamos a opção 1 (Overwrite)
echo -e "1\n" | $RECYCLE_BIN_SCRIPT restore "$ID_CONFLICT"

echo "6.3. Restaurar item para destino ocupado (Rename):"
# Deletamos fileA.txt novamente para o teste de restore com renomeação
$RECYCLE_BIN_SCRIPT delete fileA.txt > /dev/null

# Criar um ficheiro com o mesmo nome para o conflito
echo "novo conteudo para conflito" > fileA.txt

# Simulamos restore (fileA.txt) e selecionamos 2 (Rename), digitando 'new_fileA.txt'
echo -e "2\nnew_fileA.txt\n" | $RECYCLE_BIN_SCRIPT restore "fileA.txt"

# === 7. Testes de EMPTY ===
echo -e "\n${GREEN}=== 7. TESTES DE EMPTY ===${NC}"

echo "7.1. Empty por ID: Apaga 'file_to_empty.tmp' (${ID_FILE_TO_EMPTY}):"
$RECYCLE_BIN_SCRIPT empty "$ID_FILE_TO_EMPTY"
echo "7.2. Listar lixeira (Deve ter menos 1 item):"
$RECYCLE_BIN_SCRIPT list

echo "7.3. Empty --force (Esvaziamento Total sem Confirmação):"
$RECYCLE_BIN_SCRIPT empty --force
echo "7.4. Listar lixeira (Deve estar vazia):"
$RECYCLE_BIN_SCRIPT list

echo "7.5. Empty em lixeira vazia: Deve retornar aviso."
$RECYCLE_BIN_SCRIPT empty

# === 8. Verificação Final ===
echo -e "\n${GREEN}=== 8. VERIFICAÇÃO FINAL ===${NC}"
echo "8.1. Verificar se 'file_to_empty.tmp' foi removido da metadata:"
if [ -z "$(get_file_id 'file_to_empty.tmp')" ]; then
    echo -e "${GREEN}Sucesso:${NC} 'file_to_empty.tmp' foi permanentemente apagado da metadata."
else
    echo -e "${RED}Falha:${NC} 'file_to_empty.tmp' ainda está na metadata após o empty (modo ID)."
fi

echo "8.2. Verificar se o ficheiro restaurado (new_fileA.txt) existe no diretório atual:"
if [ -f new_fileA.txt ]; then
    echo -e "${GREEN}Sucesso:${NC} 'new_fileA.txt' foi restaurado com sucesso (após renomeação)."
else
    echo -e "${RED}Falha:${NC} 'new_fileA.txt' não foi restaurado."
fi

rm -f fileA.txt new_fileA.txt large_file.bin file_to_restore_conflict.txt no_perm_file.txt large_file.bin file_to_empty.tmp 2>/dev/null
#rm -rf dir_to_delete "$RECYCLE_BIN_DIR" 2>/dev/null

echo -e "\n${YELLOW}=====================================================${NC}"
echo -e "${YELLOW}               TESTES CONCLUÍDOS                    ${NC}"
echo -e "${YELLOW}=====================================================${NC}"