;;; eglot-lsp-settings.el --- Auto install Language-Server powered by vim-lsp-settings  -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Naoya Yamashita

;; Author: Naoya Yamashita <conao3@gmail.com>
;; Version: 0.0.1
;; Keywords: convenience
;; Package-Requires: ((emacs "26.1"))
;; URL: https://github.com/conao3/eglot-lsp-settings.el

;; This program is free software: you can redistribute it and/or modify
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

;; Auto install Language-Server powered by vim-lsp-settings.


;;; Code:

(require 'json)
(require 'eshell)
(require 'esh-mode)                     ; eshell-interactive-filter

(defgroup eglot-lsp-settings nil
  "Auto install Language-Server powered by vim-lsp-settings."
  :group 'convenience
  :link '(url-link :tag "Github" "https://github.com/conao3/eglot-lsp-settings.el"))

(defcustom eglot-lsp-settings-dir (locate-user-emacs-file "eglot-lsp-settings")
  "Directory for `eglot-lsp-settings'."
  :group 'eglot-lsp-settings
  :type 'directory)

(defcustom eglot-lsp-settings-vim-lsp-settings-dir
  (expand-file-name "vim-lsp-settings" eglot-lsp-settings-dir)
  "Directory vim-lsp-settings cloning into."
  :group 'eglot-lsp-settings
  :type 'directory)

(defcustom eglot-lsp-settings-buffer-name "*eglot-lsp-settings*"
  "Buffer name for `eglot-lsp-settings'."
  :group 'eglot-lsp-settings
  :type 'string)

(defvar eglot-lsp-settings-process nil
  "Process for `eglot-lsp-settings'.")

(defun eglot-lsp-settings--plist-kv (plist)
  "PLIST for map function."
  (seq-partition plist 2))

(defun eglot-lsp-settings--split-name (name)
  "Convert NAME into (filetype . command)."
  (let ((strs (split-string name "/")))
    (cons (car strs) (string-join (cdr strs) "_"))))

(defun eglot-lsp-settings--shell-script-ext ()
  "Return shell script extention."
  (if (string= system-type "windows-nt")
      "cmd"
    "sh"))

(defun eglot-lsp-settings--ensure-buffer ()
  "Create `eglot-lsp-settings' buffer."
  (let ((initializep (not (get-buffer eglot-lsp-settings-buffer-name)))
        (buf (get-buffer-create eglot-lsp-settings-buffer-name)))
    (when initializep
      (with-current-buffer buf
        (fundamental-mode)))            ; TODO: create `eglot-lsp-settings-message-mode'
    buf))

(defun eglot-lsp-settings--display-buffer ()
  "Display `eglot-lsp-settings' buffer."
  (display-buffer (eglot-lsp-settings--ensure-buffer)))

(defun eglot-lsp-settings--auto-scroll-buffer ()
  "Autoscroll to bottom."
  (let ((buf (eglot-lsp-settings--ensure-buffer)))
    (dolist (win (get-buffer-window-list buf nil 'all-frame))
      (with-selected-window win
        (goto-char (point-max))))))

(defun eglot-lsp-settings--ensure-dir (dir)
  "Make direcory DIR if not exists."
  (let ((dir* (expand-file-name dir)))
    (unless (file-directory-p dir*)
     (make-directory dir* 'parent))
    dir*))

(defun eglot-lsp-settings--expand-file-name (paths)
  "Expand PATHS based `eglot-lsp-settings' dir."
  (cl-reduce (lambda (prev cur) (expand-file-name cur prev))
             (cons eglot-lsp-settings-dir paths)))

(defun eglot-lsp-settings--assert-command (command)
  "Check COMMAND in variable `exec-path'."
  (or (executable-find command)
      (error (format "Missing `%s'" command))))

(defun eglot-lsp-settings--initialize-buffer ()
  "Initialize `eglot-lsp-settings' buffer to run new command."
  (with-current-buffer (eglot-lsp-settings--ensure-buffer)
    (save-excursion
      (goto-char (point-max))
      (set (make-local-variable 'eshell-last-input-start) (point-marker))
      (set (make-local-variable 'eshell-last-input-end) (point-marker))
      (set (make-local-variable 'eshell-last-output-start) (point-marker))
      (set (make-local-variable 'eshell-last-output-end) (point-marker))
      (set (make-local-variable 'eshell-last-output-block-begin) (point)))))

(defun eglot-lsp-settings--make-process (command)
  "Run COMMAND at eglot-lsp-settings buffer."
  (eglot-lsp-settings--ensure-dir eglot-lsp-settings-dir)
  (eglot-lsp-settings--display-buffer)
  (eglot-lsp-settings--initialize-buffer)
  (when (process-live-p eglot-lsp-settings-process)
    (error "Process is now running"))
  (setq eglot-lsp-settings-process
        (make-process
         :name "eglot-lsp-settings"
         :buffer eglot-lsp-settings-buffer-name
         :command command
         :filter (lambda (proc string)
                   (eshell-interactive-process-filter proc string)
                   (eglot-lsp-settings--auto-scroll-buffer))
         :sentinel (lambda (proc event)
                     (with-current-buffer eglot-lsp-settings-buffer-name
                       (save-excursion
                         (goto-char (point-max))
                         (insert (format "\nProcess %s %s" proc event))))
                     (eglot-lsp-settings--auto-scroll-buffer)))))

(defun eglot-lsp-settings--ensure-vim-lsp-settings ()
  "Initialize dependency."
  (eglot-lsp-settings--assert-command "git")
  (let ((default-directory eglot-lsp-settings-dir))
    (eglot-lsp-settings--make-process
     '("git" "clone" "https://github.com/mattn/vim-lsp-settings.git"))))

(defvar eglot-lsp-settings--load-settings--cached nil)
(defun eglot-lsp-settings--load-settings ()
  "Load vim-lsp-settings settings.json."
  (or eglot-lsp-settings--load-settings--cached
      (setq eglot-lsp-settings--load-settings--cached
            (let ((obj (let ((json-object-type 'plist)
                             (json-array-type 'list)
                             (json-key-type 'keyword))
                         (json-read-file
                          (eglot-lsp-settings--expand-file-name '("vim-lsp-settings" "settings.json"))))))
              (mapcan (lambda (elm)
                        (let ((key (car elm))
                              (val (cadr elm)))
                          (when (listp val)
                            (mapcan (lambda (e)
                                      (list
                                       (intern (format "%s/%s" key (plist-get e :command)))
                                       e))
                                    val))))
                      (eglot-lsp-settings--plist-kv obj))))))

(defun eglot-lsp-settings-install-server (name)
  "Install NAME server."
  (interactive (list (completing-read
                      "Server: "
                      (mapcar (lambda (elm) (substring (symbol-name (car elm)) 1))
                              (eglot-lsp-settings--plist-kv
                               (eglot-lsp-settings--load-settings))))))
  (let* ((stem (eglot-lsp-settings--split-name name))
         (default-directory (eglot-lsp-settings--expand-file-name
                             (list "server"
                                   (format "%s_%s" (car stem) (cdr stem)))))
         (script-path (eglot-lsp-settings--expand-file-name
                       (list "vim-lsp-settings"
                             "installer"
                             (format "install-%s.%s"
                                     (cdr stem)
                                     (eglot-lsp-settings--shell-script-ext))))))
    (when (file-directory-p default-directory)
      (error "%s is already installed" name))
    (eglot-lsp-settings--ensure-dir default-directory)
    (eglot-lsp-settings--make-process (list script-path))))

(provide 'eglot-lsp-settings)

;;; eglot-lsp-settings.el ends here
