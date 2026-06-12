# Guix CVA6 - RISC-V Test Flows

A Guix-based reproducible build system for running RISC-V ISA tests across multiple simulators:
- **Spike ISA Simulator** - Fast, reference implementation
- **QEMU System Emulator** - Full system emulation with HTIF support  
- **RISC-V-VP++ System Simulator** - Full system emulation with SystemC TLM models
- **Gem5 Simulator** - Full system simulation with workaround for buggy HTIF support  
- **CVA6 Verilator** - Cycle-accurate RTL simulation

Includes **~200 pre-built RISC-V ISA tests** that run automatically across all simulators with result verification.

## Using as a Guix Channel

This repository is a [Guix channel](https://guix.gnu.org/manual/en/html_node/Channels.html). Anyone with access can add it to their Guix configuration to install packages directly.

### Option 1: Add to your channels.scm

Copy `channels.scm` to `~/.config/guix/channels.scm`, or merge it with your existing channels file:

```scheme
(list
 (channel
  (name 'guix)
  (url "https://git.guix.gnu.org/guix.git")
  (branch "master")
  (introduction
    (make-channel-introduction
      "9edb3f66fd807b096b48283debdcddccfea34bad"
      (openpgp-fingerprint
       "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 61AF 2A30 8831"))))
 (channel
  (name 'riscv-guix)
  (url "https://github.com/imec-CSA/riscv-guix.git")
  (branch "stable")))
```

Then pull and install packages:

```bash
guix pull
guix package --list-available | grep 'packages/'
guix build verilated-cva6
```

### Option 2: Use locally with `-L`

If you have a local clone, you can use the packages directly without configuring a channel:

```bash
guix time-machine -C channels.scm -- build -L . riscv-test-flows

# This will:
# 1. Build CVA6 Verilator simulator from CVA6 v4.2.0 source
# 2. Run ~200 RISC-V ISA tests on Spike, QEMU, and CVA6
# 3. Verify all results match expected outcomes
# 4. Report: "ALL TESTS VERIFIED SUCCESSFULLY"
```

**Note**: Building CVA6 from source takes ~30 minutes. The full test suite with CVA6 takes hours due to RTL simulation.

### Run Individual Simulator Flows

```bash
# Run tests on Spike only (fast, ~1 minute)
guix build -L . spike-flow

# Run tests on QEMU only (~3 minutes)
guix build -L . qemu-flow

# Run tests on CVA6 Verilator only (slow - hours!)
guix build -L . cva6-flow
```

## What Tests Are Included?

This repository includes **~200 pre-built RISC-V ISA tests** in `riscv-tests-scalar/`:

| Test Category | Count | Description |
|---------------|-------|-------------|
| `rv64ui-p-*` | 54 | Integer unit tests |
| `rv64um-p-*` | 13 | Multiply/Divide tests |
| `rv64ua-p-*` | 19 | Atomic instruction tests |
| `rv64uf-p-*` | 11 | Single-precision float tests |
| `rv64ud-p-*` | 12 | Double-precision float tests |
| Custom | 2 | `add-positive` (PASS), `add-negative` (FAIL) |

All tests are bare-metal binaries using the HTIF (Host-Target Interface) protocol.

## How It Works

The test framework follows a flow-based architecture:

```
riscv-test-binary (around 200 tests)
      |
      +----> spike-flow  ----+
      |                      |
      +----> qemu-flow   ----+----> riscv-test-flows (verifies all)
      |                      |
      +----> cva6-flow   ----+
```

Each flow:
1. **Runs** all tests on its simulator
2. **Captures** results (PASS/FAIL/TIMEOUT)
3. **Saves** results to `$out/tmp/<simulator>-results.txt`

The final `riscv-test-flows` package:
1. **Reads** all three result files
2. **Verifies** each test matches expected result
3. **Fails build** if any test has wrong outcome
4. **Reports** "ALL TESTS VERIFIED SUCCESSFULLY" if all pass

## Package Reference

### Core Packages

| Package | Description |
|---------|-------------|
| `riscv-test-binary` | arounf 200 pre-built RISC-V ISA test binaries |
| `verilated-cva6` | CVA6 v4.2.0 Verilator simulator binary |
| `spike-flow` | Runs tests on Spike ISA simulator |
| `qemu-flow` | Runs tests on QEMU system emulator |
| `cva6-flow` | Runs tests on CVA6 Verilator (SLOW) |
| `riscv-test-flows` | **Main package** - Runs all flows and verifies results |

### Build a Specific Package

```bash
# Just the test binaries
guix build -L . riscv-test-binary

# Just the CVA6 simulator
guix build -L . verilated-cva6

# Individual flows
guix build -L . spike-flow
guix build -L . qemu-flow
guix build -L . cva6-flow

# Everything (recommended)
guix build -L . riscv-test-flows
```

## Viewing Test Results

After building, view the results:

```bash
# View Spike results
cat /gnu/store/*-spike-flow-*/tmp/spike-results.txt

# View QEMU results
cat /gnu/store/*-qemu-flow-*/tmp/qemu-results.txt

# View CVA6 results (if you ran cva6-flow)
cat /gnu/store/*-cva6-flow-*/tmp/cva6-results.txt
```

Results format:
```
test_name: ACTUAL=PASS EXPECTED=PASS
test_name: ACTUAL=FAIL EXPECTED=FAIL
test_name: ACTUAL=TIMEOUT EXPECTED=PASS  # Error!
```

## Debugging Individual Tests

Each flow saves individual test outputs:

```bash
# Example: Debug a specific test on QEMU
cat /gnu/store/*-qemu-flow-*/tmp/rv64ui-p-add-qemu.txt

# Example: See why a test timed out on CVA6
cat /gnu/store/*-cva6-flow-*/tmp/rv64ui-p-fence_i-cva6.txt
```

### QEMU Debug Mode

To see disassembly and execution trace when running QEMU manually:

```bash
# Show disassembly
qemu-system-riscv64 -nographic -machine spike -bios none \
  -kernel riscv-tests-scalar/rv64ui-p-add \
  -d in_asm -D trace.log </dev/null

# Show execution trace
qemu-system-riscv64 -nographic -machine spike -bios none \
  -kernel riscv-tests-scalar/rv64ui-p-add \
  -d exec -D trace.log </dev/null

# Show everything (registers + disassembly + execution)
qemu-system-riscv64 -nographic -machine spike -bios none \
  -kernel riscv-tests-scalar/rv64ui-p-add \
  -d in_asm,cpu,exec,nochain -D trace.log </dev/null
```

## Contributing / Adding More Tests

To add more tests:

1. Add test binaries to `riscv-tests-scalar/`
2. Update `riscv-tests-scalar/MANIFEST` with format:
   ```
   test-name:EXPECTED_RESULT
   ```
3. Rebuild: `guix build -L . riscv-test-flows`

The framework will automatically run and verify the new tests.

## Technical Details

### Flow Execution Time

| Flow | Tests | Typical Time |
|------|-------|--------------|
| `spike-flow` | ~200 | ~1 minute |
| `qemu-flow` | ~200 | ~3 minutes |
| `cva6-flow` | ~200 | **Hours** (RTL simulation) |
| `riscv-test-flows` (all) | 333 | Hours (waits for CVA6) |

**Tip**: Build flows individually during development, use `riscv-test-flows` for final verification.

### Platform-Specific Behavior

The `rv64ui-p-ma_data` test checks misaligned data access:
- **QEMU**: PASS (emulates misaligned access)
- **Spike**: FAIL (doesn't support misaligned access by default)
- **CVA6**: FAIL (hardware doesn't support misaligned access)

The verification script handles this difference automatically.

### Why Are These Tests "Bare-Metal"?

The test binaries have ELF OS/ABI "UNIX - System V" but are actually **bare-metal**:

1. **Entry point**: `0x80000000` (standard bare-metal address)
2. **Protocol**: HTIF (Host-Target Interface) using `tohost`/`fromhost` memory locations
3. **No OS**: Tests signal pass/fail by writing to HTIF memory addresses
4. **No syscalls**: Direct hardware-level execution

Each simulator has built-in HTIF support:
- **Spike**: Native HTIF support (built-in)
- **QEMU**: `-machine spike` emulates HTIF protocol
- **CVA6**: Verilator testbench implements HTIF

**No proxy kernel (pk) needed** for these tests!

### Why Verilator 4.110?

CVA6 v4.2.0 works reliably with Verilator 4.110. Verilator 5.x has compatibility issues with the CVA6 codebase.

### Key Bugfix: QEMU Stdin Consumption

The QEMU flow was failing because `qemu-system-riscv64 -nographic` consumed stdin from the test loop, corrupting test names. Fixed by adding `</dev/null` to prevent stdin consumption.
 
