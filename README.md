# Linux Recycle Bin Simulation

Um sistema de reciclagem para Linux implementado em Shell Script que simula o comportamento de uma "Lixeira" similar ao Windows/macOS.

## 📋 Funcionalidades

- ✅ **Delete**: Move ficheiros/diretórios para a reciclagem
- 🚧 **List**: Lista todos os items na reciclagem (TODO)
- 🚧 **Restore**: Restaura ficheiros pelo ID único (TODO)
- 🚧 **Search**: Procura ficheiros por padrão (TODO)
- 🚧 **Empty**: Esvazia permanentemente a reciclagem (TODO)

## 🚀 Instalação

1. Clona o repositório:
```bash
git clone https://github.com/teu-usuario/linux-recycle-bin.git
cd linux-recycle-bin
```

2. Dá permissões de execução:
```bash
chmod +x recycle_bin.sh
```

3. (Opcional) Move para uma pasta no PATH:
```bash
sudo cp recycle_bin.sh /usr/local/bin/recycle_bin
```

## 💻 Uso

### Comandos Disponíveis

```bash
# Eliminar ficheiro/diretório
./recycle_bin.sh delete arquivo.txt
./recycle_bin.sh delete pasta/

# Listar items na reciclagem
./recycle_bin.sh list

# Restaurar ficheiro pelo ID
./recycle_bin.sh restore 1696234567_abc123

# Procurar ficheiros
./recycle_bin.sh search "*.pdf"

# Esvaziar reciclagem
./recycle_bin.sh empty

# Ajuda
./recycle_bin.sh help
```

### Exemplos Práticos

```bash
# Eliminar múltiplos ficheiros
./recycle_bin.sh delete file1.txt file2.txt pasta/

# Ver conteúdo da reciclagem
./recycle_bin.sh list
```

## 📁 Estrutura do Sistema

O script cria a seguinte estrutura em `~/.recycle_bin/`:

```
~/.recycle_bin/
├── files/           # Ficheiros eliminados (com IDs únicos)
├── metadata.db      # Base de dados com metadados
├── recyclebin.log   # Logs das operações
└── config           # Ficheiro de configuração
```

## ⚙️ Configuração

- **Tamanho máximo**: 1024MB por ficheiro/diretório
- **Retenção**: 30 dias (funcionalidade futura)
- **Localização**: `~/.recycle_bin/`

## 🔧 Funcionalidades de Segurança

- ✅ Verificação de permissões
- ✅ Proteção contra eliminação da própria reciclagem
- ✅ Verificação de espaço em disco
- ✅ Limite de tamanho de ficheiros
- ✅ Logging detalhado de operações

## 📊 Metadados Guardados

Para cada ficheiro eliminado, o sistema guarda:
- ID único
- Nome original
- Caminho original
- Data/hora de eliminação
- Tamanho
- Tipo (ficheiro/diretório)
- Permissões
- Proprietário

## 🐛 Status de Desenvolvimento

| Funcionalidade | Status | Descrição |
|----------------|--------|-----------|
| Delete | ✅ Completa | Eliminação com validações |
| List | 🚧 TODO | Listar items na reciclagem |
| Restore | 🚧 TODO | Restaurar por ID |
| Search | 🚧 TODO | Pesquisa por padrão |
| Empty | 🚧 TODO | Esvaziar reciclagem |
| Auto-cleanup | 🚧 TODO | Limpeza automática (30 dias) |

## 👨‍💻 Autores

**Rodrigo Simões**
**Simão Pinto**
📅 13/10/2025

---

💡 **Nota**: Este é um projeto educacional para demonstrar conceitos de shell scripting e gestão de ficheiros em Linux.
