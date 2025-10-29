# TESTING.md: Recycle Bin Test Documentation (Final Version)

## Overview
This document details the complete set of automated test cases executed by the `run_tests.sh` script, providing a detailed sequential numbering for every setup step, execution command, and verification logic.

---

## Setup & Helper Information

| Component | Status | Note |
| :--- | :--- | :--- |
| **Test Script** | `run_tests.sh` | Automatically reports PASS/FAIL using `assert_success` and `assert_fail` functions. |
| **Initial Items** | **12 items** | The setup phase creates and deletes 12 unique files/directories for statistics and integrity tests. |
| **Max Quota** | `MAX_SIZE_MB = 1024` | Used for size limit validation tests. |

---

## Test Cases

### 1. Delete Command (`delete`)

#### Test Case 1.1: Delete Success (Standard File & Directory)
**Objective:** Verify basic deletion works for standard files and directories.

**Steps:**
1.1. (Setup) Create `fileA.txt` and `dir_to_delete`.

1.2. (Execution) Run `$SCRIPT delete fileA.txt dir_to_delete`.

1.3. **(Verification 1)** Confirm `fileA.txt` does not exist in the working directory.

1.4. **(Verification 2)** Confirm `dir_to_delete` does not exist in the working directory.

**Expected Result:** Deletion success; `exit_status = 0`.
**Status:** ☐ Pass ☐ Fail


#### Test Case 1.2: Delete Success (Multi-Path, Complex Names & Hidden)
**Objective:** Verify deletion of multiple paths, complex names, and hidden files.

**Steps:**
1.5. (Execution) Run `$SCRIPT delete "file with spaces #@.pdf" umdiretorio/doc_dir1.txt outrodiretorio/relatorio_dir2.pdf .hidden_test_file.dat`.

1.6. **(Verification 1)** "file with spaces #@.pdf" moved.

1.7. **(Verification 2)** `umdiretorio/doc_dir1.txt` moved.

1.8. **(Verification 3)** `outrodiretorio/relatorio_dir2.pdf` moved.

1.9. **(Verification 4)** `.hidden_test_file.dat` moved.

**Expected Result:** Success for all deletions; `exit_status = 0`.
**Status:** ☐ Pass ☐ Fail


#### Test Case 1.3: Delete Success (Symbolic Link Integrity)
**Objective:** Ensure deleting a **link** does not delete the **original target** file.

**Steps:**
1.10. (Execution) Run `$SCRIPT delete link_to_target.lnk`.

1.11. **(Verification 1)** Confirm successful deletion message for the link.

1.12. **(Verification 2)** The target file `original_target.txt` **still exists** in the active file system.

1.13. **(Verification 3)** Metadata entry for `link_to_target.lnk` created.

1.14. (Cleanup) Remove the link record and the original target file.

**Expected Result:** Link moved to bin, target remains intact; `exit_status = 0`.
**Status:** ☐ Pass ☐ Fail


#### Test Case 1.4: Error Handling (Security & Non-Existent)
**Objective:** Verify all security and validation errors (No Args, Non-Existent, Permission, Self-Delete).

**Steps:**
1.15. (Error) Run `$SCRIPT delete` (No arguments).

1.16. (Error) Run `$SCRIPT delete non_existent_file.txt`.

1.17. (Error) Run `$SCRIPT delete no_perm_file.txt` (File lacks write permission).

1.18. (Error) Run `$SCRIPT delete $HOME/.recycle_bin` (Attempt to delete the bin itself).

**Expected Result:** All calls fail with the correct error message; `exit_status = 1`.
**Status:** ☐ Pass ☐ Fail


#### Test Case 1.5: Error Handling (Exceeds Size Limit)
**Objective:** Verify rejection of files larger than `MAX_SIZE_MB`.

**Steps:**
1.19. (Setup) Create `huge_file.bin` (1050MB).

1.20. (Error) Run `$SCRIPT delete huge_file.bin`.

1.21. (Cleanup) Remove `huge_file.bin`.

**Expected Result:** Deletion fails with size limit error message; `exit_status = 1`.
**Status:** ☐ Pass ☐ Fail

---

### 2. Information and Audit Commands

#### Test Case 2.1: List & Statistics (General Information)
**Objective:** Validate listing and statistics display correctness.

**Steps:**
2.1. (Execution) Run `$SCRIPT list`.

2.2. **(Verification 1)** `list` command returns content (bin is not empty).

2.3. (Execution) Run `$SCRIPT list --detailed`.

2.4. **(Verification 2)** The detailed list shows the "Proprietary" column.

2.5. (Execution) Run `$SCRIPT statistics`.

2.6. **(Verification 3)** `statistics` returns the correct item count of 12.

**Expected Result:** All information commands execute successfully; `exit_status = 0`.
**Status:** ☐ Pass ☐ Fail


#### Test Case 2.2: Search Command
**Objective:** Verify search functionality by partial name and ID.

**Steps:**
2.7. (Execution) Run `$SCRIPT search "fileb"`.

2.8. **(Verification 1)** Partial/case-insensitive search successfully finds `FileB.DOC`.

2.9. (Execution) Run `$SCRIPT search $ID_A_PARTIAL`.

2.10. **(Verification 2)** Search by partial ID finds `fileA.txt`.

2.11. (Execution) Run `$SCRIPT search "nonexistent123"`.

2.12. **(Verification 3)** Search for non-existent term returns "No items found" warning.

**Expected Result:** All search scenarios are handled correctly; `exit_status = 0`.
**Status:** ☐ Pass ☐ Fail


#### Test Case 2.3: Preview and Quota
**Objective:** Verify content preview for text files and the system quota status.

**Steps:**
2.13. (Execution) Run `$SCRIPT preview $ID_PREVIEW_TEST_TXT`.

2.14. **(Verification 1)** Preview displays the expected text content ("This is line 1").

2.15. (Execution) Run `$SCRIPT quota`.

2.16. **(Verification 2)** Quota is checked and reports "Quota Check OK".

**Expected Result:** Preview and Quota checks pass; `exit_status = 0`.
**Status:** ☐ Pass ☐ Fail

---

### 3. Restore and Empty Commands

#### Test Case 3.1: Restore Success (Overwrite Conflict & Rename Conflict)
**Objective:** Validate conflict resolution options during restoration.

**Steps:**
3.1. (Execution) Run `$SCRIPT restore $ID_CONFLICT` (Simulate Option 1: Overwrite).

3.2. **(Verification 1)** File is restored via overwrite.

3.3. (Execution) Run `$SCRIPT restore $ID_A_RENAME` (Simulate Option 2: Rename, inputting `new_fileA.txt`).

3.4. **(Verification 2)** The renamed file (`new_fileA.txt`) exists.

3.5. **(Verification 3)** The original conflicting file (`fileA.txt`) content remained unchanged.

**Expected Result:** Both conflict resolution methods function; `exit_status = 0`.
**Status:** ☐ Pass ☐ Fail


#### Test Case 3.2: Restore Error (Destination Read-Only)
**Objective:** Ensure `restore` fails and item is not removed from metadata if the target directory lacks write permission.

**Steps:**
3.6. (Setup) Change parent directory permissions to 555 (Read-Only).

3.7. (Error) Run `$SCRIPT restore $ID_BLOCKED`.

3.8. **(Verification 1)** Restore fails due to permission error.

3.9. **(Verification 2)** The item remains in `metadata.db`.

3.10. (Cleanup) Remove Read-Only directory lock.

**Expected Result:** Restore fails, item is retained in bin; `exit_status = 1`.
**Status:** ☐ Pass ☐ Fail


#### Test Case 3.3: Empty Success (By ID & Total Empty)
**Objective:** Validate permanent deletion of individual items and total bin contents.

**Steps:**
3.11. (Execution) Run `$SCRIPT empty $ID_FILE_TO_EMPTY`.

3.12. **(Verification 1)** Item removed from `metadata.db` (Empty by ID).

3.13. (Execution) Run `$SCRIPT empty --force`.

3.14. **(Verification 2)** `metadata.db` contains only 2 header lines (total cleanup).

3.15. (Execution) Run `$SCRIPT empty` (Test empty bin behavior).

3.16. **(Verification 3)** Command returns warning message that the bin is already empty.

**Expected Result:** All forms of emptying the recycle bin function; `exit_status = 0`.
**Status:** ☐ Pass ☐ Fail