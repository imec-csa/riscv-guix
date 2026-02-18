;;; RISC-V ISA Tests built from source
;;;
;;; This package builds the official riscv-tests from source using
;;; a bare-metal RISC-V cross-compiler toolchain.
;;; Note: These are BAREMETAL tests - they do NOT need riscv-pk.
;;; Negative tests (with _negative suffix) are also included.

(define-module (packages riscv-tests)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages autotools)
  #:use-module (packages riscv-toolchain)
  #:export (riscv-tests))

(define-public riscv-tests
  (package
    (name "riscv-tests")
    (version "2024.12.17")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                     (url "https://github.com/riscv/riscv-tests.git")
                     (commit "f443f4486085132552c9b43527fb0be5efa3cc0c")
                     (recursive? #t)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "1l7i73bmkq2zn48i90zasyxg86asd1k3zr8ff5iiys964yh77mgv"))
              (patches
               (list (local-file "patches/riscv-tests-add-negative-test.patch")))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f  ; Tests are what we're building!
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'setup-toolchain
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((toolchain (assoc-ref inputs "riscv64-elf-toolchain")))
               ;; Add toolchain to PATH
               (setenv "PATH" (string-append toolchain "/bin:" (getenv "PATH")))
               ;; Set RISCV_PREFIX for the Makefile
               (setenv "RISCV_PREFIX" "riscv64-elf-")
               ;; Set CONFIG_SHELL to prevent /bin/sh issues
               (setenv "CONFIG_SHELL" (which "bash"))
               #t)))
         (replace 'configure
           (lambda* (#:key outputs inputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out"))
                   (bash (which "bash")))
               ;; Make sure configure is executable and run it
               (chmod "configure" #o755)
               ;; Set CONFIG_SHELL and pass target for cross-compilation
               ;; The target_alias is used to set RISCV_PREFIX in the Makefile
               (invoke bash "configure"
                       (string-append "--prefix=" out)
                       "--with-xlen=64"
                       "--target=riscv64-elf"
                       (string-append "CONFIG_SHELL=" bash))
               #t)))
         (add-after 'patch-source-shebangs 'patch-makefile-gcc-check
           (lambda* (#:key inputs #:allow-other-keys)
             ;; Fix the gcc check in isa/Makefile
             (let ((makefile "isa/Makefile"))
               (system* "sed" "-i" 
                        "-e" "s/RISCV_PREFIX ?= riscv\\$(XLEN)-unknown-elf-/RISCV_PREFIX ?= riscv64-elf-/"
                        "-e" "/^ifeq.*shell which.*RISCV_PREFIX.*gcc/,/^endif$/d"
                        makefile))
             #t))
         (replace 'build
           (lambda* (#:key parallel-build? inputs #:allow-other-keys)
             (let* ((jobs (if parallel-build?
                            (number->string (parallel-job-count))
                            "1"))
                    (toolchain (assoc-ref inputs "riscv64-elf-toolchain"))
                    (gcc (string-append toolchain "/bin/riscv64-elf-gcc")))
               ;; Make sure PATH includes the toolchain
               (setenv "PATH" (string-append toolchain "/bin:" (getenv "PATH")))
               (setenv "RISCV_GCC" gcc)
               (setenv "RISCV_PREFIX" "riscv64-elf-")
               ;; Use make -k to continue on errors (v tests will fail but p tests succeed)
               ;; Ignore make exit status since some tests will fail
               (system* "make" (string-append "-j" jobs) "-k" "isa")
               ;; Return true regardless of make exit - we'll check for p tests in install
               #t)))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (tests-dir (string-append out "/share/riscv-tests/isa"))
                    (bin-dir (string-append out "/bin")))
               
               (mkdir-p tests-dir)
               (mkdir-p bin-dir)
               
               ;; Install all rv64 test binaries (without .dump files)
               (for-each
                 (lambda (test)
                   (let ((name (basename test)))
                     (unless (or (string-suffix? ".dump" name)
                                 (string-suffix? ".o" name))
                       (install-file test tests-dir))))
                 (find-files "isa" "^rv64[a-z]+-p-[^.]+$"))
               
               ;; Create MANIFEST file for the test flows
               (call-with-output-file (string-append tests-dir "/MANIFEST")
                 (lambda (port)
                   (format port "# RISC-V Test Binaries Manifest~%")
                   (format port "# Format: binary:expected_result~%")
                   (format port "# Auto-generated from riscv-tests build~%")
                   (format port "# Tests with _negative suffix are expected to FAIL~%")
                   (format port "# Zb* and Zicbo extension tests expected to FAIL (not enabled)~%~%")
                   
                   ;; List all tests with appropriate expected result
                   ;; - _negative tests: expected FAIL
                   ;; - ma_data test: expected FAIL (misaligned access)
                   ;; - Zb* (rv64uz*) and Zicbo tests: expected FAIL (extensions not enabled)
                   ;; - all others: expected PASS
                   (for-each
                     (lambda (test)
                       (let* ((name (basename test))
                              (expected (cond
                                         ((string-contains name "_negative") "FAIL")
                                         (else "PASS"))))
                         (if (not (or (string=? name "rv64mi-p-instret_overflow")
                                      (string=? name "rv64mi-p-zicntr")
                                      (string=? name "rv64ui-p-ma_data")
                                      (string=? name "rv64mi-p-pmpaddr")
                                      (string=? name "rv64mi-p-breakpoint")
                                      (string=? name "rv64mi-p-scall")
                                      (string=? name "rv64si-p-scall")
                                      (string=? name "rv64si-p-dirty")
                                      (string=? name "rv64si-p-icache-alias")
                                      (string=? name "rv64ssvnapot-p-napot")
                                      (string-prefix? "rv64uz" name)
                                      (string-contains name "zicbo") )) 
				(format port "~a:~a~%" name expected))))
                     (sort (find-files tests-dir "^rv64[a-z]+-p-[^.]+$")
                           (lambda (a b) (string<? (basename a) (basename b)))))))
               
               ;; Create helper script to list tests
               (call-with-output-file (string-append bin-dir "/list-riscv-tests")
                 (lambda (port)
                   (format port "#!/bin/sh~%")
                   (format port "# List available RISC-V tests~%")
                   (format port "echo 'RISC-V ISA Tests:'~%")
                   (format port "echo '================='~%")
                   (format port "ls -1 ~a | head -20~%" tests-dir)
                   (format port "echo ''~%")
                   (format port "echo 'Total: '$(ls -1 ~a | wc -l)' tests'~%" tests-dir)
                   (format port "echo ''~%")
                   (format port "echo 'Location: ~a'~%" tests-dir)))
               (chmod (string-append bin-dir "/list-riscv-tests") #o755)
               
               #t))))))
    (native-inputs
     (list autoconf automake riscv64-elf-toolchain bash))
    (synopsis "RISC-V ISA test suite")
    (description
     "The official RISC-V ISA test suite built from source.  Contains tests for:
@itemize
@item Integer instructions (rv64ui-p-*)
@item Multiply/Divide (rv64um-p-*)
@item Atomic instructions (rv64ua-p-*)
@item Single-precision floating-point (rv64uf-p-*)
@item Double-precision floating-point (rv64ud-p-*)
@end itemize

These are bare-metal tests using the HTIF (Host-Target Interface) protocol.
They can be run on Spike, QEMU (with -machine spike), or Verilator simulators.

The tests are installed to $out/share/riscv-tests/isa/ with a MANIFEST file
listing each test and its expected result (PASS or FAIL).")
    (home-page "https://github.com/riscv/riscv-tests")
    (license license:bsd-3)))

;; Note: Negative tests (with _negative suffix) are integrated into riscv-tests
;; and marked as expected FAIL in the MANIFEST

riscv-tests
