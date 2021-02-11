;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; refresh' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Eddie Brunstedt"
      user-mail-address "eddie.brunstedt@gmail.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
(setq doom-font (font-spec :family "Roboto Mono Medium" :size 17))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. These are the defaults.
(setq doom-theme 'doom-tomorrow-night)

;; If you intend to use org, it is recommended you change this!
(setq org-directory "~/org/")

;; Roam directory
(setq org-roam-directory "~/org-roam")

(setq org-roam-rename-file-on-title-change t)

;; Org capture templates
(after! org
  (add-to-list
   'org-capture-templates
   '("w" "Work"))
  (add-to-list
   'org-capture-templates
   '("wc" "customers" entry (file "~/org/penneo-customers.org")
     "* %^{Name of End user account}
:PROPERTIES:
:Title: Handover info regarding %\\1 from sales
:Account: %^{Salesforce Account ID}
:END:
** TODO Set up %\\1
SCHEDULED: %^t
** Account information at handover
- Name :: %\\1
- VATIN :: %^{Vatin}
- Salesforce Account ID :: [[https://penneo.lightning.force.com/%\\2][%\\2]]
- Netsuite Org ID :: %^{Netsuite Org ID}
- Industry :: %^{Industry}
- Using integration :: %^{Will be using integration?}
- Parent - Salesforce Account ID :: %^{Parent - Salesforce Account ID}
- Parent - Vatin :: %^{Parent - Vatin}
*** Address
%^{Address}
*** Contact person
- Name :: %^{Name of contact person}
- Email :: %^{Email to contact person}
- Phone :: %^{Phone to contact person}
*** Products
%?
*** Misc
%^{Misc}"
     :empty-lines 1
     :prepend t))
  )

;; If you want to change the style of line numbers, change this to `relative' or
;; `nil' to disable it:
(setq display-line-numbers-type `relative)

;; Set javascript indent level to two spaces
(setq js-indent-level 2)

;; Setting typescript indent level [EXPERIMENTAL]
(setq typescript-indent-level 2)
(setq-hook! 'typescript-tsx-mode-hook web-mode-code-indent-offset 2)

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
        lsp-ui-peek-list-width 50
        lsp-ui-peek-peek-height 40

        lsp-ui-doc-enable t
        ;; Prevents LSP peek to disappear when mouse touches it
        lsp-ui-doc-show-with-mouse nil
        lsp-ui-doc-include-signature t
        lsp-ui-doc-delay 0.5
        ;; lsp-ui-doc-position 'at-point
        lsp-ui-doc-position (quote top)
        lsp-ui-doc-max-width 100
        lsp-ui-doc-max-height 50

        ;; This is just annoying, really
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
