;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
(setq user-full-name "Eddie Brunstedt"
      user-mail-address "eddie.brunstedt@protonmail.com")

;;; UI
;; Theme
(setq doom-theme 'doom-ayu-mirage)
;; Font
(setq doom-font (font-spec :family "FiraCode Nerd Font Mono" :size 18)
      doom-big-font (font-spec :family "FiraCode Nerd Font Mono" :size 24)
      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 18))

;; Hide the menu for as minimalistic a startup screen as possible.
(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-shortmenu)
(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-footer)

;;; :editor evil
;; Focus new window after splitting
(setq evil-split-window-below t
      evil-vsplit-window-right t)

;; Org
;; Org root directory
(setq org-directory "~/notes/org/")
;; Roam root directory
(setq org-roam-directory "~/notes/org/org-roam/")
;; Roam rename file on title change
(setq org-roam-rename-file-on-title-change t)

;; Statusbar
(display-time-mode 1)

;; Width of left-hand side fringe
(after! git-gutter-fringe (fringe-mode 20))

;; Code & Language
;; Do not start spell-fu (spelling) by default
(remove-hook! 'text-mode-hook #'spell-fu-mode)
;; Only format TypeScript on save
(add-to-list '+format-on-save-enabled-modes 'typescript-mode t)

(setq rustic-lsp-server 'rust-analyzer)

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

(after! lsp-ui
  (setq lsp-ui-doc-enable nil
        lsp-ui-sideline-enable nil)
  )

;; Breadcrumbs
(setq lsp-headerline-breadcrumb-enable t)
(setq lsp-headerline-breadcrumb-segments '(symbols))
(setq lsp-headerline-breadcrumb-icons-enable t)

;; Code actions icon style
(setq lsp-modeline-code-actions-segments '(count icon name))

;; Use evil-snipe for all windows
(setq avy-all-windows t)

(use-package! topspace
  :custom
  (topspace-active             #'dan/topspace--active-p)
  (topspace-autocenter-buffers #'dan/topspace--active-p)
  (indicate-empty-lines        t)
  :hook
  (doom-first-buffer . global-topspace-mode))

(after! topspace
  (defun dan/topspace--active-p ()
    (not (or (minibufferp)
             (derived-mode-p 'vterm-mode
                             'comint-mode
                             'org-agenda-mode
                             '+doom-dashboard-mode
                             'eshell-mode
                             'magit-mode
                             'telega-root-mode
                             'telega-chat-mode
                             'image-mode
                             'Custom-mode
                             'compilation-mode
                             'elfeed-search-mode
                             'elfeed-show-mode
                             'cfw:calendar-mode
                             'special-mode)))))
