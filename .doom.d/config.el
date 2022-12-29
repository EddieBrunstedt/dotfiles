;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
(setq user-full-name "Eddie Brunstedt"
      user-mail-address "eddie.brunstedt@protonmail.com")

;;; UI
;; Theme
(setq doom-theme 'doom-xcode)
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
(setq abbrev-file-name "~/.doom.d/.abbrev_defs")

;; Lsp
;; Disable formatting with lsp for typescript files
(setq-hook! 'typescript-mode-hook +format-with-lsp nil)

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
<style>h2{color:#ffc587;;}</style>
<style>h3{color:#f27a7a;}</style>
<style>h4{color:#49a080;}</style>
<style>a{color:#60a5fa; text-decoration-line: none;}</style>
<style>a:hover{text-decoration-line: underline;}</style>
<style>code{color:#fdba74; background:#27272a; border: 1px solid #3f3f46; padding-left: 0.2rem; padding-right: 0.2rem; font-size: 0.9rem;}</style>
<style>pre{background:#27272a; color:#d4d4d8; border: 1px solid #3f3f46; margin: 0.5rem; font-size: 0.9rem;}</style>
<style>#content{max-width:1024px;}</style>
<style>#text-table-of-contents{border-bottom:1px solid white; margin-bottom: 1rem; border-color: rgb(113 113 122);}</style>
<style>.org-src-name{font-size: 0.875rem; line-height: 1.25rem;}</style>
<style>#postamble{margin-top: 3rem;}</style>
<style>.TODO{color: #9294f3;}</style>
<style>.PROJ{color: #34c99f;}</style>
<style>.LOOP{color: #f35df1;}</style>
<style>.DONE{color: #61ad3e;}</style>
<style>.STRT{color: #8db8a9;}</style>
<style>.WAIT{color: #d6d074;}</style>
<style>._X_{color: #61ad3e;}</style>
<style>.___{color: #9294f3;}</style>
<style>.tag{background-color: #332819;}</style>
")

;; lsp auto complete delay
(setq lsp-idle-delay 0.001)
(setq company-tooltip-idle-delay 0.001)
(setq company-dabbrev-downcase 0)
(setq company-idle-delay 0)
(setq company-minimum-prefix-length 1)
