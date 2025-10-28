## System architecture diagram

```text
      [ User (via CLI Terminal) ]
                   |
                   v
    +----------------------------------+
    |        recycle_bin.sh            |
    |       (Main Script Logic)        |
    |----------------------------------|
    |  main() [Command Router]         |
    |   |                              |
    |   +-> delete_file()              |
    |   +-> restore_file()             |
    |   +-> list_recycled()            |
    |   +-> search_recycled()          |
    |   +-> show_statistics()          |
    |   +-> preview_file()             |
    |   +-> check_quota()              |
    |   +-> empty_recyclebin()         |
    |   +-> auto_cleanup()             |
    +----------------------------------+
       |          |            |
(Reads/Writes)    |      (Reads/Writes)
       |          |            |
       v          v            v
 [ External Filesystem ] <-----> [ $HOME/.recycle_bin (Data Store) ]
 (e.g., /home/user/docs)       |-----------------------------------|
                               | [ files/ ]      (File Storage)    |
                               |   - 123_abc     (Actual data)     |
                               |   - 456_def                       |
                               |                                   |
                               | [ metadata.db ] (CSV "Database")  |
                               | (Stores paths, perms, dates)      |
                               |                                   |
                               | [ recyclebin.log ] (Audit Log)    |
                               | (Tracks delete/empty actions)     |
                               +-----------------------------------+
```

## Metadata schema explanation

The metadata for each recycled file is stored in a CSV file named `metadata.db` located within the recycle bin directory (`$HOME/.recycle_bin/`). Each entry in this database corresponds to a single recycled file and contains the following fields:

- `id`: A unique identifier for the recycled file (e.g., `11761675601_1x6169`).
- `original_name`: The original name of the file before deletion (e.g., `file.txt`).
- `original_path`: The original file path before deletion (e.g., `/home/user/docs/file.txt`).
- `deletion_date`: The timestamp when the file was deleted (e.g., `2006-10-22 13:03:56`).
- `size`: The size of the file in bytes (e.g., `1024`).
- `type`: The type of the file (file/directory).
- `permissions`: The file permissions at the time of deletion (e.g., `rw-r--r--`).
- `owner`: The username of the file owner (e.g., `user`).

Each line in `metadata.db` follows this format:

```
ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER
```
**Example entry:**
```
11761675601_1x6169,file.txt,/home/user/docs/file.txt,2023-03-15 12:34:56,1024,file,664,rw-r--r--,user