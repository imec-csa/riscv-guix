;;; RISC-V VP++ simulator
;;; Build: guix build -L . riscv-vp-plus-plus
(define-module (packages rv-vp-plus-plus)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages boost))

(define-public riscv-vp-plus-plus
  (let* ((commit "master")
         (version "2025.05"))
    (package
      (name "riscv-vp-plus-plus")
      (version version)
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/ics-jku/riscv-vp-plusplus.git")
               (commit commit)
               (recursive? #t)))
         (file-name (git-file-name name version))
         (sha256 (base32 "18z689gdd43nigmnar7sf214lxq751mj7m18426s6qsvadzwqv9i"))))
      (build-system trivial-build-system)
      (arguments
       `(#:modules ((guix build utils))
         #:builder
         (begin
           (use-modules (guix build utils))
           (let* ((out (assoc-ref %outputs "out"))
                  (bin (string-append out "/bin"))
                  (source (assoc-ref %build-inputs "source"))
                  (cmake-bin (string-append (assoc-ref %build-inputs "cmake") "/bin/cmake"))
                  (input-dirs (map cdr %build-inputs))
                  ;; Collect all include and lib directories from inputs
                  (include-dirs (string-join
                                 (filter file-exists?
                                         (map (lambda (d) (string-append d "/include"))
                                              input-dirs))
                                 ":"))
                  (lib-dirs (string-join
                              (filter file-exists?
                                      (map (lambda (d) (string-append d "/lib"))
                                           input-dirs))
                              ":")))

             (setenv "PATH"
                     (string-join
                      (map (lambda (input)
                             (string-append (cdr input) "/bin"))
                           %build-inputs)
                      ":"))

             ;; Expose all input headers and libraries so cmake and the
             ;; compiler can find boost, nlohmann-json, libvnc, etc.
             (setenv "C_INCLUDE_PATH" include-dirs)
             (setenv "CPLUS_INCLUDE_PATH" include-dirs)
             (setenv "LIBRARY_PATH" lib-dirs)
             (setenv "CMAKE_PREFIX_PATH"
                     (string-join input-dirs ":"))

             (copy-recursively source "source")
             (mkdir-p bin)

             ;; Configure: cmake points at vp/ subdirectory, SystemC is bundled
             (invoke cmake-bin "-S" "source/vp" "-B" "build"
                     (string-append "-DCMAKE_INSTALL_PREFIX=" out)
                     "-DCMAKE_BUILD_TYPE=Release"
                     "-DUSE_SYSTEM_SYSTEMC=OFF")

             ;; Build
             (invoke cmake-bin "--build" "build" "--parallel")

             ;; Install: find and copy VP binaries
             (let ((copied 0))
               (with-directory-excursion "build"
                 ;; Newer versions put binaries under build/bin/
                 (for-each
                  (lambda (f)
                    (when (and (file-exists? f) (executable-file? f))
                      (install-file f bin)
                      (set! copied (+ copied 1))))
                  (find-files "bin" ".*" #:directories? #f #:fail-on-error? #f))
                 ;; Older versions scatter them under build/src/
                 (when (= copied 0)
                   (for-each
                    (lambda (f)
                      (when (executable-file? f)
                        (install-file f bin)
                        (set! copied (+ copied 1))))
                    (append
                     (find-files "src" ".*-vp$" #:fail-on-error? #f)
                     (find-files "src" "linux.*-vp$" #:fail-on-error? #f))))
                 (when (= copied 0)
                   (error "no VP binaries found to install!"))))
             #t))))
      (inputs
       (list
        boost
        git
        cmake
        pkg-config
        (specification->package "make")
        (specification->package "gcc-toolchain")
        (specification->package "libvnc")
        (specification->package "nlohmann-json")
        (specification->package "qtbase")
        (specification->package "zlib")))
      (home-page "https://github.com/ics-jku/riscv-vp-plusplus")
      (synopsis "RISC-V VP++ virtual prototype simulator")
      (description
       "RISC-V VP++ is an extended and improved successor of the RISC-V based
Virtual Prototype (VP).  It provides RV32 and RV64 virtual platforms including
riscv32-vp, tiny32-vp, and linux32-vp.  Maintained at the Institute for Complex
Systems, Johannes Kepler University, Linz.")
      (license license:expat))))
