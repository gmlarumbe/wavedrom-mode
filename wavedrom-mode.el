;;; wavedrom-mode.el --- WaveDrom Integration  -*- lexical-binding: t -*-

;; Copyright (C) 2022-2025 Gonzalo Larumbe

;; Author: Gonzalo Larumbe <gonzalomlarumbe@gmail.com>
;; URL: https://github.com/gmlarumbe/wavedrom-mode
;; Version: 0.1.1
;; Keywords: FPGA, ASIC, Tools
;; Package-Requires: ((emacs "29.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Major-mode for editing and rendering WaveJSON files to create timing diagrams
;; using wavedrom:
;;  - https://wavedrom.com/
;;
;; Requirements:
;;  - `wavedrom-cli': https://github.com/wavedrom/cli
;;  - Optional: `inkscape' to export to PDF
;;
;; Usage:
;; - Create a file with .wjson extension and `wavedrom-mode' will automatically
;;   be enabled next time it is opened.
;; - Fill the file with valid WaveJSON syntax and every time it gets saved the
;;   function `wavedrom-compile' will be run, updating the output file and its
;;   associated buffer.
;; - The output file path will be determined from the value of customizable
;;   variables `wavedrom-output-format' and `wavedrom-output-directory'.
;;
;; Keybindings:
;;  - C-c C-c `wavedrom-compile'
;;  - C-c C-p `wavedrom-preview-browser'
;;
;; Some WaveDrom documentation and tutorials:
;;  - https://wavedrom.com/tutorial.html (timing diagram)
;;  - https://wavedrom.com/tutorial2.html (schematic)
;;  - https://github.com/wavedrom/schema/blob/master/WaveJSON.md

;;; Code:

(require 'js)


;;;; Custom
(defgroup wavedrom nil
  "WaveDrom customization."
  :group 'tools)

(defcustom wavedrom-executable (executable-find "wavedrom-cli")
  "Executable path of wavedrom-cli."
  :group 'wavedrom
  :type 'file)

(defcustom wavedrom-inkscape-executable (executable-find "inkscape")
  "Executable path of inkscape for exporting to PDF."
  :group 'wavedrom
  :type 'file)

(defcustom wavedrom-output-format "svg"
  "Output format for generated timing diagram.

It must be of type string without a dot."
  :group 'wavedrom
  :type '(choice (const :tag "SVG" "svg")
                 (const :tag "PNG" "png")
                 (const :tag "PDF" "pdf")))

(defcustom wavedrom-output-directory nil
  "Directory where rendered files will be saved to.

If set to nil, default to same directory as current WaveJSON file."
  :group 'wavedrom
  :type 'directory)


;;;; Font-lock
(defvar wavedrom-font-lock-punctuation-face 'wavedrom-font-lock-punctuation-face)
(defface wavedrom-font-lock-punctuation-face
  '((t (:inherit font-lock-punctuation-face)))
  "Face for punctuation."
  :group 'wavedrom)

(defvar wavedrom-font-lock-brackets-face 'wavedrom-font-lock-brackets-face)
(defface wavedrom-font-lock-brackets-face
  '((t (:inherit font-lock-bracket-face)))
  "Face for brackets."
  :group 'wavedrom)

(defconst wavedrom-keywords '("signal" "edge" "config" "head" "foot" "assign"))
(defconst wavedrom-keywords-signal-attributes '("name" "wave" "data" "period" "phase" "node"))
(defconst wavedrom-keywords-config-attributes '("hscale" "skin")) ;; Two skins: default and narrow
(defconst wavedrom-keywords-head-foot-attributes '("tick" "tock" "text" "every"))
(defconst wavedrom-brackets '("[" "]" "{" "}"))
(defconst wavedrom-punctuation '("'" "," ":"))

(defconst wavedrom-keywords-re (regexp-opt wavedrom-keywords 'symbols))
(defconst wavedrom-keywords-signal-attributes-re (regexp-opt wavedrom-keywords-signal-attributes 'symbols))
(defconst wavedrom-keywords-config-attributes-re (regexp-opt wavedrom-keywords-config-attributes 'symbols))
(defconst wavedrom-keywords-head-foot-attributes-re (regexp-opt wavedrom-keywords-head-foot-attributes 'symbols))
(defconst wavedrom-brackets-re (regexp-opt wavedrom-brackets))
(defconst wavedrom-punctuation-re (regexp-opt wavedrom-punctuation))

(defvar wavedrom-font-lock-defaults
  `(((,wavedrom-keywords-re . font-lock-keyword-face)
     (,wavedrom-keywords-signal-attributes-re . font-lock-variable-name-face)
     (,wavedrom-keywords-config-attributes-re . font-lock-variable-name-face)
     (,wavedrom-keywords-head-foot-attributes-re . font-lock-variable-name-face)
     (,wavedrom-brackets-re . wavedrom-font-lock-brackets-face)
     (,wavedrom-punctuation-re . wavedrom-font-lock-punctuation-face)))
  "Font lock defaults for WaveDrom.")


;;;; Functions
(defun wavedrom-output-file ()
  "Return name of rendered output file.

It will depend on `wavedrom-output-format' and `wavedrom-output-directory'."
  (file-name-concat wavedrom-output-directory
                    (concat (file-name-sans-extension (buffer-name)) "." wavedrom-output-format)))

(defun wavedrom-command-args ()
  "Return wavedrom-cli command arguments depending on selected output format."
  (let ((filename (concat "\"" buffer-file-name "\"")))
    (pcase wavedrom-output-format
      ("svg" `("-i" ,filename "-s" ,(wavedrom-output-file)))
      ("png" `("-i" ,filename "-p" ,(wavedrom-output-file)))
      ("pdf" `("-i" ,filename "|" ,wavedrom-inkscape-executable "-p" ,(concat "--export-filename=" (wavedrom-output-file))))
      (_ nil))))

(defun wavedrom-completion-at-point ()
  "Simple `completion-at-point' function."
  (let* ((bds (bounds-of-thing-at-point 'symbol))
         (start (car bds))
         (end (cdr bds))
         candidates)
    (setq candidates (remove (thing-at-point 'symbol :no-props)
                             (append wavedrom-keywords
                                     wavedrom-keywords-signal-attributes
                                     wavedrom-keywords-config-attributes
                                     wavedrom-keywords-head-foot-attributes)))
    (list start end candidates . nil)))

(defun wavedrom-checks ()
  "Check customizable variables and environment."
  (unless buffer-file-name
    (error "Buffer needs to be visiting a file.  Run first `save-buffer` with `C-x C-s'"))
  (unless (member wavedrom-output-format '("svg" "png" "pdf"))
    (error "Output format not supported: %s" wavedrom-output-format))
  (unless wavedrom-executable
    (error "`wavedrom-cli' binary not found"))
  (when (string= wavedrom-output-format "pdf")
    (unless wavedrom-inkscape-executable
      (error "`inkscape' binary not found on PATH, required to export to PDF")))
  (when (and wavedrom-output-directory
             (file-exists-p wavedrom-output-directory))
    (unless (file-directory-p wavedrom-output-directory)
      (error "Selected `wavedrom-output-directory': %s is not a directory" wavedrom-output-directory))))

(defun wavedrom-compile ()
  "Generate timing diagram using WaveDrom."
  (interactive)
  (wavedrom-checks)
  (let ((buf (concat "*wavedrom-cli*"))
        (buf-err (concat "*wavedrom-cli-err*"))
        (cmd (concat wavedrom-executable " " (mapconcat #'identity (wavedrom-command-args) " "))))
    (message "Compiling wavedrom...")
    ;; Setup output directory
    (when wavedrom-output-directory
      (unless (and (file-exists-p wavedrom-output-directory)
                   (file-directory-p wavedrom-output-directory))
        (make-directory wavedrom-output-directory :parents)))
    ;; Clear error buffer before running command
    (with-current-buffer (get-buffer-create buf-err)
      (erase-buffer))
    ;; Run command and check for errors
    (shell-command cmd buf buf-err)
    (unless (eq 0 (buffer-size (get-buffer buf-err)))
      (message "There were some errors. Check buffer %s" buf-err))
    ;; Pop to buffer after rendering
    (unless (get-file-buffer (wavedrom-output-file))
      (find-file-other-window (wavedrom-output-file)))
    ;; Make sure it's autoupdated when rendered file is opened externally (e.g. via `dired')
    (with-current-buffer (get-file-buffer (wavedrom-output-file))
      (auto-revert-mode))))

(defun wavedrom-preview-browser ()
  "Open rendered image in default browser."
  (interactive)
  (browse-url-of-file (wavedrom-output-file)))

;;;; Major-mode
(defvar wavedrom-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") 'wavedrom-compile)
    (define-key map (kbd "C-c C-p") 'wavedrom-preview-browser)
    map))

;;;###autoload
(define-derived-mode wavedrom-mode js-json-mode "WaveDrom"
  "Major mode for editing WaveDrom files and generate output."
  (setq-local font-lock-defaults wavedrom-font-lock-defaults)
  (add-hook 'after-save-hook #'wavedrom-compile nil :local)
  (add-hook 'completion-at-point-functions #'wavedrom-completion-at-point nil 'local))

;;;###autoload
(add-to-list 'auto-mode-alist (cons "\\.wjson\\'" 'wavedrom-mode))



(provide 'wavedrom-mode)

;;; wavedrom-mode.el ends here
