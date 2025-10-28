## System architecture diagram

```text
    +----------------------------------+
    |        recycle_bin.sh            |
    |       (Main Script Logic)        |
    |----------------------------------|
    |  main()         |
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
                               |-----------------------------------|
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
```

## Functions descriptions 

- `delete_file()`: Safely moves specified files or directories into the trash folder, after performing checks on permissions, disk space, maximum size limits, and preventing the deletion of the bin itself.
- `restore_file()`: Retrieves a file from the trash and moves it back to its original location, handling potential naming conflicts by prompting the user for an action (overwrite or rename).
- `list_recycled()` : Displays all items currently stored in the recycle bin, offering a detailed view option (--detailed) to show all stored metadata.
- `search_recycled()` : Allows the user to find deleted items in the metadata by matching a given pattern against the file names and other attributes.
- `show_statistics()` : Calculates and presents an overview of the recycle bin's state, including total usage, item counts, size distribution, and the age of the oldest and newest items.
- `preview_file()` : Provides a quick look at the contents of a deleted item by printing the first few lines, primarily for text-based files.
- `check_quota()` : Monitors the total storage consumption against the configured maximum size and triggers the automatic cleanup routine if the limit is exceeded.
- `empty_recyclebin()` : Performs permanent deletion of items, either removing a single item by its ID or clearing the entire contents of the recycle bin.
- `auto_cleanup()` : Executes the scheduled maintenance by permanently deleting any files that have exceeded the defined retention period in days.

## Algorithm Explanations

### A. Deletion Algorithm (`delete_file`)

1.  **Input Validation:** Verify item existence, Read/Write permissions, and that the item is not the recycle bin itself.
2.  **Size & Space Validation:** Calculate size, compare against **`$MAX_SIZE_MB`**, and check **available disk space**. Fail if any constraint is violated.
3.  **Metadata and Movement:** **Generate a Unique ID**. **Record Metadata** (path, permissions, owner). Execute **`mv`** to move the file to `$FILES_DIR`, renaming it to the Unique ID.
4.  **Logging:** Append the new metadata record to the **`$METADATA_FILE`** and log the event to **`$LOG_FILE`**.

### B. Restoration Algorithm (`restore_file`)

1.  **Lookup:** Search the **`$METADATA_FILE`** for the record corresponding to the input ID/Name.
2.  **Conflict Resolution:** Check if the file exists at the **`ORIGINAL_PATH`**. If yes, prompt user for Overwrite, Rename, or Cancel.
3.  **Physical Restoration:** Execute the **`mv`** command from `$FILES_DIR/$ID` to the resolved destination path.
4.  **Attribute Restoration:** Execute **`chmod`** and **`chown`** using the stored metadata values.
5.  **Cleanup:** Remove the corresponding **Metadata Record** from the **`$METADATA_FILE`**.

### C. Automatic Cleanup Algorithm (`auto_cleanup`)

1.  **Identification:** Use **`find`** to locate physical files in **`$FILES_DIR`** older than **`+$RETENTION_DAYS`**.
2.  **Metadata Synchronization:** For each expired file, locate and remove its **Metadata Record** from the **`$METADATA_FILE`**.
3.  **Physical Deletion:** Execute **`rm -rf`** on the expired physical file.
4.  **Reporting:** Log the event and report the count of removed items.

## Design Decisions and Rationale

| Design Decision | Rationale |
| :--- | :--- |
| **1. Separation of Concerns (Files vs. Metadata)** | Ensures that listing and management operations are fast (only reading the small `$METADATA_FILE`) and robust against file storage corruption. |
| **2. Timestamp-based Unique IDs** | Guarantees uniqueness across simultaneous deletions, preventing name collisions when renaming files in the flat `$FILES_DIR` structure. |
| **3. Pre-Deletion Constraint Checks** | Ensures system stability by checking file **permissions**, **size limits**, and **disk space** before executing the irreversible `mv` operation. |
| **4. Restoration Conflict Resolution** | Enhances user experience and prevents data loss by giving the user explicit control (Overwrite/Rename/Cancel) when the target file path already exists. |
| **5. Attribute Preservation** | Recording `PERMISSIONS` and `OWNER` guarantees that the restored file is functionally identical to the original, critical for multi-user Linux environments. |



