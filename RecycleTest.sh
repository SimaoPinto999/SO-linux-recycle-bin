#!/bin/bash
#################################################
# Linux Recycle Bin Simulation - Test Script
#################################################

# Configuração
RECYCLE_BIN_SCRIPT="./recycle_bin.sh"
# Assumimos que o script principal está no mesmo diretório
if [ ! -f "$RECYCLE_BIN_SCRIPT" ]; then
    echo "Erro: Ficheiro do script principal ($RECYCLE_BIN_SCRIPT) não encontrado."
    exit 1
fi

# Variáveis globais de configuração do script principal
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"

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
    touch "file_to_restore_conflict.txt"
    echo "original content" > file_to_restore_conflict.txt
    
    # Cria ficheiro de 15MB. Assume-se que o MAX_SIZE_MB está em 1024 no script
    dd if=/dev/zero of=large_file.bin bs=1M count=15 2>/dev/null
    
    # Cria um ficheiro que o utilizador não tem permissão para escrever (se não for root)
    touch no_perm_file.txt
    chmod 444 no_perm_file.txt

    echo -e "${GREEN}Ambiente de teste pronto.${NC}"
}

# Função para buscar o ID de um ficheiro
get_file_id() {
    local filename="$1"
    # Busca o ID na metadata usando o nome do ficheiro, ignora os cabeçalhos
    grep "$filename" "$METADATA_FILE" | tail -n 1 | cut -d',' -f1
}

# --- Execução dos Testes ---
reset_environment

# === 1. Testes de DELETE (Edge Cases) ===
echo -e "\n${GREEN}=== 1. TESTES DE DELETE ===${NC}"
echo "1.1. Sem argumentos: Deve falhar."
$RECYCLE_BIN_SCRIPT delete
echo "1.2. Ficheiro inexistente: Deve falhar."
$RECYCLE_BIN_SCRIPT delete arquivo_inexistente.txt
echo "1.3. Eliminar o próprio recycle bin: Deve falhar (segurança)."
$RECYCLE_BIN_SCRIPT delete "$RECYCLE_BIN_DIR"
echo "1.4. Ficheiro sem permissão de escrita/leitura (se não for root): Deve falhar."
$RECYCLE_BIN_SCRIPT delete no_perm_file.txt 2>/dev/null

# === 2. Testes de DELETE (Sucesso) ===
echo -e "\n${GREEN}=== 2. TESTES DE DELETE (SUCESSO) ===${NC}"
echo "2.1. Ficheiro pequeno (fileA.txt): Deve mover."
$RECYCLE_BIN_SCRIPT delete fileA.txt
echo "2.2. Diretório (dir_to_delete): Deve mover."
$RECYCLE_BIN_SCRIPT delete dir_to_delete
echo "2.3. Ficheiro com nome complexo (spaces #@): Deve mover."
$RECYCLE_BIN_SCRIPT delete "file with spaces #@.pdf"
echo "2.4. Ficheiro grande (large_file.bin): Deve mover (se <= MAX_SIZE_MB, que é 1024)."
$RECYCLE_BIN_SCRIPT delete large_file.bin
echo "2.5. Outro ficheiro pequeno (FileB.DOC): Deve mover."
$RECYCLE_BIN_SCRIPT delete FileB.DOC

# === 3. Testes de LIST ===
echo -e "\n${GREEN}=== 3. TESTES DE LIST ===${NC}"
echo "3.1. Listagem normal (5 itens):"
$RECYCLE_BIN_SCRIPT list
echo "3.2. Listagem detalhada:"
$RECYCLE_BIN_SCRIPT list --detailed

# === 4. Testes de SEARCH ===
echo -e "\n${GREEN}=== 4. TESTES DE SEARCH ===${NC}"
ID_A=$(get_file_id "fileA.txt")

echo "4.1. Procura por nome parcial (case-insensitive): 'fileb'. Deve encontrar FileB.DOC."
$RECYCLE_BIN_SCRIPT search "fileb"
echo "4.2. Procura por extensão (wildcard implícito): 'DOC'. Deve encontrar FileB.DOC."
$RECYCLE_BIN_SCRIPT search "DOC"
echo "4.3. Procura por ID parcial: Os 5 primeiros dígitos do ID '$ID_A'."
$RECYCLE_BIN_SCRIPT search "${ID_A:0:5}"
echo "4.4. Procura por nome complexo parcial: 'with spaces'. Deve encontrar o ficheiro com espaços."
$RECYCLE_BIN_SCRIPT search "with spaces"
echo "4.5. Procura por termo inexistente: Deve falhar (0 resultados)."
$RECYCLE_BIN_SCRIPT search "inexistente123"

# === 5. Testes de RESTORE (Edge Cases) ===
echo -e "\n${GREEN}=== 5. TESTES DE RESTORE (EDGE CASES) ===${NC}"

ID_B=$(get_file_id "FileB.DOC")
ID_CONFLICT=$(get_file_id "file_to_restore_conflict.txt")

echo "5.1. Restaurar ficheiro inexistente: Deve falhar."
$RECYCLE_BIN_SCRIPT restore "111_nonexistent"

echo "5.2. Restaurar ficheiro para destino ocupado (Conflict):"
# Simulamos o restore e selecionamos a opção 1 (Overwrite)
echo -e "1\n" | $RECYCLE_BIN_SCRIPT restore "$ID_CONFLICT"

echo "5.3. Restaurar ficheiro para destino ocupado (Rename):"
# Deletar o ficheiro pequeno novamente
$RECYCLE_BIN_SCRIPT delete fileA.txt > /dev/null

# Criar um ficheiro com o mesmo nome para o conflito
echo "novo conteudo" > fileA.txt

# Simulamos o restore e selecionamos a opção 2 (Rename), digitando 'new_fileA.txt'
echo -e "2\nnew_fileA.txt\n" | $RECYCLE_BIN_SCRIPT restore "fileA.txt"

# === 7. Verificação Final ===
echo -e "\n${GREEN}=== 7. VERIFICAÇÃO FINAL ===${NC}"
echo "7.1. Verificar se o ficheiro FileB.DOC foi removido da metadata:"
if [ -z "$(get_file_id 'FileB.DOC')" ]; then
    echo -e "${GREEN}Sucesso:${NC} FileB.DOC foi apagado da metadata."
else
    echo -e "${RED}Falha:${NC} FileB.DOC ainda está na metadata após o empty."
fi
echo "7.2. Listar lixeira vazia:"
$RECYCLE_BIN_SCRIPT list
echo "7.3. Verificar se o novo ficheiro restaurado (new_fileA.txt) existe no diretório atual:"
if [ -f new_fileA.txt ]; then
    echo -e "${GREEN}Sucesso:${NC} new_fileA.txt foi restaurado com sucesso (após renomeação)."
else
    echo -e "${RED}Falha:${NC} new_fileA.txt não foi restaurado."
fi

echo -e "\n${YELLOW}=====================================================${NC}"
echo -e "${YELLOW}               TESTES CONCLUÍDOS                    ${NC}"
echo -e "${YELLOW}=====================================================${NC}"