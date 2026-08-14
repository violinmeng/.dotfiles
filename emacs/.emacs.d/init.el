;;; init.el --- Load the canonical XDG Emacs configuration -*- lexical-binding: t; -*-

(let ((config-home (or (getenv "XDG_CONFIG_HOME")
                       (expand-file-name "~/.config"))))
  (load (expand-file-name "emacs/init.el" config-home) nil 'nomessage))

;;; init.el ends here
