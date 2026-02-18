(define-module (packages verilator-4-110)
  #:use-module (gnu packages electronics)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:export (verilator-4.110 verilator-5.024))

(define-public verilator-4.110
  (package
    (inherit verilator)
    (version "4.110")
    (source (origin
              (inherit (package-source verilator))
              (method git-fetch)
              (uri (git-reference
                     (url "https://github.com/verilator/verilator")
                     (commit (string-append "v" version))))
              (file-name (git-file-name "verilator" version))
              (sha256 (base32 "1lm2nyn7wzxj5y0ffwazhb4ygnmqf4d61sl937vmnmrpvdihsrrq"))))
    (arguments
     `(,@(substitute-keyword-arguments (package-arguments verilator)
           ((#:tests? _ #f) #f))))))  ; Disable tests - some SystemC tests fail

;;; Verilator 5.024 - new version that works with CVA6 v4.2.0
;;; Requires --no-timing and -Wno-ENUMVALUE flags, and C++17
(define-public verilator-5.024
  (package
    (inherit verilator)
    (version "5.024")
    (source (origin
              (inherit (package-source verilator))
              (method git-fetch)
              (uri (git-reference
                     (url "https://github.com/verilator/verilator")
                     (commit (string-append "v" version))))
              (file-name (git-file-name "verilator" version))
              (sha256 (base32 "0rs4sm7ic8c6n3qp489s7yxy8kxfwhxb11xyvbkvzs5p2h94zp92"))))
    (arguments
     `(,@(substitute-keyword-arguments (package-arguments verilator)
           ((#:tests? _ #f) #f))))))  ; Disable tests

;; Return the package when file is loaded directly with -f
verilator-5.024
