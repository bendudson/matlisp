;;; -*- Mode: lisp; Syntax: ansi-common-lisp; Package: :matlisp; Base: 10 -*-
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Copyright (c) 2000 The Regents of the University of California.
;;; All rights reserved. 
;;; 
;;; Permission is hereby granted, without written agreement and without
;;; license or royalty fees, to use, copy, modify, and distribute this
;;; software and its documentation for any purpose, provided that the
;;; above copyright notice and the following two paragraphs appear in all
;;; copies of this software.
;;; 
;;; IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY
;;; FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
;;; ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF
;;; THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
;;; SUCH DAMAGE.
;;;
;;; THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
;;; INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
;;; MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE
;;; PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
;;; CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
;;; ENHANCEMENTS, OR MODIFICATIONS.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package #:matlisp)

(defmacro generate-typed-copy! (func (tensor-class blas-func fortran-lb))
  ;;Be very careful when using functions generated by this macro.
  ;;Indexes can be tricky and this has no safety net
  ;;Use only after checking the arguments for compatibility.
  (let* ((opt (get-tensor-class-optimization-hashtable tensor-class)))
    (assert opt nil 'tensor-cannot-find-optimization :tensor-class tensor-class)
    `(definline ,func (from to)
       (declare (type ,tensor-class from to))
       ,(let
	 ((lisp-routine
	   `(let ((f-sto (store from))
		  (t-sto (store to)))
	      (declare (type ,(linear-array-type (getf opt :store-type)) f-sto t-sto))
	      (very-quickly
		;;Can possibly make this faster (x2) by using ,blas-func in one of
		;;the inner loops, but this is to me messy and as of now unnecessary.
		;;SBCL can already achieve Fortran-ish speed inside this loop.
		(mod-dotimes (idx (dimensions from))
		  with (linear-sums
			(f-of (strides from) (head from))
			(t-of (strides to) (head to)))
		  do (,(getf opt :reader-writer) f-sto f-of t-sto t-of))))))
	 (if blas-func
	     `(let* ((call-fortran? (> (number-of-elements to) ,fortran-lb))
		     (strd-p (when call-fortran? (blas-copyable-p from to))))
		(cond
		  ((and strd-p call-fortran?)
		   (,blas-func (number-of-elements from)
			       (store from) (first strd-p)
			       (store to) (second strd-p)
			       (head from) (head to)))
		  (t
		   ,lisp-routine)))
	     lisp-routine))
       to)))

(defmacro generate-typed-num-copy! (func (tensor-class blas-func fortran-lb))
  ;;Be very careful when using functions generated by this macro.
  ;;Indexes can be tricky and this has no safety net
  ;;(you don't see a matrix-ref do you ?)
  ;;Use only after checking the arguments for compatibility.
  (let* ((opt (get-tensor-class-optimization-hashtable tensor-class)))
    (assert opt nil 'tensor-cannot-find-optimization :tensor-class tensor-class)
    `(definline ,func (num-from to)
       (declare (type ,tensor-class to)
		(type ,(getf opt :element-type) num-from))
       ,(let
	 ((lisp-routine
	   `(let-typed
	     ((t-sto (store to) :type ,(linear-array-type (getf opt :store-type))))
	     (very-quickly
	       (mod-dotimes (idx (dimensions to))
		 with (linear-sums
		       (t-of (strides to) (head to)))
		 do (,(getf opt :value-writer) num-from t-sto t-of))))))
	 (if blas-func
	     `(let* ((call-fortran? (> (number-of-elements to) ,fortran-lb))
		     (min-stride (when call-fortran? (consecutive-store-p to))))
		(cond
		  ((and call-fortran? min-stride)
		   (let ((num-array (,(getf opt :store-allocator) 1)))
		     (declare (type ,(linear-array-type (getf opt :store-type)) num-array))
		     (,(getf opt :value-writer) num-from num-array 0)
		     (,blas-func (number-of-elements to)
				 num-array 0
				 (store to) min-stride
				 0 (head to))))
		  (t
		   ,lisp-routine)))
	     lisp-routine))
	 to)))

;;Real
(generate-typed-copy! real-typed-copy!
  (real-tensor dcopy *real-l1-fcall-lb*))

(generate-typed-num-copy! real-typed-num-copy!
  (real-tensor dcopy *real-l1-fcall-lb*))

;;Complex
(generate-typed-copy! complex-typed-copy!
  (complex-tensor zcopy *complex-l1-fcall-lb*))

(generate-typed-num-copy! complex-typed-num-copy!
  (complex-tensor zcopy *complex-l1-fcall-lb*))

;;Symbolic
#+maxima
(progn
(generate-typed-copy! symbolic-typed-copy!
  (symbolic-tensor nil 0))

(generate-typed-num-copy! symbolic-typed-num-copy!
  (symbolic-tensor nil 0)))
;;---------------------------------------------------------------;;
;;Generic function defined in src;base;generic-copy.lisp

(defmethod copy! :before ((x standard-tensor) (y standard-tensor))
  "
  The contents of X must be coercable to
  the type of Y.  For example,
  a COMPLEX-MATRIX cannot be copied to a
  REAL-MATRIX but the converse is possible."
  (assert (lvec-eq (dimensions x) (dimensions y) #'=) nil
	  'tensor-dimension-mismatch))

(defmethod copy! ((x standard-tensor) (y standard-tensor))
  (mod-dotimes (idx (dimensions x))
    do (setf (tensor-ref y idx) (tensor-ref x idx)))
  y)

(defmethod copy! ((x complex-tensor) (y real-tensor))
  (error 'coercion-error :from 'complex-tensor :to 'real-tensor))

(defmethod copy! ((x real-tensor) (y real-tensor))
  (real-typed-copy! x y))

(defmethod copy! ((x number) (y real-tensor))
  (real-typed-num-copy! (coerce-real x) y))

(defmethod copy! ((x complex-tensor) (y complex-tensor))
  (complex-typed-copy! x y))

(defmethod copy! ((x real-tensor) (y complex-tensor))
  ;;Borrowed from realimag.lisp
  (let ((tmp (make-instance 'real-tensor
			    :parent-tensor y :store (store y)
			    :dimensions (dimensions y)
			    :strides (map 'index-store-vector #'(lambda (n) (* 2 n)) (strides y))
			    :head (the index-type (* 2 (head y))))))
    (declare (type real-tensor tmp))
    (real-typed-copy! x tmp)
    ;;Increasing the head by 1 points us to the imaginary part.
    (incf (head tmp))
    (real-typed-num-copy! 0d0 tmp))
  y)

(defmethod copy! ((x number) (y complex-tensor))
  (complex-typed-num-copy! (coerce-complex x) y))

;; Copy between a Lisp array and a tensor
(defun convert-to-lisp-array (tensor)
"
  Syntax
  ======
  (convert-to-lisp-array tensor)

  Purpose
  =======
  Create a new Lisp array with the same dimensions as the tensor and
  with the same elements.  This is a copy of the tensor.
"
  (declare (type standard-tensor tensor))
  (let*-typed ((dims (dimensions tensor) :type index-store-vector)
	       (ret (make-array (lvec->list dims)
				:element-type (or (getf (get-tensor-object-optimization tensor) :element-type)
						  (error 'tensor-cannot-find-optimization :tensor-class (class-name (class-of tensor)))))))
    (let ((lst (make-list (rank tensor))))
      (very-quickly
	(mod-dotimes (idx dims)
	  do (setf (apply #'aref ret (lvec->list! idx lst)) (tensor-ref tensor idx))))
      ret)))

(defmethod copy! :before ((x standard-tensor) (y array))
  (assert (subtypep (getf (get-tensor-object-optimization x) :element-type)
		    (array-element-type y))
	  nil 'invalid-type
	  :given (getf (get-tensor-object-optimization x) :element-type)
	  :expected (array-element-type y))
  (assert (and
	   (= (rank x) (array-rank y))
	   (dolist (ele (mapcar #'= (lvec->list (dimensions x)) (array-dimensions y)) t)
	     (unless ele (return nil))))
	  nil 'dimension-mismatch))

(defmethod copy! ((x real-tensor) (y array))
  (let-typed ((sto-x (store x) :type real-store-vector)
	      (lst (make-list (rank x)) :type cons))
    (very-quickly
      (mod-dotimes (idx (dimensions x))
	with (linear-sums
	      (of-x (strides x) (head x)))
	do (setf (apply #'aref y (lvec->list! idx lst))
		 (aref sto-x of-x)))))
  y)

(defmethod copy! ((x complex-tensor) (y array))
  (let-typed ((sto-x (store x) :type complex-store-vector)
	      (lst (make-list (rank x)) :type cons))
    (very-quickly
      (mod-dotimes (idx (dimensions x))
	with (linear-sums
	      (of-x (strides x) (head x)))
	do (setf (apply #'aref y (lvec->list! idx lst))
		 (complex (aref sto-x (* 2 of-x)) (aref sto-x (1+ (* 2 of-x))))))))
  y)

;;
(defmethod copy! :before ((x array) (y standard-tensor))
  (assert (subtypep (array-element-type x)
		    (getf (get-tensor-object-optimization y) :element-type))
	  nil 'invalid-type
	  :given (array-element-type x) :expected (getf (get-tensor-object-optimization y) :element-type))
  (assert (and
	   (= (array-rank x) (rank y))
	   (dolist (ele (mapcar #'= (array-dimensions x) (lvec->list (dimensions y))) t)
	     (unless ele (return nil))))
	  nil 'dimension-mismatch))

(defmethod copy! ((x array) (y real-tensor))
  (let-typed ((sto-y (store y) :type real-store-vector)
	      (lst (make-list (array-rank x)) :type cons))
    (very-quickly
      (mod-dotimes (idx (dimensions y))
	with (linear-sums
	      (of-y (strides y) (head y)))
	do (setf (aref sto-y of-y) (apply #'aref x (lvec->list! idx lst))))))
  y)

(defmethod copy! ((x array) (y complex-tensor))
  (let-typed ((sto-y (store y) :type real-store-vector)
	      (lst (make-list (array-rank x)) :type cons))
    (very-quickly
      (mod-dotimes (idx (dimensions y))
	with (linear-sums
	      (of-y (strides y) (head y)))
	do (let-typed ((ele (apply #'aref x (lvec->list! idx lst)) :type complex-type))
	     (setf (aref sto-y (* 2 of-y)) (realpart ele)
		   (aref sto-y (1+ (* 2 of-y))) (imagpart ele))))))
  y)

;;
;;Generic function defined in src;base;generic-copy.lisp

(defmethod copy ((tensor real-tensor))
  (let* ((ret (apply #'make-real-tensor (lvec->list (dimensions tensor)))))
    (declare (type real-tensor ret))
    (copy! tensor ret)))

(defmethod copy ((tensor complex-tensor))
  (let* ((ret (apply #'make-complex-tensor (lvec->list (dimensions tensor)))))
    (declare (type complex-tensor ret))
    (copy! tensor ret)))

(defmethod copy ((tensor number))
  tensor)
