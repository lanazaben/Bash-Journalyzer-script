
load helpers.bash

SCRIPTS_DIR="../scripts"
# 1. Smoke Testing

@test "TC-001 Valid Execution of Online Log Extraction" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/valid_config.conf
}

@test "TC-002 Normal Offline Log Processing" {
  run bash "$SCRIPTS_DIR/offline2.sh" tests/fixtures/offline_logs
}

@test "TC-003 Integration Smoke Test: Service Import → Online Script" {
  run bash "$SCRIPTS_DIR/serviceImport.sh" tests/fixtures/valid_config.conf

  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/valid_config.conf
}

@test "TC-004 Missing Configuration File" {
  run bash "$SCRIPTS_DIR/journal.sh" missing.conf
}
# 2. Black Box Functional Testing

@test "TC-005 Service With No Logs in Time Range" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/empty_services.conf
}

@test "TC-006 Invalid Service Name in Config" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/invalid_config.conf
}

@test "TC-007 Missing Offline Log Files" {
  run bash "$SCRIPTS_DIR/offline2.sh" missing_dir
}

@test "TC-008 Alert Threshold Triggering" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/valid_config.conf
  [[ "$output" =~ ALERT|alert ]]
}

@test "TC-009 Processing Multiple Services (Offline Mode)" {
  run bash "$SCRIPTS_DIR/offline2.sh" tests/fixtures/offline_logs
}

@test "TC-010 Future Time Range in Online Mode" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/future_time.conf
  [[ "$output" =~ 0 ]]
}

@test "TC-011 Empty Service List" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/empty_services.conf
}

@test "TC-012 Duplicate Services in Configuration" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/services_with_duplicates.conf
}

@test "TC-013 Partial Service Failure" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/invalid_config.conf
  [[ "$output" =~ error|ERROR ]]
}

@test "TC-014 Empty Offline Log File" {
  run bash "$SCRIPTS_DIR/offline2.sh" tests/fixtures/offline_logs/empty.log
}

@test "TC-015 Special Characters in Service Names" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/services_special_chars.conf
}

@test "TC-016 Single Log Entry Boundary Case" {
  run bash "$SCRIPTS_DIR/offline2.sh" tests/fixtures/offline_logs/nginx.log
}
# 3. White Box Testing
@test "TC-017 Valid Time Parsing" {
  run bash "$SCRIPTS_DIR/timeRange.sh" "2025-01-01 00:00" "2025-01-01 01:00"
}

@test "TC-018 Invalid Time Range Format" {
  run bash "$SCRIPTS_DIR/timeRange.sh" "invalid"
}

@test "TC-019 Valid Service Import File" {
  run bash "$SCRIPTS_DIR/serviceImport.sh" tests/fixtures/valid_config.conf
}

@test "TC-020 Empty or Malformed Import File" {
  run bash "$SCRIPTS_DIR/serviceImport.sh" tests/fixtures/invalid_config.conf
}

# 4. Error Handling / Negative Testing

@test "TC-028 Output Directory Not Writable" {
  mkdir -p "$TEST_ROOT/readonly"
  chmod 500 "$TEST_ROOT/readonly"
  export OUTPUT_DIR="$TEST_ROOT/readonly"
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/valid_config.conf
}

@test "TC-029 Run Online Script Without Permissions" {
  chmod -x "$SCRIPTS_DIR/journal.sh"
  run "$SCRIPTS_DIR/journal.sh"
  [ "$status" -ne 0 ]
  chmod +x "$SCRIPTS_DIR/journal.sh"
}

@test "TC-030 Corrupted Offline Log File" {
  run bash "$SCRIPTS_DIR/offline2.sh" tests/fixtures/offline_logs/corrupted.log
}
# 7. Security & Boundary Testing
@test "TC-036 Output File Permission Verification" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/valid_config.conf
  find "$OUTPUT_DIR" -type f -perm /002 | wc -l | grep -q '^0$'
}

@test "TC-038 Zero Logs Across All Services" {
  run bash "$SCRIPTS_DIR/journal.sh" tests/fixtures/empty_services.conf
}

