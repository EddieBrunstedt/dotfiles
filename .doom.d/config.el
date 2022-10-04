;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
(setq user-full-name "Eddie Brunstedt"
      user-mail-address "eddie.brunstedt@protonmail.com")

;;; UI
;; Theme
(setq doom-theme 'doom-dracula)
;; Font
(setq doom-font (font-spec :family "FiraCode Nerd Font Mono" :size 17)
      doom-big-font (font-spec :family "FiraCode Nerd Font Mono" :size 24)
      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 17))

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

;; Org html export theme
(setq org-html-head "
<style>body{background:#18181b; color:#d4d4d8;}</style>
<style>h2{color:#f47878;;}</style>
<style>h3{color:#8cdbd2;}</style>
<style>h4{color:#ff7474;}</style>
<style>a{color:#60a5fa; text-decoration-line: none;}</style>
<style>a:hover{text-decoration-line: underline;}</style>
<style>code{color:#fdba74;}</style>
<style>pre{background:#27272a; color:#d4d4d8; border: 1px solid #3f3f46; margin: 0.5rem; font-size: 0.9rem;}</style>
<style>#content{max-width:1024px;}</style>
<style>#text-table-of-contents{border-bottom:1px solid white; margin-bottom: 1rem; border-color: rgb(113 113 122);}</style>
<style>.org-src-name{font-size: 0.875rem; line-height: 1.25rem;}</style>
<style>#postamble{margin-top: 3rem;}</style>
")
