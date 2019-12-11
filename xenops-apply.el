(defmacro xenops-define-apply-command (op-type docstring)
  `(defun ,(intern (concat "xenops-" (symbol-name op-type))) ()
     ,(concat docstring " "
              "The elements operated on are determined by trying the following:
1. The element at point, if any.
2. Elements in the active region, if there is an active region.
3. All elements in the buffer.")
     (interactive)
     (xenops-apply ',op-type)))

(defmacro xenops-define-apply-at-point-command (op docstring)
  `(defun ,(intern (concat "xenops-" (symbol-name op) "-at-point")) ()
     ,docstring
     (interactive)
     (-if-let* ((el (xenops-apply-parse-at-point))
                (handlers (xenops-ops-get ',op :handlers)))
         (xenops-element-dispatch el handlers))))

(defun xenops-apply (op &optional pred)
  "Apply operation type OP-TYPE to any elements encountered. The region
operated on is either the element at point, the active region, or
the entire buffer.

Optional argument PRED is a function taking an element plist as
its only argument. The element will be operated on iff PRED
returns non-nil."
  (xenops-apply-handlers (xenops-ops-get op :handlers) pred))

(defun xenops-apply-handlers (handlers &optional pred)
  "Apply HANDLERS to any elements encountered. The region
operated on is either the element at point, the active region, or
the entire buffer."
  (cl-flet ((handle (lambda (el) (save-excursion
                              (xenops-element-dispatch el handlers)))))
    (-if-let* ((el (xenops-apply-parse-at-point)))
        (handle el)
      (cl-destructuring-bind (beg end region-active)
          (if (region-active-p)
              `(,(region-beginning) ,(region-end) t)
            `(,(point-min) ,(point-max) nil))
        (save-excursion
          (goto-char beg)
          (let ((parse-at-point-fns (xenops-elements-get-all :parser)))
            (while (setq el (xenops-apply-get-next-element nil end parse-at-point-fns))
              (and el
                   (or (null pred) (funcall pred el))
                   (handle el)))))
        ;; Hack: This should be abstracted.
        (and region-active (not (-intersection handlers '(xenops-math-image-increase-size
                                                          xenops-math-image-decrease-size)))
             (deactivate-mark))))))

(defun xenops-apply-get-next-element (&optional start-regexp end parse-at-point-fns)
  "If there is another element, return it and leave point after it.
An element is a plist containing data about a regexp match for a
section of the buffer that xenops can do something to."
  (let ((start-regexp (or start-regexp (xenops-elements-delimiter-start-regexp)))
        (end (or end (point-max)))
        (parse-at-point-fns (or parse-at-point-fns (xenops-elements-get-all :parser))))
    (-if-let* ((_ (re-search-forward start-regexp end t))
               (_ (goto-char (match-beginning 0)))
               (element (xenops-apply-parse-at-point parse-at-point-fns))
               (_ (goto-char (plist-get element :end))))
        element)))

(defun xenops-apply-parse-at-point (&optional parse-at-point-fns)
  (xenops-util-first-result #'funcall (or parse-at-point-fns
                                          (xenops-elements-get-all :parser))))

(provide 'xenops-apply)
