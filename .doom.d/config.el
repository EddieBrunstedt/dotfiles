;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
(setq user-full-name "Eddie Brunstedt"
      user-mail-address "eddie.brunstedt@protonmail.com")

;; Font
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'
(setq doom-font (font-spec :family "Hack Nerd Font" :size 17))

;; Theme
(setq doom-theme 'doom-badger)

;; Org
;; Org root directory
(setq org-directory "~/.org/")
;; Roam root directory
(setq org-roam-directory "~/.org/roam")
;; Roam rename file on title change
(setq org-roam-rename-file-on-title-change t)

;; Statusbar
(display-time-mode 1)

;; Code & Language
;; Do not start spell-fu (spelling) by default
(remove-hook! 'text-mode-hook #'spell-fu-mode)
;; Only format TypeScript on save
(add-to-list '+format-on-save-enabled-modes 'typescript-mode t)

;; Keybindings
;; Mouse thumb buttons for navigating forward/back
(map! :n [mouse-8] #'better-jumper-jump-backward
      :n [mouse-9] #'better-jumper-jump-forward)

;; Elfeed
;; Default filter
(after! elfeed (setq elfeed-search-filter "@2-month-ago +unread"))

;; Ivy
;; Preview buffers from ivy (buffer selection)
(setq +ivy-buffer-preview t)

;; Line numbers
;; t=standard, relative=relative, nil=off
(setq display-line-numbers-type `relative)

;; Abbrev
;; Definitions path
(setq abbrev-file-name "~/.doom.d/.abbrev_defs")

;; Lsp
;; Disable formatting with lsp
(setq +format-with-lsp nil)
;; Find references (`find-defintions per default with "g d")
(define-key evil-normal-state-map (kbd "g f") 'lsp-ui-peek-find-references)
(after! lsp-ui
  ;; Peek: keybindings
  (define-key lsp-ui-peek-mode-map (kbd "j") 'lsp-ui-peek--select-next)
  (define-key lsp-ui-peek-mode-map (kbd "k") 'lsp-ui-peek--select-prev)
  (define-key lsp-ui-peek-mode-map (kbd "C-k") 'lsp-ui-peek--select-prev-file)
  (define-key lsp-ui-peek-mode-map (kbd "C-j") 'lsp-ui-peek--select-next-file)
  ;; Peek: always fontify previewed code
  (setq lsp-ui-peek-fontify 'always
        ;; Peek: window size
        lsp-ui-peek-list-width 60
        lsp-ui-peek-peek-height 25
        lsp-ui-doc-enable t
        ;; Peek: Prevent closing when mouse touches it
        lsp-ui-doc-show-with-mouse t
        lsp-ui-doc-show-with-cursor t
        lsp-ui-doc-include-signature t
        lsp-ui-doc-delay 0.2
        lsp-ui-doc-position 'top
        ;; Doc: pop-up size
        ;; lsp-ui-doc-max-width 100
        ;; lsp-ui-doc-max-height 50
        lsp-ui-imenu-enable t
        lsp-enable-symbol-highlighting t
        ;; UI: Disable inline error messages
        lsp-ui-sideline-enable nil)
  )
