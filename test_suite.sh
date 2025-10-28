#!/bin/bash
# Test Suite for Recycle Bin System

SCRIPT="./recycle_bin.sh"
PASS=0
FAIL=0

# --- Color Configuration ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- File Configuration ---
# (Assuming the main SCRIPT is in the same directory)
if [ ! -f "$SCRIPT" ]; then
    echo -e "${RED}Error: Main script file ($SCRIPT) not found.${NC}"
    exit 1
fi
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"


# --- Helper Functions ---
assert_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

assert_fail() {
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

get_file_id() {
    local filename="$1"
    grep -i "$filename" "$METADATA_FILE" | tail -n 1 | cut -d',' -f1 | tr -d '[:space:]' | tr -d '\r'
}

# --- Test Setup ---
test_initialization() {
    echo -e "\n=== Test: Setup & Initialization ==="
    
    rm -rf "$RECYCLE_BIN_DIR"
    rm -f fileA.txt FileB.DOC "file with spaces #@.pdf" "file_to_restore_conflict.txt" file_to_empty.tmp large_file.bin no_perm_file.txt new_fileA.txt 2>/dev/null
    rm -rf dir_to_delete 2>/dev/null
    
    $SCRIPT help > /dev/null
    assert_success "Initialization (Creation of $RECYCLE_BIN_DIR)"

    # Create test files
    echo "content A" > fileA.txt
    echo "content B" > FileB.DOC
    mkdir -p dir_to_delete/sub_folder
    echo "content in folder" > dir_to_delete/sub_folder/subfile.log
    touch "file with spaces #@.pdf"
    touch "file_to_restore_conflict.txt"
    echo "original content" > file_to_restore_conflict.txt
    touch file_to_empty.tmp 
    dd if=/dev/zero of=large_file.bin bs=1M count=15 2>/dev/null
    touch no_perm_file.txt
    chmod 444 no_perm_file.txt

    echo -e "${GREEN}Test environment ready.${NC}"
}

global_teardown() {
    echo -e "\n${YELLOW}Cleaning up test environment...${NC}"
    rm -f fileA.txt FileB.DOC "file with spaces #@.pdf" "file_to_restore_conflict.txt" file_to_empty.tmp large_file.bin no_perm_file.txt new_fileA.txt 2>/dev/null
    rm -rf dir_to_delete 2>/dev/null
    rm -rf "$RECYCLE_BIN_DIR" 2>/dev/null
}

# --- Test Cases ---

test_delete_errors() {
    echo -e "\n=== Test: Delete (Error Cases) ==="
    $SCRIPT delete &>/dev/null
    assert_fail "Delete: Parsing no arguments"
    
    $SCRIPT delete non_existent_file.txt &>/dev/null
    assert_fail "Delete: Non-existent file"

    $SCRIPT delete "$RECYCLE_BIN_DIR" &>/dev/null
    assert_fail "Delete: Attempt to delete $RECYCLE_BIN_DIR itself"
    
    $SCRIPT delete no_perm_file.txt &>/dev/null
    assert_fail "Delete: File without permissions"
}

test_delete_success() {
    echo -e "\n=== Test: Delete (Success Cases) ==="
    $SCRIPT delete fileA.txt > /dev/null
    assert_success "Delete: Small file (fileA.txt)"
    
    $SCRIPT delete dir_to_delete > /dev/null
    assert_success "Delete: Directory (dir_to_delete)"

    $SCRIPT delete "file with spaces #@.pdf" > /dev/null
    assert_success "Delete: File with complex name"
    
    $SCRIPT delete large_file.bin > /dev/null
    assert_success "Delete: Large file (large_file.bin)"
    
    $SCRIPT delete file_to_empty.tmp > /dev/null
    assert_success "Delete: Temporary file (file_to_empty.tmp)"
    
    $SCRIPT delete FileB.DOC > /dev/null
    assert_success "Delete: Another file (FileB.DOC)"

    $SCRIPT delete file_to_restore_conflict.txt > /dev/null
    assert_success "Delete: File for conflict test"
}

test_list_and_stats() {
    echo -e "\n=== Test: List & Statistics ==="
    
    # Check if listing contains an expected item
    $SCRIPT list | grep -q "fileA.txt"
    assert_success "List: Non-empty bin check"

    $SCRIPT list --detailed | grep -q "Proprietary" 
    assert_success "List: Detailed listing (--detailed)"

    # Check statistics output (color-insensitive)
    $SCRIPT statistics | grep -E -q "Total Items:.* 7"
    assert_success "Statistics: Correct item count (7 items)"
}

test_search() {
    echo -e "\n=== Test: Search ==="
    
    $SCRIPT search "fileb" | grep -q "FileB.DOC"
    assert_success "Search: Partial name (case-insensitive)"
    
    $SCRIPT search "nonexistent123" 2>&1 | grep -q "No items found"
    assert_success "Search: Non-existent item"

    local ID_A=$(get_file_id "fileA.txt")
    # Check search by partial ID
    $SCRIPT search "${ID_A:0:5}" | grep -q "fileA.txt"
    assert_success "Search: Partial ID"
}

test_restore() {
    echo -e "\n=== Test: Restore (Conflicts and Rename) ==="    
    local ID_CONFLICT=$(get_file_id "file_to_restore_conflict.txt")

    $SCRIPT restore "111_nonexistent" &>/dev/null
    assert_fail "Restore: Non-existent ID"

    (echo -e "1\n" | $SCRIPT restore "$ID_CONFLICT") &> /dev/null
    assert_success "Restore: Conflict (Option 1 - Overwrite)"
    [ -f "file_to_restore_conflict.txt" ]
    assert_success "✓ Verification: 'file_to_restore_conflict.txt' restored"

    $SCRIPT delete fileA.txt > /dev/null
    echo "new content for conflict" > fileA.txt
    local ID_A_RENAME=$(get_file_id "fileA.txt")   

    (echo -e "2\nnew_fileA.txt\n" | $SCRIPT restore "$ID_A_RENAME") &> /dev/null
    assert_success "Restore: Conflict (Option 2 - Rename)"
    
    [ -f "new_fileA.txt" ]
    assert_success "✓ Verification: 'new_fileA.txt' restored successfully (Renamed)"
    
    [ "$(cat fileA.txt)" = "new content for conflict" ]
    assert_success "✓ Verification: 'fileA.txt' (original file) content unchanged"
}

test_empty() {
    echo -e "\n=== Test: Empty ==="
    
    local ID_FILE_TO_EMPTY=$(get_file_id "file_to_empty.tmp")
    
    $SCRIPT empty "$ID_FILE_TO_EMPTY" > /dev/null
    assert_success "Empty: Delete by specific ID"
    
    [ -z "$(get_file_id 'file_to_empty.tmp')" ]
    assert_success "✓ Verification: Item removed from metadata (Empty by ID)"

    $SCRIPT empty --force > /dev/null
    assert_success "Empty: Total emptying (--force)"

    local line_count=$(wc -l < "$METADATA_FILE" 2>/dev/null)
    [ "$line_count" -eq 2 ]
    assert_success "✓ Verification: Metadata cleared (only headers remain)"

    $SCRIPT empty 2>&1 | grep -q "already empty"
    assert_success "Empty: Warning on empty bin"
}

# --- Test Execution ---
echo "========================================="
echo " Recycle Bin Test Suite"
echo "========================================="

test_initialization

test_delete_errors
test_delete_success
test_list_and_stats
test_search
test_restore
test_empty

global_teardown

echo "========================================="
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "========================================="

[ $FAIL -eq 0 ] && exit 0 || exit 1