(in-package #:matlisp-tests)

(defun randn (shape) (t:random-normal shape))
(defun zrandn (shape)
  (let ((ret (t:zeros shape (t:tensor '(complex double-float)))))
    (copy! (t:random-normal shape) (t:realpart~ ret))
    (copy! (t:random-normal shape) (t:imagpart~ ret))
    ret))
(defun srandn (shape) (copy (randn shape) (t:tensor 'single-float)))
(defun crandn (shape) (copy (zrandn shape) (t:tensor '(complex single-float))))
