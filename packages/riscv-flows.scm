;;; Flow-based RISC-V test framework
;;; Each flow runs the same riscv-tests on a different simulator.
;;; A single shared run-flow.sh script reads MANIFEST and outputs CSV.
;;; The riscv-test-flows package verifies all CSVs match the reference model.
(define-module (packages riscv-flows)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages gawk)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages virtualization)
  #:use-module (gnu packages multiprecision)
  #:use-module (gnu packages compression)
  #:use-module (packages verilated-cva6)
  #:use-module (packages riscv-tests)
  #:use-module (packages riscv-toolchain)
  #:use-module (packages rv-vp-plus-plus)
  #:use-module (packages gem5)
  #:re-export (verilated-cva6 riscv-tests)
  #:export (spike-flow
           qemu-flow
           cva6-flow
           vp-flow
           gem5-flow
           sail-riscv-flow
           riscv-test-flows))

(define-public spike-flow
  (package
    (name "spike-flow")
    (version "1.0.1")
    (source (local-file "scripts/run-flow.sh"))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((out (assoc-ref %outputs "out"))
               (tmp-dir (string-append out "/tmp"))
               (bin-dir (string-append out "/bin"))
               (script-src (assoc-ref %build-inputs "source"))
               (spike-bin (string-append (assoc-ref %build-inputs "spike") "/bin/spike"))
               (test-dir (string-append (assoc-ref %build-inputs "riscv-tests") "/share/riscv-tests/isa"))
               (bash-bin (string-append (assoc-ref %build-inputs "bash") "/bin/bash")))

           (mkdir-p tmp-dir)
           (mkdir-p bin-dir)

           (copy-file script-src (string-append bin-dir "/run-flow"))
           (substitute* (string-append bin-dir "/run-flow")
            (("#!/bin/sh") (string-append "#!" bash-bin)))
           (chmod (string-append bin-dir "/run-flow") #o755)

           (setenv "PATH" (string-append (assoc-ref %build-inputs "coreutils") "/bin"))
           (setenv "SH" bash-bin)
           (setenv "SIM_NAME" "spike")
           (setenv "SIM_CMD" (string-append spike-bin " --isa=rv64gc __TEST__"))
           (setenv "TIMEOUT" "30")
           (setenv "TEST_DIR" test-dir)
           (setenv "OUT_DIR" tmp-dir)
           (invoke (string-append bin-dir "/run-flow"))
           #t))))
    (native-inputs (list spike riscv-tests bash coreutils))
    (synopsis "Spike ISA simulator test flow")
    (description "Runs RISC-V tests on Spike.  Results: $out/tmp/spike-results.csv")
    (home-page "https://github.com/riscv/riscv-isa-sim")
    (license license:bsd-3)))

(define-public qemu-flow
  (package
    (name "qemu-flow")
    (version "1.0.1")
    (source (local-file "scripts/run-flow.sh"))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((out (assoc-ref %outputs "out"))
               (tmp-dir (string-append out "/tmp"))
               (bin-dir (string-append out "/bin"))
               (script-src (assoc-ref %build-inputs "source"))
               (qemu-bin (string-append (assoc-ref %build-inputs "qemu") "/bin/qemu-system-riscv64"))
               (test-dir (string-append (assoc-ref %build-inputs "riscv-tests") "/share/riscv-tests/isa"))
               (bash-bin (string-append (assoc-ref %build-inputs "bash") "/bin/bash")))

           (mkdir-p tmp-dir)
           (mkdir-p bin-dir)

           (copy-file script-src (string-append bin-dir "/run-flow"))
           (substitute* (string-append bin-dir "/run-flow")
            (("#!/bin/sh") (string-append "#!" bash-bin)))
           (chmod (string-append bin-dir "/run-flow") #o755)

           (setenv "PATH" (string-append (assoc-ref %build-inputs "coreutils") "/bin"))
           (setenv "SH" bash-bin)
           (setenv "SIM_NAME" "qemu")
           (setenv "SIM_CMD" (string-append qemu-bin " -nographic -machine spike -bios none -kernel __TEST__ </dev/null"))
           (setenv "TIMEOUT" "30")
           (setenv "TEST_DIR" test-dir)
           (setenv "OUT_DIR" tmp-dir)
           (invoke (string-append bin-dir "/run-flow"))
           #t))))
    (native-inputs (list qemu riscv-tests bash coreutils))
    (synopsis "QEMU system-mode test flow")
    (description "Runs RISC-V tests on QEMU.  Results: $out/tmp/qemu-results.csv")
    (home-page "https://www.qemu.org")
    (license license:gpl2+)))

(define-public cva6-flow
  (package
    (name "cva6-flow")
    (version "1.0.1")
    (source (local-file "scripts/run-flow.sh"))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((out (assoc-ref %outputs "out"))
               (tmp-dir (string-append out "/tmp"))
               (bin-dir (string-append out "/bin"))
               (script-src (assoc-ref %build-inputs "source"))
               (cva6-bin (string-append (assoc-ref %build-inputs "verilated-cva6") "/bin/verilated-cva6"))
               (test-dir (string-append (assoc-ref %build-inputs "riscv-tests") "/share/riscv-tests/isa"))
               (bash-bin (string-append (assoc-ref %build-inputs "bash") "/bin/bash")))

           (mkdir-p tmp-dir)
           (mkdir-p bin-dir)

           (copy-file script-src (string-append bin-dir "/run-flow"))
           (substitute* (string-append bin-dir "/run-flow")
            (("#!/bin/sh") (string-append "#!" bash-bin)))
           (chmod (string-append bin-dir "/run-flow") #o755)

           (setenv "PATH" (string-append (assoc-ref %build-inputs "coreutils") "/bin"))
           (setenv "SH" bash-bin)
           (setenv "SIM_NAME" "cva6")
           (setenv "SIM_CMD" (string-append cva6-bin " __TEST__"))
           (setenv "TIMEOUT" "60")
           (setenv "TEST_DIR" test-dir)
           (setenv "OUT_DIR" tmp-dir)
           (invoke (string-append bin-dir "/run-flow"))
           #t))))
    (native-inputs (list verilated-cva6 riscv-tests bash coreutils))
    (synopsis "CVA6 Verilator test flow")
    (description "Runs RISC-V tests on CVA6 RTL simulation.  Results: $out/tmp/cva6-results.csv")
    (home-page "https://github.com/openhwgroup/cva6")
    (license license:bsd-3)))

(define-public gem5-flow
  (package
    (name "gem5-flow")
    (version "1.0.1")
    (source (local-file "scripts" "scripts" #:recursive? #t))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((out (assoc-ref %outputs "out"))
               (tmp-dir (string-append out "/tmp"))
               (bin-dir (string-append out "/bin"))
               (scripts-dir (assoc-ref %build-inputs "source"))
               (gem5-path (string-append (assoc-ref %build-inputs "gem5") "/share/gem5/configs"))
               (test-dir (string-append (assoc-ref %build-inputs "riscv-tests") "/share/riscv-tests/isa"))
               (bash-bin (string-append (assoc-ref %build-inputs "bash") "/bin/bash")))

           (mkdir-p tmp-dir)
           (mkdir-p bin-dir)

           ;; Install shared flow runner (needs substitute* for shebang)
           (copy-file (string-append scripts-dir "/run-flow.sh")
                     (string-append bin-dir "/run-flow"))
           (substitute* (string-append bin-dir "/run-flow")
            (("#!/bin/sh") (string-append "#!" bash-bin)))
           (chmod (string-append bin-dir "/run-flow") #o755)

           ;; gem5_baremetal.sh and .py are already in scripts-dir with execute bits
           (setenv "PATH" (string-append (assoc-ref %build-inputs "coreutils") "/bin:"
                                        (assoc-ref %build-inputs "gawk") "/bin:"
                                        (assoc-ref %build-inputs "gem5") "/bin"))
           (setenv "PYTHONPATH" gem5-path)
           (setenv "TMPDIR" tmp-dir)
           (setenv "SH" bash-bin)
           (setenv "SIM_NAME" "gem5")
           (setenv "SIM_CMD" (string-append scripts-dir "/gem5_baremetal.sh --elf __TEST__"))
           (setenv "TIMEOUT" "60")
           (setenv "TEST_DIR" test-dir)
           (setenv "OUT_DIR" tmp-dir)
           (invoke (string-append bin-dir "/run-flow"))
           #t))))
    (native-inputs
     (list gem5 riscv-tests bash coreutils gawk))
    (synopsis "Gem5 test flow")
    (description "Runs RISC-V tests on Gem5.  Results: $out/tmp/gem5-results.csv")
    (home-page "https://github.com/gem5")
    (license license:bsd-3)))

(define-public sail-riscv-flow
  (package
    (name "sail-riscv-flow")
    (version "1.0.1")
    (source (local-file "scripts/run-flow.sh"))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((out (assoc-ref %outputs "out"))
               (tmp-dir (string-append out "/tmp"))
               (bin-dir (string-append out "/bin"))
               (script-src (assoc-ref %build-inputs "source"))
               (golden-dir (assoc-ref %build-inputs "golden-model"))
               (rvsim-bin (string-append golden-dir "/riscv_sim_RV64"))
               (test-dir (string-append (assoc-ref %build-inputs "riscv-tests") "/share/riscv-tests/isa"))
               (bash-bin (string-append (assoc-ref %build-inputs "bash") "/bin/bash")))

           (mkdir-p tmp-dir)
           (mkdir-p bin-dir)

           (copy-file script-src (string-append bin-dir "/run-flow"))
           (substitute* (string-append bin-dir "/run-flow")
            (("#!/bin/sh") (string-append "#!" bash-bin)))
           (chmod (string-append bin-dir "/run-flow") #o755)

           ;; golden directory imported with #:recursive? #t preserves execute bits
           (setenv "LD_LIBRARY_PATH" (string-append (assoc-ref %build-inputs "gmp") "/lib:"
                                                   (assoc-ref %build-inputs "zlib") "/lib:"
                                                   (assoc-ref %build-inputs "gcc-toolchain") "/lib"))
           (setenv "PATH" (string-append (assoc-ref %build-inputs "coreutils") "/bin:"
                                        (assoc-ref %build-inputs "grep") "/bin"))
           (setenv "SH" bash-bin)
           (setenv "SIM_NAME" "sail-riscv")
           (setenv "SIM_CMD" (string-append rvsim-bin " -p __TEST__ 2>&1 | grep -q SUCCESS"))
           (setenv "TIMEOUT" "60")
           (setenv "TEST_DIR" test-dir)
           (setenv "OUT_DIR" tmp-dir)
           (invoke (string-append bin-dir "/run-flow"))
           #t))))
    (native-inputs
     `(("golden-model" ,(local-file "golden" "golden" #:recursive? #t))
       ("riscv-tests" ,riscv-tests)
       ("bash" ,bash)
       ("coreutils" ,coreutils)
       ("grep" ,grep)
       ("gcc-toolchain" ,gcc-toolchain)
       ("gmp" ,gmp)
       ("zlib" ,zlib)))
    (synopsis "sail-riscv golden model test flow")
    (description "Runs RISC-V tests on sail-riscv golden model.  Results: $out/tmp/sail-riscv-results.csv")
    (home-page "https://github.com/riscv/sail-riscv")
    (license license:bsd-3)))

(define-public vp-flow
  (package
    (name "vp-flow")
    (version "1.0.1")
    (source (local-file "scripts/run-flow.sh"))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((out (assoc-ref %outputs "out"))
                (tmp-dir (string-append out "/tmp"))
                (bin-dir (string-append out "/bin"))
                (script-src (assoc-ref %build-inputs "source"))
                (vp-bin (string-append (assoc-ref %build-inputs "riscv-vp-plus-plus") "/bin/riscv64-vp"))
                (test-dir (string-append (assoc-ref %build-inputs "riscv-tests") "/share/riscv-tests/isa"))
                (bash-bin (string-append (assoc-ref %build-inputs "bash") "/bin/bash")))

           (mkdir-p tmp-dir)
           (mkdir-p bin-dir)

           (copy-file script-src (string-append bin-dir "/run-flow"))
           (substitute* (string-append bin-dir "/run-flow")
             (("#!/bin/sh") (string-append "#!" bash-bin)))
           (chmod (string-append bin-dir "/run-flow") #o755)

           (setenv "SYSTEMC_DISABLE_COPYRIGHT_MESSAGE" "1")
           (setenv "PATH" (string-append (assoc-ref %build-inputs "coreutils") "/bin"))
           (setenv "SH" bash-bin)
           (setenv "SIM_NAME" "vp")
           (setenv "SIM_CMD" (string-append vp-bin " --intercept-syscalls --error-on-zero-traphandler=false --memory-start 2147483648 --quiet --input-file __TEST__"))
           (setenv "TIMEOUT" "10")
           (setenv "TEST_DIR" test-dir)
           (setenv "OUT_DIR" tmp-dir)
           (invoke (string-append bin-dir "/run-flow"))
           #t))))
    (native-inputs
     (list riscv-vp-plus-plus riscv-tests bash coreutils))
    (synopsis "RISC-V VP++ ISA test flow")
    (description "Runs RISC-V tests on VP++ riscv64-vp.  Results: $out/tmp/vp-results.csv")
    (home-page "https://github.com/ics-jku/riscv-vp-plusplus")
    (license license:expat)))

;;; Simulator flows to verify against the reference model (sail-riscv or spike).
;;; To add a new simulator: define its flow package above, then add
;;; ("sim-name" ,flow-package) here.  Everything else is automatic.
(define simulator-flows
  `(("sail-riscv" ,sail-riscv-flow)
    ("spike" ,spike-flow)
    ("qemu"  ,qemu-flow)
    ("cva6"  ,cva6-flow)
    ("vp"    ,vp-flow)
    ("gem5"  ,gem5-flow)))

;; Metadata spliced into the builder: (("sim-name" . "input-name") ...)
(define (sim-flow-metadata sf)
  (map (lambda (entry)
         (cons (car entry) (string-append (car entry) "-flow")))
       sf))

(define (gen-riscv-test-flows n sf sm)
  (package
    (name n)
    (version "1.0.1")
    (source (local-file "scripts/verify-results.sh"))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((out (assoc-ref %outputs "out"))
               (bin-dir (string-append out "/bin"))
               (script-src (assoc-ref %build-inputs "source"))
               (bash-bin (string-append (assoc-ref %build-inputs "bash") "/bin/bash"))
               (sim-csvs (map (lambda (entry)
                               (string-append (assoc-ref %build-inputs (cdr entry))
                                              "/tmp/" (car entry) "-results.csv"))
                              ',sm)))

           (mkdir-p bin-dir)

           (copy-file script-src (string-append bin-dir "/verify-results"))
           (substitute* (string-append bin-dir "/verify-results")
            (("#!/bin/sh") (string-append "#!" bash-bin)))
           (chmod (string-append bin-dir "/verify-results") #o755)

           (setenv "PATH" (string-append (assoc-ref %build-inputs "coreutils") "/bin:"
                                        (assoc-ref %build-inputs "diffutils") "/bin"))
           (apply invoke (string-append bin-dir "/verify-results")
                  sim-csvs)
           #t))))
    (native-inputs
     (append
       (list bash coreutils diffutils)
       (map cadr sf)))
    (synopsis "Unified RISC-V test verification flow")
    (description
     "Verifies all simulator flows match the golden model (sail-riscv).
Build FAILS if any simulator disagrees with the golden model.
Uses cmp for whole-file comparison.")
    (home-page "https://github.com/imec-CSA")
    (license license:bsd-3)))

; default is to compare to sail-riscv flow results
(define-public riscv-test-flows
 (let* ((sim-flow-meta (sim-flow-metadata simulator-flows)))
    (gen-riscv-test-flows "riscv-test-flows" simulator-flows sim-flow-meta)
  ))

; this is for platforms on which we don't (yet) have golden flow
(define-public riscv-test-flows-silver
 (let* ((simulator-flows (cdr simulator-flows))
        (sim-flow-meta (sim-flow-metadata simulator-flows)))
    (gen-riscv-test-flows "riscv-test-flows-silver" simulator-flows sim-flow-meta)
  ))

;default to golden model reference
riscv-test-flows
