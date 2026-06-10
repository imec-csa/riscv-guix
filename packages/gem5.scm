;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2026 Cayetano Santos <csantosb@inventati.org>
;;; Copyright © 2022-2023 Efraim Flashner <efraim@flashner.co.il>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (packages gem5)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system qt)
  #:use-module (guix build-system scons)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages)
  #:use-module (gnu packages boost)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cpp)
  #:use-module (gnu packages fpga)
  #:use-module (gnu packages engineering)
  #:use-module (gnu packages graphviz)
  #:use-module (gnu packages image)
  #:use-module (gnu packages m4)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages shells))

;;; Strongly based on package gem5 in channel
;; https://git.genenetwork.org/guix-bioinformatics
(define-public gem5
  (package
    (name "gem5")
    (version "25.1.0.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
              (url "https://github.com/gem5/gem5")
              (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0pbckqv08f6yiirr9f6gxivgrk422z31p04fifdhvzyc5magh8ls"))
       (snippet
        #~(begin
            (use-modules (guix build utils))
            ;; For reproducibility.
            (substitute* "src/base/date.cc"
              (("__DATE__") "\"1970-01-01\"")
              (("__TIME__") "\"00:00:00\""))
            ;; TODO: Unbundle systemc, libelf and googletest
            (delete-file-recursively "ext/ply") ;unbundling of python-ply
            ;; Unbundling of pybind11
            (delete-file-recursively "ext/pybind11")
            (substitute* "ext/sst/Makefile.linux"
              (("-I../../ext/pybind11/include/")
               "${shell pybind11-config --includes}"))
            (substitute* "SConstruct"
              ((".*pybind11.*") ""))))))
    (build-system scons-build-system)
    (arguments
     (list
      #:scons-flags #~(list "--verbose")
      #:build-targets #~(list "build/ALL/gem5.opt")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch-source
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute* "SConstruct"
                ;; Force adding missing includes into the environment.
                (("main\\.Append\\(CPPPATH=\\[Dir\\('" all)
                 (string-append
                  all (assoc-ref inputs "capstone") "/include')])\n"
                  all (assoc-ref inputs "hdf5") "/include')])\n"
                  all (assoc-ref inputs "kernel-headers") "/include')])\n"
                  all (assoc-ref inputs "libpng") "/include')])\n"
                  all (assoc-ref inputs "protobuf") "/include')])\n"
                  all (assoc-ref inputs "pybind11") "/include')])\n"
                  all (assoc-ref inputs "zlib") "/include')])\n"
                  all)))
              (substitute* "ext/libelf/SConscript"
                (("m4env\\.Tool" all)
                 (string-append
                  "m4env.Append(CPPPATH=[Dir('"
                  (assoc-ref inputs "kernel-headers")
                  "/include')])\n"
                  all)))
              (substitute* "ext/libelf/native-elf-format"
                (("cc") #$(cc-for-target)))))
          ;; This uses the cached results from the previous 'build phase.
          ;; Move to after 'install and delete build dir first?
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys #:rest args)
              (when tests?
                (apply (assoc-ref %standard-phases 'build)
                       #:build-targets '("build/ALL/unittests.opt")
                       args))))
          (replace 'install
            (lambda _
              (let* ((bin (string-append #$output "/bin/")))
                (mkdir-p bin)
                (install-file "build/ALL/gem5.opt" bin)
                (install-file "build/ALL/gem5py" bin)
                (install-file "build/ALL/gem5py_m5" bin)
                (copy-recursively
                 "configs"
                 (string-append #$output"/share/gem5/configs")))))
          (add-after 'install 'wrap-binaries
            (lambda _
              (for-each
               (lambda (file)
                 (wrap-program file
                   `("GUIX_PYTHONPATH" ":" prefix
                     (,(getenv "GUIX_PYTHONPATH")))))
               (find-files (string-append #$output "/bin"))))))))
    (inputs
     (list capstone
           gperftools
           hdf5
           libpng
           protobuf
           pybind11
           python
           python-ply
           python-pydot
           zlib))
    (native-inputs
     (list boost
           m4
           tcsh
           perl
           python-minimal-wrapper
           pkg-config))
    (home-page "http://gem5.org/")
    (synopsis "Modular platform for computer-system architecture research")
    (description "The gem5 simulator is a modular platform for computer-system
architecture research, encompassing system-level architecture as well as
processor microarchitecture.")
    (license license:bsd-3)))

