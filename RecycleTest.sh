#!/bin/bash

# Configuração (ajusta o caminho se necessário)
RECYCLE_BIN_SCRIPT="./recycle_bin.sh"

# Preparação do ambiente de testes
mkdir -p "$HOME/.recycle_bin/files"
touch "$HOME/.recycle_bin/metadata.db"
touch "$HOME/.recycle_bin/recyclebin.log"

MAX_SIZE_MB=10  # Define limite baixo para testes no teu script

# Cria ficheiros e diretórios para teste
echo "conteúdo pequeno" > test_file.txt
dd if=/dev/zero of=large_file.bin bs=1M count=15 2>/dev/null  # arquivo 15MB
mkdir -p test_dir/subdir
echo "conteudo em pasta" > test_dir/subdir/file.txt
touch "ficheiro com espaços e #$@!.txt"

echo "=== Teste 1: Sem argumentos (deve dar erro) ==="
$RECYCLE_BIN_SCRIPT delete

echo "=== Teste 2: Ficheiro inexistente (deve dar erro) ==="
$RECYCLE_BIN_SCRIPT delete arquivo_inexistente.txt

echo "=== Teste 3: Ficheiro pequeno (deve mover) ==="
$RECYCLE_BIN_SCRIPT delete test_file.txt

echo "=== Teste 4: Ficheiro grande (deve rejeitar) (mas da porque so tem 15MB) ==="
$RECYCLE_BIN_SCRIPT delete large_file.bin

echo "=== Teste 5: Diretório (deve mover) ==="
$RECYCLE_BIN_SCRIPT delete test_dir

echo "=== Teste 6: Múltiplos ficheiros e diretórios ==="
$RECYCLE_BIN_SCRIPT delete test_file.txt large_file.bin test_dir arquivo_inexistente.txt

echo "=== Teste 7: Ficheiro com nome complexo ==="
$RECYCLE_BIN_SCRIPT delete "ficheiro com espaços e #$@!.txt"

echo "=== Conteúdo de metadata.db ==="
cat "$HOME/.recycle_bin/metadata.db"

echo "=== Conteúdo do recyclebin.log ==="
cat "$HOME/.recycle_bin/recyclebin.log"
