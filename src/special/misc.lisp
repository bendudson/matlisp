(in-package #:matlisp)

(defun range (start end &optional h_ list-outputp &aux (h (or h_ 1)))
  (declare (type real start end h))
  (let ((quo (ceiling (if (> start end) (- start end) (- end start)) h))
	(h (if (> start end) (- h) h)))
    (if (= quo 0) nil
	(if (not list-outputp)
	    (let* ((type (realtype-max (list h start end (+ h start) (- end h)))))
	      (mapsor! (let ((ori (coerce start type)) (h (coerce h type)))
			 (lambda (idx y) (declare (ignore idx y)) (prog1 ori (incf ori h))))
		       nil (zeros quo (dense-tensor type))))
	    (loop :for i :from 0 :below quo
	       :for ori := start :then (+ ori h)
	       :collect ori)))))

(defun linspace (start end &optional num-points list-outputp)
  (let* ((num-points (floor (or num-points (1+ (abs (- start end))))))
	 (h (/ (- end start) (1- num-points))))
    (range start (+ h end) (abs h) list-outputp)))

;;This will only work if type is a dense-tensor
(defun ones (dims &optional (type *default-tensor-type*))
  (the dense-tensor (zeros dims type 1)))

(defun eye! (tensor)
  (tricopy! 1 (copy! 0 tensor) :d))

(defun eye (dims &optional (type *default-tensor-type*))
  (tricopy! 1 (zeros dims type) :d))

(defun diag (tensor &optional (order 2))
  (declare (type (and tensor-vector dense-tensor) tensor))
  (tricopy! tensor (zeros (make-list order :initial-element (dimensions tensor 0)) (type-of tensor)) :d))

(defun diag~ (a)
  (declare (type dense-tensor a))
  (with-no-init-checks
    (make-instance (class-of a)				
      :dimensions (coerce (list (lvec-min (dimensions a))) 'index-store-vector)
      :strides (coerce (list (lvec-foldr #'+ (strides a))) 'index-store-vector)
      :head (head a) :store (store a) :parent a)))

(defun (setf diag~) (value tensor) (copy! value (diag~ tensor)))
