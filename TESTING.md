# TESTING.md: Recycle Bin Test Documentation

## Overview
This document details the test cases executed by the `test_suite.sh` script to validate the core functionality of the Linux Recycle Bin system. The tests are designed to cover success paths, edge cases, and error handling for all major commands.

---

## Setup & Helper Information

| Component | Status | Note |
| :--- | :--- | :--- |
| **Test Script** | `test_suite.sh` | Automatically reports PASS/FAIL using `assert_success` and `assert_fail` functions. |
| **Max Quota** | `MAX_SIZE_MB` | Has the value of 1024 MB. Used for size limit validation tests. |

---

## Test Cases

### 1. Delete Command (`delete`)

#### Test Case 1.1: Delete Success (Single File)
**Objective:** Verify that a standard file is successfully moved to the recycle bin and logged.

**Steps:**
1. Create file: `echo "test" > temp_file.txt`
2. Run: `$SCRIPT delete temp_file.txt`
3. Verify `temp_file.txt` is missing from the current directory.
4. Verify entry in `metadata.db`.

**Expected Result:** Success message displayed; File is moved; `exit_status = 0`.

**Status:** ☐ Pass ☐ Fail

#### Test Case 1.2: Delete Success (Directory)
**Objective:** Verify that a directory (with contents) is recursively moved.

**Steps:**
1. Create directory: `mkdir -p test_dir/sub`
2. Run: `$SCRIPT delete test_dir`
3. Verify `test_dir` is missing.

**Expected Result:** Success message displayed; Directory is moved; `exit_status = 0`.

**Status:** ☐ Pass ☐ Fail

#### Test Case 1.3: Delete Success (Multiple Items & Complex Name)
**Objective:** Verify deletion handles multiple arguments and files with special characters/spaces.

**Steps:**
1. Run: `$SCRIPT delete fileA.txt dir_to_delete "file with spaces #@.pdf"`
2. Verify all files are deleted from the working directory.

**Expected Result:** Success message for each item; `exit_status = 0`.

**Status:** ☐ Pass ☐ Fail

#### Test Case 1.4: Error Handling (No Arguments)
**Objective:** Verify the script handles zero arguments correctly.

**Steps:**
1. Run: `$SCRIPT delete`

**Expected Result:** Error message: "No file specified"; `exit_status = 1`.

**Status:** ☐ Pass ☐ Fail

#### Test Case 1.5: Error Handling (Security Check)
**Objective:** Prevent the user from deleting the recycle bin directory itself.

**Steps:**
1. Run: `$SCRIPT delete $HOME/.recycle_bin`

**Expected Result:** Error message: "Cannot delete the recycle bin..."; `exit_status = 1`.

**Status:** ☐ Pass ☐ Fail

#### Test Case 1.6: Error Handling (Permissions)
**Objective:** Verify deletion fails if the file lacks read/write permissions for the current user.

**Steps:**
1. Create file with read-only permissions: `chmod 444 no_perm_file.txt`
2. Run: `$SCRIPT delete no_perm_file.txt`

**Expected Result:** Error message: "No read/write permission..."; `exit_status = 1`.

**Status:** ☐ Pass ☐ Fail

---

### 2. List & Statistics Commands (`list`, `statistics`)

#### Test Case 2.1: List Non-Empty Bin
**Objective:** Verify the list command displays content when the bin is populated.

**Steps:**
1. Run: `$SCRIPT delete ...` (pre-requesite)
2. Run: `$SCRIPT list`
3. Check for presence of an item (e.g., `fileA.txt`).

**Expected Result:** List output contains expected filenames.

**Status:** ☐ Pass ☐ Fail

#### Test Case 2.2: List Detailed Output
**Objective:** Verify the `--detailed` flag works and includes specific metadata (e.g., 'Proprietário').

**Steps:**
1. Run: `$SCRIPT list --detailed`
2. Check output for metadata headers.

**Expected Result:** Output contains "Proprietário" (Owner) and detailed item blocks.

**Status:** ☐ Pass ☐ Fail

#### Test Case 2.3: Statistics Correct Count
**Objective:** Verify the `statistics` function accurately counts total items (7 in the setup).

**Steps:**
1. Run: `$SCRIPT statistics`
2. Check output for "Total Items".

**Expected Result:** Output shows the total item count correctly; `exit_status = 0`.

**Status:** ☐ Pass ☐ Fail

---

### 3. Search Command (`search`)

#### Test Case 3.1: Search by Partial Name (Case-Insensitive)
**Objective:** Verify search finds items using partial names, regardless of case.

**Steps:**
1. Run: `$SCRIPT search "fileb"`
2. Check output for "FileB.DOC".

**Expected Result:** `FileB.DOC` is listed.

**Status:** ☐ Pass ☐ Fail

#### Test Case 3.2: Search by Partial ID
**Objective:** Verify search works using the unique ID.

**Steps:**
1. Get ID of an item (`ID_A`).
2. Run: `$SCRIPT search $ID_A_PARTIAL`
3. Check output for the filename.

**Expected Result:** Filename corresponding to the ID is listed.

**Status:** ☐ Pass ☐ Fail

#### Test Case 3.3: Search Non-Existent Item
**Objective:** Verify an appropriate message is shown when no match is found.

**Steps:**
1. Run: `$SCRIPT search "nonexistent123"`

**Expected Result:** Output contains "No items found matching the pattern..."; `exit_status = 0`.

**Status:** ☐ Pass ☐ Fail

---

### 4. Restore Command (`restore`)

#### Test Case 4.1: Restore Error (Non-Existent ID)
**Objective:** Verify restoration fails gracefully if the provided ID is invalid or not in metadata.

**Steps:**
1. Run: `$SCRIPT restore "111_nonexistent"`

**Expected Result:** Error message: "No file found with ID or name..."; `exit_status = 1`.

**Status:** ☐ Pass ☐ Fail

#### Test Case 4.2: Restore Success (Overwrite Conflict)
**Objective:** Verify the restoration succeeds when the user chooses to overwrite an existing destination file.

**Steps:**
1. Delete `file_to_restore_conflict.txt`.
2. Create a conflicting file at the destination path.
3. Run: `echo -e "1\n" | $SCRIPT restore $ID_CONFLICT` (Simulate choosing Option 1: Overwrite).
4. Check if the file now exists in the working directory.

**Expected Result:** File is restored and metadata entry is removed.

**Status:** ☐ Pass ☐ Fail

#### Test Case 4.3: Restore Success (Rename Conflict)
**Objective:** Verify the restoration succeeds when the user chooses to rename the file at the destination.

**Steps:**
1. Delete `fileA.txt`.
2. Create a conflicting file at the destination path.
3. Run: `echo -e "2\nnew_fileA.txt\n" | $SCRIPT restore $ID_A_RENAME` (Simulate choosing Option 2: Rename, using `new_fileA.txt`).
4. Check if the original conflicting file (`fileA.txt`) remains and the new file (`new_fileA.txt`) exists.

**Expected Result:** `new_fileA.txt` exists; `fileA.txt` content is unchanged; metadata entry for ID is removed.

**Status:** ☐ Pass ☐ Fail

---

### 5. Empty Command (`empty`)

#### Test Case 5.1: Empty Success (By ID)
**Objective:** Verify a single item can be permanently deleted and removed from metadata.

**Steps:**
1. Get ID of an item (`ID_FILE_TO_EMPTY`).
2. Run: `$SCRIPT empty $ID_FILE_TO_EMPTY`
3. Verify the item is removed from `metadata.db`.

**Expected Result:** Success message; Item is no longer in metadata; `exit_status = 0`.

**Status:** ☐ Pass ☐ Fail

#### Test Case 5.2: Empty Success (Total Empty with --force)
**Objective:** Verify all contents are deleted without confirmation when using `--force`.

**Steps:**
1. Run: `$SCRIPT empty --force`
2. Check the metadata file line count.

**Expected Result:** Metadata file contains only 2 lines (headers); `exit_status = 0`.

**Status:** ☐ Pass ☐ Fail

#### Test Case 5.3: Empty Error (Already Empty)
**Objective:** Verify the script handles the case where the bin is already empty.

**Steps:**
1. (Bin is empty from 5.2).
2. Run: `$SCRIPT empty`

**Expected Result:** Warning message: "The recycle bin is already empty"; `exit_status = 0`.

**Status:** ☐ Pass ☐ Fail