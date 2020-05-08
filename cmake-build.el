;;; cmake-build.el --- Calling CMake with transient buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2020 Miquel Sabaté Solà <mikisabate@gmail.com>
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; Author: Miquel Sabaté Solà <mikisabate@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1") (s "1.12.0") (transient "0.2.0"))
;; Keywords: processes, tools
;; URL: https://github.com/mssola/cmake-build

;;; Commentary:
;;
;; Calling CMake is actually not that hard, but there are some flags that keeps
;; repeating from project to project.  With `cmake-build' you will be able to
;; call CMake from within GNU Emacs.  This can be done with the interactive
;; function `cmake-build', which will open up a transient buffer (a la Magit)
;; with the options you want to use.
;;
;; `cmake-build' will save the options being used in a file used as a cache
;; inside of the `cmake-build-directory' directory.  These cached options are
;; going to be used every time you fire up the transient buffer.  Moreover, this
;; cache also allows us to implement `cmake-build-from-cache', which will
;; directly call CMake with the cached values, or call `cmake-build' if the
;; cache is not available yet.  Thus, it's recommended to use
;; `cmake-build-from-cache' if you only want to call CMake for your project,
;; since it will do the expected thing always.
;;
;; Other than that, you can set some customization variables in order to direct
;; how `cmake-build' should act on the first run.

;;; Credits:
;;
;; This package is possible thanks to Magit and its `transient'
;; (https://github.com/magit/transient) package, which allows us to have useful
;; buffers for toggling options on the fly.  There are parts from this package
;; that have been copied from magit's code.

;;; Code:

(require 's)
(require 'transient)

;;; TODO: defcustom instead?

(defvar cmake-build-directory "build"
  "TODO.")

(defvar cmake-build-export-commands t
  "TODO.")

(defvar cmake-build-generator nil
  "TODO.")

(defvar cmake-build-guess-generator t
  "TODO.")

(defvar cmake-build-type nil
  "TODO.")

(defconst cmake-build-cache-file "cmake-build.txt"
  "TODO.")

(define-transient-command cmake-build ()
  "Show build options for cmake."
  :man-page "cmake"
  :value #'cmake-build--initial-value
  ["Options"
   (cmake-build:-G)
   ]
  ["Variables"
   ("e" "Export compile commands" "-DCMAKE_EXPORT_COMPILE_COMMANDS=1")
   (cmake-build:p)
   ("t" "Build type" "-DCMAKE_BUILD_TYPE=" read-string)
   (cmake-build:-D)
   ]
  ["Actions"
   [("b" "Build" cmake-build--build)
    ("c" "Clear" cmake-build--clear)
    ]
   ])

(defun cmake-build-from-cache ()
  "TODO."

  (interactive)

  (if (file-exists-p (cmake-build--cache-file))
      (cmake-build--do-build (cmake-build--initial-value-from-cache) t)
    (cmake-build)))

(defun cmake-build--cache-file ()
  "TODO."

  (expand-file-name
   (concat cmake-build-directory "/" cmake-build-cache-file)
   (cmake-build--project-root)))

(defun cmake-build--initial-value ()
  "TODO."

  (if (file-exists-p (cmake-build--cache-file))
      (cmake-build--initial-value-from-cache)
    (cmake-build--initial-value-from-vars)))

(defun cmake-build--guess-generator ()
  "TODO."

  (let ((build-directory (expand-file-name
                          cmake-build-directory
                          (cmake-build--project-root))))
    (if (file-directory-p build-directory)
        (if (file-exists-p (expand-file-name "build.ninja" build-directory))
            "Ninja"
          "Unix Makefiles")
      nil)))

(defun cmake-build--initial-value-from-cache ()
  "TODO."

  (with-temp-buffer
    (insert-file-contents (cmake-build--cache-file))
    (read (current-buffer))))

(defun cmake-build--initial-value-from-vars ()
  "TODO."

  (let ((ret '()))
    ;; Check if we should export CMake commands.
    (when cmake-build-export-commands
      (push "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" ret))

    ;; If `cmake-build-generator' is set to a non-empty string, set it directly
    ;; into the CMake variable. If this is not the case and the user let us
    ;; guess the build system, let's try it now.
    (if (s-blank-str? cmake-build-generator)
        (when cmake-build-guess-generator
          (let ((guessed (cmake-build--guess-generator)))
            (unless (s-blank-str? guessed)
              (push (format "-G %s" guessed) ret))))
      (push (format "-G %s" cmake-build-generator) ret))

    ;; Check if a build type was specified
    (unless (s-blank-str? cmake-build-type)
      (push (format "-DCMAKE_BUILD_TYPE=%s" cmake-build-type) ret))

    ret))

(define-infix-argument cmake-build:-D ()
  :description "Specify custom CMake variables"
  :class 'transient-option
  :key "-D"
  :argument "-E"
  :reader 'cmake-build-directory-reader)

(define-infix-argument cmake-build:-G ()
  :description "Specify a build system generator"
  :class 'transient-option
  :key "-G"
  :argument "-G"
  :reader 'cmake-build-generator)

(define-infix-argument cmake-build:p ()
  :description "Install prefix"
  :class 'transient-option
  :key "p"
  :argument "-DCMAKE_INSTALL_PREFIX="
  :reader 'cmake-build-directory-reader)

(defun cmake-build-directory-reader (&rest _ignored)
  "TODO."

  (read-directory-name "Install prefix directory: " "/"))

(defun cmake-build-generator (&rest _ignored)
  "TODO."

  ;; TODO: where does magit-read-char-case come from?
  (magit-read-char-case "Build generator " t
    (?u "[U]nix Makefiles" " Unix Makefiles")
    (?n "[n]inja" " Ninja")
    (?w "[W]atcom WMake" " Watcom WMake")))

(defun cmake-build-arguments nil
  (transient-args 'cmake-build))

(defun cmake-build--project-root ()
  "TODO."

  ;; TODO: error out when not in a project
  ;; TODO: integration with projectile

  (let ((dir (expand-file-name "."))
        (home (getenv "HOME"))
        (ret nil))
    (while (not (string= dir home))
      (when (file-exists-p (expand-file-name "CMakeLists.txt" dir))
        (setq ret dir))
      (setq dir (expand-file-name ".." dir)))
    ret))

(defun cmake-build--build (&optional args)
  "TODO."

  ;; TODO: sort this out...
  (interactive (list (cmake-build-arguments)))

  (cmake-build--ensure-environment)
  (cmake-build--do-build (transient-args 'cmake-build)))

(defun cmake-build--do-build (args &optional avoid-cache)
  "TODO."

  (let ((default-directory (expand-file-name cmake-build-directory (cmake-build--project-root)))
        (cmake-command (concat
                        "cmake "
                        ".. "
                        (s-join " " args))))
    (unless avoid-cache
      (cmake-build--save-cache args))
    (compile cmake-command)))

(defun cmake-build--clear ()
  "TODO."

  (interactive)

  (let ((default-directory (cmake-build--project-root)))
    (delete-directory cmake-build-directory t))
  )

(defun cmake-build--save-cache (args)
  "TODO."

  (with-temp-file (cmake-build--cache-file)
    (prin1 args (current-buffer))))

(defun cmake-build--ensure-environment ()
  "TODO."

  (let ((default-directory (cmake-build--project-root)))
    (unless (file-directory-p cmake-build-directory)
      (make-directory cmake-build-directory))))

(provide 'cmake-build)

;;; cmake-build.el ends here
