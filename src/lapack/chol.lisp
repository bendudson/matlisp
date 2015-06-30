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

(deft/generic (t/lapack-potrf! #'subtypep) sym (A lda uplo))
(deft/method (t/lapack-potrf! #'blas-tensor-typep) (sym dense-tensor) (A lda uplo)
  (let ((ftype (field-type sym)))
    (using-gensyms (decl (A lda uplo))
      `(let* (,@decl)
	 (declare (type ,sym ,A)
		  (type index-type ,lda)
		  (type character ,uplo))
	 (ffuncall ,(blas-func "potrf" ftype)
		   (:& :character) ,uplo
		   (:& :integer) (dimensions ,A 0)
		   (:* ,(lisp->ffc ftype) :+ (head ,A)) (the ,(store-type sym) (store ,A)) (:& :integer) ,lda
		   (:& :integer :output) 0)))))

;;
(defgeneric potrf! (a &optional uplo)
  (:documentation "
  Syntax
  ======
  (POTRF! a)

  Purpose
  =======
  POTRF computes the Cholesky factorization of a real symmetric
  positive definite matrix A.

  This is the block version of the algorithm, calling Level 3 BLAS.

  Return Values
  =============
  [1] The factor U or L from the Cholesky
	  factorization A = U**T*U or A = L*L**T.
  [2] INFO = T: successful
	     i:  U(i,i) is exactly zero.
")
  (:method :before ((a dense-tensor) &optional (uplo *default-uplo*))
     (assert (typep a 'tensor-square-matrix) nil 'tensor-dimension-mismatch :message "Expected square matrix.")
     (assert (inline-member uplo (:l :u)) nil 'invalid-arguments :given uplo :expected `(member uplo '(:l :u)))))

(define-tensor-method potrf! ((a dense-tensor :x t) &optional (uplo *default-uplo*))
  `(with-columnification (() (A))
     (let ((info (t/lapack-potrf! ,(cl a) A (or (blas-matrix-compatiblep A #\N) 0) (char-upcase (aref (symbol-name uplo) 0)))))
       (unless (= info 0)
	 (if (< info 0)
	     (error "POTRF: the ~a'th argument had an illegal value." (- info))
	     (error 'matrix-not-pd :message "POTRF: the leading minor of order ~a is not p.d; the factorization could not be completed." :position info)))))
  'A)

(definline chol! (a &optional (uplo *default-uplo*))
  (tricopy! 0 (potrf! a uplo) (ecase uplo (:l :uo) (:u :lo))))
;;
(deft/generic (t/lapack-potrs! #'subtypep) sym (A lda B ldb uplo))
(deft/method (t/lapack-potrs! #'blas-tensor-typep) (sym dense-tensor) (A lda B ldb uplo)
  (let ((ftype (field-type sym)))
    (using-gensyms (decl (A lda B ldb uplo))
      `(let* (,@decl)
	 (declare (type ,sym ,A ,B)
		  (type index-type ,lda ,ldb)
		  (type character ,uplo))
	 (ffuncall ,(blas-func "potrs" ftype)
	   (:& :character) ,uplo
	   (:& :integer) (dimensions ,A 0) (:& :integer) (dimensions ,B 1)
	   (:* ,(lisp->ffc ftype) :+ (head ,A)) (the ,(store-type sym) (store ,A)) (:& :integer) ,lda
	   (:* ,(lisp->ffc ftype) :+ (head ,B)) (the ,(store-type sym) (store ,B)) (:& :integer) ,ldb
	   (:& :integer :output) 0)))))

;;
(defgeneric potrs! (A B &optional uplo)
  (:documentation "
  Syntax
  ======
  (POTRS! a b [:U :L])

  Purpose
  =======
  Solves a system of linear equations
      A * X = B  or  A' * X = B
  with a general N-by-N matrix A using the Cholesky LU factorization computed
  by POTRF.  A and are the results from POTRF, UPLO specifies
  the form of the system of equations:
	   = 'U':   A = U**T*U
	   = 'L':   A = L*L**T

  Return Values
  =============
  [1] The NxM matrix X. (overwriting B)
  [4] INFO = T: successful
	     i:  U(i,i) is exactly zero.  The LU factorization
		 used in the computation has been completed,
		 but the factor U is exactly singular.
		 Solution could not be computed.
")
  (:method :before ((A dense-tensor) (B dense-tensor) &optional (uplo *default-uplo*))
     (assert (and (typep A 'tensor-square-matrix) (<= (order B) 2) (= (dimensions A 0) (dimensions B 0))) nil 'tensor-dimension-mismatch)
     (assert (inline-member uplo (:l :u)) nil 'invalid-value :given uplo :expected `(member uplo '(:u :l)))))

(define-tensor-method potrs! ((A dense-tensor :x) (B dense-tensor :x t) &optional (uplo *default-uplo*))
  `(if (tensor-vectorp B)
       (potrs! A (suptensor~ B 2) uplo)
       (with-columnification (((A #\C)) (B))
	 (let ((info (t/lapack-potrs! ,(cl a)
				      A (or (blas-matrix-compatiblep A #\N) 0)
				      B (or (blas-matrix-compatiblep B #\N) 0)
				      (aref (symbol-name uplo) 0))))
	   (unless (= info 0) (error "POTRS returned ~a. the ~:*~a'th argument had an illegal value." (- info))))))
  'B)
;;
(deft/generic (t/lapack-potri! #'subtypep) sym (A lda uplo))
(deft/method (t/lapack-potri! #'blas-tensor-typep) (sym dense-tensor) (A lda uplo)
  (let ((ftype (field-type sym)))
    (using-gensyms (decl (A lda uplo))
      `(let* (,@decl)
	 (declare (type ,sym ,A)
		  (type index-type ,lda)
		  (type character ,uplo))
	 (ffuncall ,(blas-func "potri" ftype)
	   (:& :character) ,uplo (:& :integer) (dimensions ,A 0)
	   (:* ,(lisp->ffc ftype) :+ (head ,A)) (the ,(store-type sym) (store ,A)) (:& :integer) ,lda
	   (:& :integer :output) 0)))))

(defgeneric potri! (A &optional uplo)
  (:documentation "
  Syntax
  ======
  (POTRI! a [:U :L])

  Purpose
  =======
  Computes the inverse of using the pre-computed Cholesky at A.
")
  (:method :before ((A dense-tensor) &optional (uplo *default-uplo*))
     (assert (and (typep A 'tensor-square-matrix)) nil 'tensor-dimension-mismatch)
     (assert (inline-member uplo (:l :u)) nil 'invalid-value :given uplo :expected `(member uplo '(:u :l)))))

(define-tensor-method potri! ((A dense-tensor :x t) &optional (uplo *default-uplo*))
  `(with-columnification (() (A))
     (let ((info (t/lapack-potri! ,(cl a)
				  A (or (blas-matrix-compatiblep A #\N) 0)
				  (aref (symbol-name uplo) 0))))
       (unless (= info 0) (error "POTRI returned ~a. the ~:*~a'th argument had an illegal value." (- info)))))
  'A)
;;

(defun chol (a &optional (uplo *default-uplo*))
  (declare (type (and tensor-square-matrix (satisfies blas-tensorp)) a))
  (let ((l (copy a)))
    (restart-case (potrf! l uplo)
      (increment-diagonal-and-retry (value)
	(copy! a l) (axpy! value nil (diag~ l))
	(potrf! l uplo)))
    (tricopy! 0d0 l (ecase uplo (:u :lo) (:l :uo)))))
;;

#+nil
(let* ((a #i(a := randn([10, 10]), a + a' + 20 * eye([10, 10])))
       (x (randn '(10 5)))
       (b #i(a * x)))
  (norm (t- x (potrs! (chol a) b))))
