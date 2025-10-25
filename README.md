# Linux Recycle Bin System

## Authors
Rodrigo Simões - 125514
Simão Pinto - 126099

## Description
This project is a Recycle Bin simulator for Linux-based systems, implemented entirely in **Shell Script (Bash)**. Developed as part of the **"Sistemas Operativos"** university course, the goal is to provide a safe alternative to the dangerous `rm` command, allowing users to move files and directories to a quarantine area where they can be inspected, restored to their original location, or permanently deleted.

The system maintains detailed metadata (original name, source path, deletion date, permissions, and owner) to ensure accurate and complete restoration.

## Installation
No complex installation is required, as the system is a *standalone* Bash script.

1.  **Create the file:** Save the main code (including the `delete_file`, `restore_file`, etc. functions) into a file named `lixeira.sh` (or `recycle_bin.sh`).
2.  **Grant execute permission:**
    ```bash
    chmod +x lixeira.sh
    ```
3.  **Initialization:** The script automatically initializes the directory structure (`$HOME/.recycle_bin`) upon the first execution of any command.

## Usage
All commands are executed through the main script file.

| Action | Syntax |
| **Delete** | `$0 delete <file(s)>` |
| **List** | `$0 list [--detailed]` |
| **Restore** | `$0 restore <ID | Name>` |
| **Search** | `$0 search <pattern>` |
| **Statistics**| `$0 statistics` |
| **Empty All** | `$0 empty` |
| **Delete Item** | `$0 empty <ID>` |
| **Force Empty** | `$0 empty --force` |
| **Help** | `$0 <help | --help | -h>` |

## Features
### Core Functionality
- **Delete (`delete`):** Moves files and directories to quarantine.
- **Metadata Management:** Stores the original path, date, permissions, and file owner.
- **Restore (`restore`):** Restores files to the original path, recovering permissions and owner (subject to execution permissions).
- **Conflict Resolution:** During restoration, detects name conflicts and allows overwriting or renaming.
- **Search (`search`):** Allows searching for items by ID, name, or original path.
- **Storage Limits:** Checks file size and available space before deletion/moving.
- **Log Management:** Logs all deletion and emptying operations.

### Advanced Features
- **Statistics (`statistics`):** Displays detailed metrics:
    - Total item count.
    - Total space used and quota percentage (`MAX_SIZE_MB=1024`).
    - Breakdown by type (files vs. directories).
    - Age analysis (oldest and newest item).
- **Permanent Delete (`empty`):**
    - Selective deletion by ID (`$0 empty <ID>`).
    - Total emptying (`$0 empty`).
    - Supports the `--force` flag for complete emptying without confirmation.

## Configuration
The main configurations are defined in the header of the script.

| Variable | Default Value | Description |
| `RECYCLE_BIN_DIR` | `$HOME/.recycle_bin` | Directory where the recycle bin is created. |
| `MAX_SIZE_MB` | `1024` | Maximum size limit (in MB) a single file/directory can have to be moved to the recycle bin. |
| `RETENTION_DAYS` | `30` | Days of file retention before automatic cleanup (currently a **TODO** function). |

## Examples
[Detailed usage examples with screenshots]

## Known Issues
- TODO: **Automatic Cleanup:** Implement automatic cleanup of files based on age (`RETENTION_DAYS=30`).
- Large Files: Files larger than MAX_SIZE_MB (default 1024MB) are rejected upon deletion.

## References
- Bash Shell Programming Documentation (Gnu/Linux)
- `stat`, `grep`, `sed`, `awk`, `bc` utility documentation.
- **AI Assistance:** Architectural design review and debugging assistance provided by **Gemini** (a large language model trained by Google).