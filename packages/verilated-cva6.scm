;;; we're using Verilator 4.110 because it works reliably with CVA6 v4.2.0.
;;; Verilator 5.024 also works but needs extra patches and help2man workarounds.

(define-module (packages verilated-cva6)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages check)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix utils)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages virtualization)  ; For spike which provides fesvr
  #:use-module (packages verilator-4-110)
  #:export (verilated-cva6))

;;; CVA6 Source
;;; We're using the official openhwgroup/cva6 v4.2.0 release because it's
;;; the most recent version that actually works with Verilator 4.110.
(define cva6-source
  (origin
    (method git-fetch)
    (uri (git-reference
           (url "https://github.com/openhwgroup/cva6.git")
           (commit "v4.2.0")
           (recursive? #t)))
    (file-name (git-file-name "cva6" "v4.2.0"))
    (sha256
     (base32
      "1pb96f2q7893fjg2v93p74vml4giw6rlwm20bw7nlbfyvmiwc935"))))

(define-public verilated-cva6
  (package
    (name "verilated-cva6")
    (version "1.0.0")
    (source cva6-source)
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f  ; Skip tests for now
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)  ; No configure script
         (add-before 'build 'patch-makefile
           (lambda _
             ;; Turn down Verilator's optimization to avoid weird issues
             (substitute* "Makefile"
               (("-O3") "-O1"))
             #t))
         (add-before 'build 'set-environment
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((verilator (assoc-ref inputs "verilator"))
                   (gcc (assoc-ref inputs "gcc-toolchain"))
                   (spike (assoc-ref inputs "spike")))
               ;; Set up paths so the CVA6 build can find everything
               (setenv "RISCV" gcc)
               (setenv "CVA6_REPO_DIR" (getcwd))
               (setenv "PATH" (string-append (getenv "PATH") ":"
                                            verilator "/bin:"
                                            gcc "/bin"))
               ;; Set up include/library paths for fesvr from spike
               (setenv "CPLUS_INCLUDE_PATH" 
                       (string-append spike "/include:"
                                      (or (getenv "CPLUS_INCLUDE_PATH") "")))
               (setenv "LIBRARY_PATH"
                       (string-append spike "/lib:"
                                      (or (getenv "LIBRARY_PATH") "")))
               (setenv "LD_LIBRARY_PATH"
                       (string-append spike "/lib:"
                                      (or (getenv "LD_LIBRARY_PATH") "")))
               #t)))
         (replace 'build
           (lambda* (#:key parallel-build? #:allow-other-keys)
             (let ((jobs (if parallel-build?
                           (number->string (parallel-job-count))
                           "1")))
               ;; This is where we actually build the Verilator simulator
               (invoke "make" "CFG_CXXFLAGS_STD_NEWEST='-std=c++17'" "verilate" (string-append "-j" jobs)))))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (share (string-append out "/share/verilator-cva6")))
               
               ;; Set up the directory structure
               (mkdir-p bin)
               (mkdir-p share)
               
               ;; Install the Verilator simulator (this is the actual hardware model)
               (copy-file "work-ver/Variane_testharness"
                         (string-append bin "/verilated-cva6"))
               (chmod (string-append bin "/verilated-cva6") #o755)
               
               ;; Create a friendly wrapper script so you don't have to remember the flags
               (call-with-output-file (string-append bin "/verilator-cva6-run")
                 (lambda (port)
                   (format port "#!~a/bin/bash~%~%" (assoc-ref %build-inputs "bash"))
                   (format port "# Verilator CVA6 Flow Runner~%")
                   (format port "# Usage: verilator-cva6-run [options] <pk> <riscv64-binary> [args...]~%~%")
                   (format port "set -e~%")
                   (format port "CVA6=~a/bin/verilated-cva6~%" out)
                   (format port "# Note: pk not included - install separately if needed~%")
                   (format port "# How long to wait before giving up~%")
                   (format port "TIMEOUT=\"+time_out=10000000\"~%")
                   (format port "MAX_CYCLES=\"+max-cycles=100000000\"~%")
                   (format port "~%")
                   (format port "# Parse options~%")
                   (format port "while [[ $# -gt 0 ]]; do~%")
                   (format port "  case $1 in~%")
                   (format port "    --timeout)~%")
                   (format port "      TIMEOUT=\"+time_out=$2\"~%")
                   (format port "      shift 2~%")
                   (format port "      ;;~%")
                   (format port "    --max-cycles)~%")
                   (format port "      MAX_CYCLES=\"+max-cycles=$2\"~%")
                   (format port "      shift 2~%")
                   (format port "      ;;~%")
                   (format port "    *)~%")
                   (format port "      break~%")
                   (format port "      ;;~%")
                   (format port "  esac~%")
                   (format port "done~%")
                   (format port "~%")
                   (format port "if [ $# -eq 0 ]; then~%")
                   (format port "  echo \"Error: No binary specified\"~%")
                   (format port "  echo \"Usage: verilator-cva6-run [--timeout N] [--max-cycles N] <riscv64-binary> [args...]\"~%")
                   (format port "  echo \"\"~%")
                   (format port "  echo \"Options:\"~%")
                   (format port "  echo \"  --timeout N      How long to wait (default: 10000000)\"~%")
                   (format port "  echo \"  --max-cycles N   Stop after this many cycles (default: 100000000)\"~%")
                   (format port "  exit 1~%")
                   (format port "fi~%")
                   (format port "~%")
                   (format port "# Convert relative paths to absolute ones~%")
                   (format port "BINARY=\"$1\"~%")
                   (format port "shift~%")
                   (format port "if [[ \"$BINARY\" != /* ]]; then~%")
                   (format port "  BINARY=\"$(cd \"$(dirname \"$BINARY\")\" && pwd)/$(basename \"$BINARY\")\"~%")
                   (format port "fi~%")
                   (format port "~%")
                   (format port "if [ ! -f \"$BINARY\" ]; then~%")
                   (format port "  echo \"Error: Can't find binary: $BINARY\"~%")
                   (format port "  exit 1~%")
                   (format port "fi~%")
                   (format port "~%")
                   (format port "echo \"Running CVA6 Verilator simulation...\"~%")
                   (format port "echo \"Binary: $BINARY\"~%")
                   (format port "echo \"Note: RTL simulation is SLOW. Grab a coffee (or three).\"~%")
                   (format port "exec $CVA6 $TIMEOUT $MAX_CYCLES $PK \"$BINARY\" \"$@\"~%")))
               
               ;; Make wrapper executable
               (chmod (string-append bin "/verilator-cva6-run") #o755)
               
               ;; Create a helpful README
               (call-with-output-file (string-append share "/README")
                 (lambda (port)
                   (format port "Verilator CVA6 Flow~%")
                   (format port "===================~%~%")
                   (format port "This package provides a Verilator-based RTL simulation flow for~%")
                   (format port "running RISC-V binaries on the CVA6 (Ariane) core.~%~%")
                   (format port "Usage:~%")
                   (format port "  verilator-cva6-run [options] <riscv64-binary> [args...]~%~%")
                   (format port "Options:~%")
                   (format port "  --timeout N      How long to wait (default: 10000000)~%")
                   (format port "  --max-cycles N   Stop after this many cycles (default: 100000000)~%~%")
                   (format port "Example:~%")
                   (format port "  guix build --target=riscv64-linux-gnu hello-static~%")
                   (format port "  verilator-cva6-run ~/.guix-profile/bin/hello~%~%")
                   (format port "Note: RTL simulation is VERY slow. A simple hello world may take~%")
                   (format port "30+ minutes to complete. Complex programs can take hours.~%~%")
                   (format port "For faster simulation, use qemu-riscv or spike-riscv flows.~%~%")))
               
               #t))))))
    (native-inputs
     (list gcc-toolchain python python-pytest verilator-4.110 spike))
    (inputs
     (list bash coreutils spike))
    ;(propagated-inputs (list verilator-4.110))
    (synopsis "Cycle-accurate CVA6 RISC-V simulator using Verilator")
    (description
     "This package builds the CVA6 (Ariane) RISC-V processor using Verilator
and gives you a cycle-accurate RTL simulator. It's the most accurate way to
test code but painfully slow - think 30+ minutes for hello world.

We're using Verilator 4.110 because it's known to work well with CVA6 v4.2.0.
(Verilator 5.024 works too but needs extra patches.)

If you just want to test your code works, use qemu-riscv or spike-riscv instead.
Save Verilator for when you need to verify actual hardware behavior.")
    (home-page "https://github.com/openhwgroup/cva6")
    (license license:bsd-3)))

;; Return the package when file is loaded directly with -f
verilated-cva6
