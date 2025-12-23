#!/usr/bin/env bash

setup() {
  export TEST_ROOT="$(mktemp -d)"
  export OUTPUT_DIR="$TEST_ROOT/output"
  mkdir -p "$OUTPUT_DIR"

  # Mock journalctl (Linux-compatible)
  export PATH="$TEST_ROOT/mockbin:$PATH"
  mkdir -p "$TEST_ROOT/mockbin"

  cat > "$TEST_ROOT/mockbin/journalctl" <<'EOF'
#!/usr/bin/env bash
# Simulated journalctl output
if [[ "$*" == *"--since"* ]]; then
  echo "Jan 01 00:00:01 test-service error something failed"
  echo "Jan 01 00:00:02 test-service warning minor issue"
fi
exit 0
EOF
  chmod +x "$TEST_ROOT/mockbin/journalctl"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

