;; Generic operations on an element. Functions in this file should determine behavior based on the
;; type of the element and requested operations, by consulting the `xenops-elements' and
;; `xenops-ops' data structures. They should not directly call functions that are specific to
;; element type (e.g. in xenops-math, xenops-image, xenops-text).

(defun xenops-element-delete-overlays (element)
  (let ((beg (plist-get element :begin))
        (end (plist-get element :end)))
    (dolist (ov (overlays-in beg end))
      (when (overlay-get ov 'xenops-overlay-type)
        (delete-overlay ov)))))

(defalias 'xenops-element-reveal #'xenops-element-delete-overlays)

(defun xenops-element-copy (element)
  (copy-region-as-kill (plist-get element :begin)
                       (plist-get element :end)))

(defun xenops-element-delete (element)
  (kill-region (plist-get element :begin)
               (plist-get element :end))
  t)

(defun xenops-element-dispatch-operation (el handlers)
  "The first handler in HANDLERS that is valid for an element of this type."
  (car (-intersection handlers (xenops-element-handlers-for-el el))))

(defun xenops-element-handlers-for-el (el)
  "The valid operations for an element of this type."
  (xenops-elements-get (plist-get el :type) :handlers))

(defun xenops-element-get-image-at-point ()
  (let ((display (get-char-property (point) 'display )))
    (and (eq (car display) 'image) display)))

(defun xenops-element-get-image (element)
  (save-excursion
    (goto-char (plist-get element :begin))
    (xenops-element-get-image-at-point)))

(defun xenops-element-make-overlay (element)
  (let* ((beg (plist-get element :begin))
         (end (plist-get element :end))
         (ov (make-overlay beg end))
         (keymap (make-sparse-keymap)))
    (overlay-put ov 'xenops-overlay-type 'xenops-overlay)
    (overlay-put ov 'evaporate t)
    (overlay-put ov
                 'modification-hooks
                 (list (lambda (o _flag _beg _end &optional _l)
                         (delete-overlay o))))
    (overlay-put ov 'help-echo (buffer-substring beg end))

    (set-keymap-parent keymap xenops-rendered-element-keymap)
    (define-key keymap [mouse-3] #'xenops-element-menu)
    (overlay-put ov 'keymap keymap)

    ov))

(defun xenops-element-menu (event)
  (popup-menu
   `("Xenops"
     ["Edit" (xenops-reveal)])
   event))

(provide 'xenops-element)
