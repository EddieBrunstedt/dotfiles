;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq user-full-name "Eddie Brunstedt"
      user-mail-address "eddie.brunstedt@protonmail.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "Dank Mono" :size 18))

(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 16 :weight 'light)
      doom-variable-pitch-font (font-spec :family "Noto Serif Nerd Font" :size 16)
      ivy-posframe-font (font-spec :family "JetBrainsMono Nerd font" :size 18))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. These are the defaults.
(setq doom-theme 'doom-one)

;; Show 80 column line
(global-display-fill-column-indicator-mode +1)
;; But not in Doom Dashboard
(add-hook! '+doom-dashboard-mode-hook (display-fill-column-indicator-mode -1))

;; Only format TypeScript on save
(add-to-list '+format-on-save-enabled-modes 'TypeScript-tsx t)

;; If you intend to use org, it is recommended you change this!
(setq org-directory "~/org/")

;; Roam directory
(setq org-roam-directory "~/org/roam")

(setq org-roam-rename-file-on-title-change t)

(display-time-mode 1)
(map! :n [mouse-8] #'better-jumper-jump-backward
      :n [mouse-9] #'better-jumper-jump-forward)

;; elfeed: default filter
(after! elfeed
  (setq elfeed-search-filter "@6-month-ago +unread"))
;; elfeed: Auto update on start
(add-hook! 'elfeed-search-mode-hook 'elfeed-update)

;; Preview buffers from ivy (buffer selection)
(setq +ivy-buffer-preview t)

;; Line numbers (t=standard, relative=relative, nil=off)
(setq display-line-numbers-type `relative)

;; Indent width
(setq js-indent-level 2)
(setq typescript-indent-level 2)
(setq-hook! 'typescript-tsx-mode-hook web-mode-code-indent-offset 2)

(after! git-gutter-fringe
  (setq fringe-mode 8))

;; Disable formatting with lsp
(setq +format-with-lsp nil)

;; Do not start spell-fu by default
(remove-hook! 'text-mode-hook #'spell-fu-mode)

;; Make comments italic
(custom-set-faces!
  '(font-lock-comment-face :slant italic)
  '(font-lock-doc-face :slant italic))

;; tell emacs where to read abbrev definitions from
(setq abbrev-file-name "~/.doom.d/.abbrev_defs")

;; LSP related
;; Complements `find-defintions' (which is `g d')
(define-key evil-normal-state-map (kbd "g f") 'lsp-ui-peek-find-references)

(after! lsp-ui
  (define-key lsp-ui-peek-mode-map (kbd "j") 'lsp-ui-peek--select-next)
  (define-key lsp-ui-peek-mode-map (kbd "k") 'lsp-ui-peek--select-prev)
  (define-key lsp-ui-peek-mode-map (kbd "C-k") 'lsp-ui-peek--select-prev-file)
  (define-key lsp-ui-peek-mode-map (kbd "C-j") 'lsp-ui-peek--select-next-file)

  (setq lsp-ui-peek-fontify 'always
        lsp-ui-peek-list-width 80
        lsp-ui-peek-peek-height 40

        lsp-ui-doc-enable t
        ;; Prevents LSP peek to disappear when mouse touches it
        lsp-ui-doc-show-with-mouse t
        lsp-ui-doc-show-with-cursor t
        lsp-ui-doc-include-signature t
        lsp-ui-doc-delay 0.2
        lsp-ui-doc-position 'top
        lsp-ui-doc-max-width 100
        lsp-ui-doc-max-height 50

        lsp-ui-imenu-enable t

        lsp-enable-symbol-highlighting t

        ;; Inline error messages
        lsp-ui-sideline-enable nil)
  )

;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', where Emacs
;;   looks when you load packages with `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c g k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c g d') to jump to their definition and see how
;; they are implemented.
