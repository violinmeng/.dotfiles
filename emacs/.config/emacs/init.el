(defconst rc/config-directory
  (file-name-directory (or load-file-name user-init-file))
  "Directory containing the canonical Emacs configuration.")

(setq custom-file (expand-file-name "custom.el" rc/config-directory))
(package-initialize)

(load-file (expand-file-name "emacs.rc/rc.el" rc/config-directory))


;; 默认英文字体
(set-face-attribute 'default nil :family "Iosevka Nerd Font Mono" :height 220)

;; 中文字体
(set-fontset-font t 'han (font-spec :family "Sarasa Fixed SC" :size 20))

;; Emoji
(set-fontset-font t 'emoji (font-spec :family "Apple Color Emoji" :height 160) nil 'prepend)


(tool-bar-mode 0)
(menu-bar-mode 0)
(scroll-bar-mode 0)
(show-paren-mode 1)

(rc/require-theme 'gruber-darker)


;;; ido
(rc/require 'smex 'ido-completing-read+)

(require 'ido-completing-read+)

(ido-mode 1)
(ido-everywhere 1)
(ido-ubiquitous-mode 1)



;;; dired
(require 'dired-x)
(setq dired-omit-files
      (concat dired-omit-files "\\|^\\..+$"))
(setq-default dired-dwim-target t)
(setq dired-listing-switches "-alh")
(setq dired-mouse-drag-files t)


(when (file-exists-p custom-file)
  (load-file custom-file))
