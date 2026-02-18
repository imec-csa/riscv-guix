;;; This module provides shared dependencies for CVA6 flows

(define-module (packages cva6-modules)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages commencement)  ; For gcc-toolchain
  #:use-module (gnu packages virtualization)  ; For spike
  #:use-module (guix utils)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages cross-base)
  #:use-module (packages verilator-4-110)
  #:export (cva6-source)
  #:re-export (verilator-4.110 spike gcc-toolchain))  ; Re-export from other modules

;;; CVA6 Source - Common source for all CVA6 flows
;;; Using openhwgroup/cva6 v4.2.0 - verified to work with Verilator 4.110
;;; Note: Latest CVA6 (master) requires Verilator 5.x which has segfault issues.
(define-public cva6-source
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
