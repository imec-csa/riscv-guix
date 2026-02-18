(define-module (packages riscv-pk-cva6)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:export (riscv-pk-cva6))

(define-public riscv-pk-cva6
  (package
    (name "riscv-pk-cva6")
    (version "1.0.0")
    (source (local-file "../pk"))  ; Use the pre-built pk binary from the repository
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((out (assoc-ref %outputs "out"))
                (bin (string-append out "/bin"))
                (source (assoc-ref %build-inputs "source")))
           (mkdir-p bin)
           (copy-file source (string-append bin "/pk"))
           (chmod (string-append bin "/pk") #o755)
           #t))))
    (synopsis "RISC-V Proxy Kernel (pre-built for CVA6)")
    (description
     "The RISC-V Proxy Kernel, pk, is a lightweight application execution
environment that can host statically-linked RISC-V ELF binaries.  This package
provides a pre-built binary that works with CVA6 simulation flows.")
    (home-page "https://github.com/riscv-software-src/riscv-pk")
    (license license:bsd-3)))

;; Return the package when file is loaded directly with -f
riscv-pk-cva6
