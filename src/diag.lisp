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
;;;
;;; $Id: diag.lisp,v 1.1 2000/04/14 00:11:12 simsek Exp $
;;;
;;; $Log: diag.lisp,v $
;;; Revision 1.1  2000/04/14 00:11:12  simsek
;;; o This file is adapted from obsolete files 'matrix-float.lisp'
;;;   'matrix-complex.lisp' and 'matrix-extra.lisp'
;;; o Initial revision.
;;;
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package "MATLISP")

(use-package "BLAS")
(use-package "LAPACK")
(use-package "FORTRAN-FFI-ACCESSORS")

(export 'diag)

;; note: here and in copy change fortran-dscal to dcopy.

(defgeneric diag (matrix)
  (:documentation
   "
 Syntax
 ======
 (DIAG x)
 
 Purpose
 =======
 Given the matrix X, returns the diagonal elements of X as a
 column vector if X is a matrix.  If X is a vector
 returns a new matrix whose diagonal is X.

 Settable
 ========
 (SETF (DIAG x) y) works as follows.

 If Y is a scalar then the diagonal elements of X are assigned to Y.
 If Y is a vector then the diagonal elements of X are assigned to 
 the elements of Y.
 If Y is a matrix then the diagonal elements of X are assigned to
 the diagonal elements of Y.

 The dimensions of X,Y need not match.  In this case, the maximum
 assignable elements are considered.

 Returns X.
"))

(defmethod diag ((mat number))
  mat)

(defmethod diag ((mat real-matrix))
  (if (row-or-col-vector-p mat)
      (let* ((nxm (nxm mat))
	     (result (make-real-matrix-dim nxm nxm)))
	(declare (type fixnum nxm))
	(dcopy nxm (store mat) 1 (store result) (1+ nxm))
	result)
    (let* ((n (n mat))
	   (m (m mat))
	   (p (min m n))
	   (result (make-real-matrix-dim p 1)))
      (declare (type fixnum n m p))
      (dcopy p (store mat) (1+ n) (store result) 1)
      result)))

(defmethod (setf diag) ((new-diag double-float) (mat real-matrix))
  (let* ((n (n mat))
	 (m (m mat))
	 (p (min m n)))
    (declare (type fixnum n m p))

    (setf (aref *1x1-real-array* 0) new-diag)
    (dcopy p *1x1-real-array* 0 (store mat) (1+ n))
    mat))

(defmethod (setf diag) ((new-diag real) (mat real-matrix))
  (setf (diag mat) (coerce new-diag 'real-matrix-element-type)))

(defmethod (setf diag) ((new-diag complex) (mat real-matrix))
  (error "cannot set the diagonal of ~a to ~a, don't know how to
coerce COMPLEX to REAL"
	 mat
	 new-diag))

(defmethod (setf diag) ((new-diag real-matrix) (mat real-matrix))
  (let* ((n (n mat))
	 (m (m mat))
	 (n-new (n new-diag))
	 (m-new (m new-diag))
	 (nxm-new (nxm new-diag)))
    (declare (type fixnum n m n-new m-new nxm-new))

    (if (row-or-col-vector-p new-diag)
	  (dcopy (min n m nxm-new) (store new-diag) 1 (store mat) (1+ n))
      (dcopy (min n m n-new m-new) (store new-diag) (1+ n-new) (store mat) (1+ n)))
    
    mat))

(defmethod (setf diag) ((new-diag complex-matrix) (mat real-matrix))
  (error "cannot assign the COMPLEX matrix ~a to the diagonal of the REAL matrix ~a,
don't know how to coerce COMPLEX to REAL"
	 new-diag
	 mat))

(defmethod diag ((mat complex-matrix))
  (if (row-or-col-vector-p mat)
      (let* ((nxm (nxm mat))
	     (result (make-complex-matrix-dim nxm nxm)))
	(declare (type fixnum nxm))
	(zcopy nxm (store mat) 1 (store result) (1+ nxm))
	result)
    (let* ((n (n mat))
	   (m (m mat))
	   (p (min m n))
	   (result (make-complex-matrix-dim p 1)))

      (declare (type fixnum n m p))
      (zcopy p (store mat) (1+ n) (store result) 1)
      result)))
	 

(defmethod (setf diag) ((new-diag complex-matrix) (mat complex-matrix))
  (let* ((n (n mat))
	 (m (m mat))
	 (n-new (n new-diag))
	 (m-new (m new-diag))
	 (nxm-new (nxm new-diag)))
    (declare (type fixnum n m n-new m-new nxm-new))
    (if (row-or-col-vector-p new-diag)
	(zcopy (min n m nxm-new) (store new-diag) 1 (store mat) (1+ n))
      (zcopy (min n m n-new m-new) (store new-diag) (1+ n-new) (store mat) (1+ n)))
    mat))


(defmethod (setf diag) ((new-diag real-matrix) (mat complex-matrix))
  (let* ((n (n mat))
	 (m (m mat))
	 (n-new (n new-diag))
	 (m-new (m new-diag))
	 (nxm-new (nxm new-diag)))
    (declare (type fixnum n m n-new m-new nxm-new))

    (if (row-or-col-vector-p new-diag)
	(progn
	  (with-vector-data-addresses ((addr-mat (store mat))) 
	      (incf-sap :double-float addr-mat)
	      (blas::fortran-dscal (min n m nxm-new) 0.0d0 addr-mat (+ 2 (* 2 n))))
	  (dcopy (min n m nxm-new) (store new-diag) 1 (store mat) (+ 2 (* 2 n))))
      (progn
	(with-vector-data-addresses ((addr-mat (store mat))) 
	   (incf-sap :double-float addr-mat)
	   (blas::fortran-dscal (min n m n-new m-new) 0.0d0 addr-mat (+ 2 (* 2 n))))
	(dcopy (min n m n-new m-new) (store new-diag) (1+ n-new) (store mat) (+ 2 (* 2 n)))))

    mat))

(defmethod (setf diag) ((new-diag kernel::complex-double-float) (mat complex-matrix))
  (let* ((n (n mat))
	 (m (m mat))
	 (p (min n m)))
    (declare (type fixnum n m p))

    (setf (aref *1x1-complex-array* 0) (realpart new-diag))
    (setf (aref *1x1-complex-array* 1) (imagpart new-diag))
    (zcopy p *1x1-complex-array* 0 (store mat) (1+ n))
    mat))

(defmethod (setf diag) ((new-diag number) (mat complex-matrix))
  (setf (diag mat) (complex-coerce new-diag)))







