;;; flymake-twig.el --- Flymake backend for Twig using twig-lint  -*- lexical-binding: t; -*-

(require 'flymake)

(defgroup flymake-twig nil
  "Flymake backend for twig using twig-lint."
  :group 'flymake)

(defvar-local flymake-twig--proc nil)

(defun flymake-twig (report-fn &rest _args)
  "Make twig-lint process."
  (unless (executable-find
           "twig-lint") (error "Cannot find a suitable twig-lint"))
  (when (process-live-p flymake-twig--proc)
    (kill-process flymake-twig--proc))
  (let ((source (current-buffer)))
    (save-restriction
      (widen)
      (setq flymake-twig--proc
            (make-process
             :name "flymake-twig-lint" :noquery t :connection-type 'pipe
             :buffer (generate-new-buffer " *flymake-twig-lint*")
             :command (list "twig-lint" "lint" "--format" "csv" "--only-print-errors" (buffer-file-name source))
             :sentinel
             (lambda (proc _event)
                (when (eq 'exit (process-status proc))
                  (unwind-protect
                      (if (with-current-buffer source (eq proc flymake-twig--proc))
                          (with-current-buffer (process-buffer proc)
                            (goto-char (point-min))
                            (cl-loop
                             while (search-forward-regexp
                                    ;; "base.html.twig",4,Unexpected "}".
                                    "^\"\\(.*.twig\\)\",\\([0-9]+\\),\\(.*\\)$"
                                    nil t)
                             for msg = (match-string 3)
                             for (beg . end) = (flymake-diag-region
                                                source
                                                (string-to-number (match-string 2)))
                             for type = :warning
                             collect (flymake-make-diagnostic source beg end type msg)
                             into diags
                             finally (funcall report-fn diags)))
                        (flymake-log :warning "Canceling obsolete check %s" proc))
                    (kill-buffer (process-buffer proc))))))))))

;;;###autoload
(defun flymake-twig-turn-on ()
  "Enable `flymake-twig' as buffer-local Flymake backend."
  (interactive)
  (flymake-mode 1)
  (add-hook 'flymake-diagnostic-functions 'flymake-twig nil t))

(provide 'flymake-twig)
;;; flymake-twig.el ends here
