;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
(setq user-full-name "Eddie Brunstedt"
      user-mail-address "eddie.brunstedt@protonmail.com")

;;; UI
;; Theme settings
(setq
 modus-themes-bold-constructs t
 modus-themes-org-blocks 'gray-background
 modus-themes-completions 'opinionated
 modus-themes-italic-constructs t
 modus-themes-mode-line 'borderless
 modus-themes-paren-match '(bold intense)
 modus-themes-prompts '(bold intense)
 modus-themes-region 'bg-only
 modus-themes-scale-headings t
 modus-themes-headings
 '((1 . (rainbow overline 1.3))
   (2 . (rainbow 1.2))
   (3 . (rainbow bold 1.1))
   (4 . (semilight 1))))

;; Set theme
(setq doom-theme 'modus-vivendi)

;; Font
(setq doom-font (font-spec :family "Iosevka Nerd Font Mono" :weight 'semibold :size 22)
      doom-big-font (font-spec :family "Iosevka Nerd Font Mono" :weight 'semibold  :size 26)
      doom-variable-pitch-font (font-spec :family "Iosevka Nerd Font Mono" :weight 'semibold  :size 19))

;; org-agenda
(after! org-agenda (setq org-agenda-span 31))

;; log done time in org
(setq org-log-done 'time)

;; Treat "_" as part of a word.
(modify-syntax-entry ?_ "w")

;; Hide the menu for as minimalistic a startup screen as possible.
(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-shortmenu)
(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-footer)

;;; :editor evil
;; Focus new window after splitting
;; (setq evil-split-window-below t
;;       evil-vsplit-window-right t)

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

(setq lsp-rust-analyzer-server-display-inlay-hints t)

;; Keybindings
;; Mouse thumb buttons for navigating forward/back
(map! :n [mouse-8] #'better-jumper-jump-backward
      :n [mouse-9] #'better-jumper-jump-forward)

;; Elfeed
;; Default filter
(after! elfeed (setq elfeed-search-filter "@2-month-ago +unread"))

(setq my/bare-repos
      '(("~/" . "~/.cfg")))

(defun my/magit-bare-repo-env (env)
  "Detect and set the git command environment ENV for a bare repo.
If a file is not inside a normal git repo, check it against a
configured list or bare repository work directories. If it's
under one, associate the file to the configured bare repo by
setting the GIT_DIR and GIT_WORK_TREE environment variables
before running a git command for Magit.
See https://github.com/magit/magit/issues/460."
  (unless (vc-call-backend 'Git 'root default-directory)
    (let* ((bare-pair (seq-some
                       (lambda (p)
                         (if (file-in-directory-p default-directory
                                                  (car p))
                             p))
                       my/bare-repos))
           (workdir (car bare-pair))
           (bare-repo (cdr bare-pair)))
      (when bare-pair
        (message "Bare repo, adding to env")
        (push (format "GIT_WORK_TREE=%s" (expand-file-name workdir)) env)
        (push (format "GIT_DIR=%s" (expand-file-name bare-repo)) env))))
  env)

(advice-add 'magit-process-environment
            :filter-return #'my/magit-bare-repo-env)

;; Line numbers
;; t=standard, relative=relative, nil=off
(setq display-line-numbers-type `relative)

;; Abbrev
;; Definitions path
;; (setq abbrev-file-name "~/.doom.d/.abbrev_defs")

;; LSP
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
<style>body{background:#1b1b1b; color:#dcdcdc;}</style>
<style>h2{color:#c792ea;}</style>
<style>h3{color:#b5b5b5;}</style>
<style>h4{color:#8e8e8e;}</style>
<style>a{color:#5da5da; text-decoration-line: none;}</style>
<style>a:hover{text-decoration-line: underline;}</style>
<style>code{color:#dcdcdc; background:#2b2b2b; border: 1px solid #4c4c4c; padding-left: 0.2rem; padding-right: 0.2rem; font-size: 0.9rem;}</style>
<style>pre{background:#000000; color:#dcdcdc; border: 1px solid #4c4c4c; margin: 0.5rem; font-size: 0.9rem;}</style>
<style>#content{max-width:1024px; margin: 0 auto;}</style>
<style>#text-table-of-contents{border-bottom:1px solid #dcdcdc; margin-bottom: 1rem;}</style>
<style>.org-src-name{font-size: 0.875rem; line-height: 1.25rem;}</style>
<style>#postamble{margin-top: 3rem;}</style>
<style>.TODO{color: #f0c674;}</style>
<style>.PROJ{color: #b5bd68;}</style>
<style>.LOOP{color: #d84a9c;}</style>
<style>.DONE{color: #b8bb26;}</style>
<style>.STRT{color: #b294bb;}</style>
<style>.WAIT{color: #de935f;}</style>
<style>._X_{color: #b8bb26;}</style>
<style>.___{color: #f0c674;}</style>
<style>.tag{background-color: #3d3d3d; border-radius: 3px; padding: 0 3px;}</style>
")

;; lsp auto complete delay
(setq lsp-idle-delay 0.001)
(setq company-tooltip-idle-delay 0.001)
(setq company-dabbrev-downcase 0)
(setq company-idle-delay 0)
(setq company-minimum-prefix-length 1)

(use-package lsp-tailwindcss
  :init
  (setq lsp-tailwindcss-add-on-mode t))
