;;; RISC-V bare-metal cross-compiler toolchain

(define-module (packages riscv-toolchain)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages gcc)
  #:export (riscv64-elf-toolchain
            cross-binutils-riscv64-elf
            cross-gcc-riscv64-elf))

;; Define the target triplet for bare-metal RISC-V
(define %riscv64-elf-target "riscv64-elf")

;; Cross binutils for riscv64-elf
(define-public cross-binutils-riscv64-elf
  (cross-binutils %riscv64-elf-target))

;; Cross GCC (sans libc) for riscv64-elf - bare-metal doesn't need libc
(define-public cross-gcc-riscv64-elf
  (cross-gcc %riscv64-elf-target
             #:xbinutils cross-binutils-riscv64-elf))

;; Complete toolchain package
(define-public riscv64-elf-toolchain
  (package
    (name "riscv64-elf-toolchain")
    (version (package-version cross-gcc-riscv64-elf))
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list #:modules '((guix build union))
           #:builder
           #~(begin
               (use-modules (ice-9 match)
                            (guix build union))
               (match %build-inputs
                 (((names . directories) ...)
                  (union-build #$output directories))))))
    (inputs (list cross-binutils-riscv64-elf
                  cross-gcc-riscv64-elf))
    (native-search-paths
     (list (search-path-specification
            (variable "PATH")
            (files '("bin")))))
    (home-page "https://gcc.gnu.org/")
    (synopsis "RISC-V bare-metal cross-compiler toolchain")
    (description
     "Complete GCC cross-compilation toolchain for building bare-metal
RISC-V binaries.  Provides riscv64-elf-gcc, riscv64-elf-as, riscv64-elf-ld,
and other tools needed to build riscv-tests and other bare-metal programs.

This is a 'sans-libc' toolchain - it does not include a C library, which is
appropriate for bare-metal development where you provide your own runtime.")
    (license license:gpl3+)))

;; Export for use
riscv64-elf-toolchain
