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
;;; $Id: special.lisp,v 1.1 2000/04/14 00:11:12 simsek Exp $
;;;
;;; $Log: special.lisp,v $
;;; Revision 1.1  2000/04/14 00:11:12  simsek
;;; o This file is adapted from obsolete files 'matrix-float.lisp'
;;;   'matrix-complex.lisp' and 'matrix-extra.lisp'
;;; o Initial revision.
;;;
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package "MATLISP")

(export '(eye
	  ones
	  zeros
	  rand))

(defun eye (n &optional (m n))
"
  Syntax
  ======
  (EYE n [m])

  Purpose
  =======
  If M is the same as N (the default), then creates
  an NxN identity matrix.  If M is different from N
  the creates an NxM matrix with 1's on the diagonal
  and 0's elsewhere.

  See ONES, ZEROS
"
  (if (and (integerp n)
	   (integerp m)
	   (> n 0)
	   (> m 0))
      (let ((result (make-real-matrix-dim n m)))
	(setf (aref *1x1-real-array* 0) 1.0d0)
	(dcopy (min n m) *1x1-real-array* 0 (store result) (1+ n))
	result)
    (error "arguments N and M to EYE must be positive integers")))

(defun zeros (n &optional (m n))
"
  Syntax
  ======
  (ZEROS n [m])

  Purpose
  =======
  Creates an NxM (default NxN) matrix filled with zeros.

  See EYE, ONES
"
(if (and (integerp n)
	 (integerp m)
	 (> n 0)
	 (> m 0))
    (let ((result (make-real-matrix-dim n m)))
      result)
  (error "arguments N and M to ZEROS must be positive integers")))
  
(defun ones (n &optional (m n))
"
  Syntax
  ======
  (ONES n [m])

  Purpose
  =======
  Creates an NxM (default NxN) matrix filled with ones

  See EYE, ZEROS
"
  (if (and (integerp n)
	   (integerp m)
	   (> n 0)
	   (> m 0))
      (let ((result (make-real-matrix-dim n m 1.0d0)))
	result)
    (error "arguments N and M to ONES must be positive integers")))

(defun rand (n &optional (m n) (state *random-state* state-p))
"
  Syntax
  ======
  (RAND n [m] [state])

  Purpose
  =======
  Creates an NxM (default NxN) matrix filled with uniformly 
  distributed pseudo-random numbers between 0 and 1.  
  STATE (default *RANDOM-STATE*), if given, should be a RANDOM-STATE.

  See RANDOM, INIT-RANDOM-STATE, MAKE-RANDOM-STATE, *RANDOM-STATE*
"
 (multiple-value-bind (m state)
     (if (not state-p)
	 (typecase m
	   (integer (values m state))
	   (random-state (values n m))
	   (t (error "arguments to RAND are not of expected type")))
       (if (and (subtypep (type-of m) 'integer)
		(subtypep (type-of state) 'random-state))
	   (values m state)
	 (error "arguments to RAND are not of expected type")))

   (if (and (integerp n)
	    (integerp m)
	    (> n 0)
	    (> m ))
       (locally (declare (type fixnum n m))
	   (let* ((size (* n m))
		  (store (make-array size :element-type 'real-matrix-element-type))
		  (unity #.(coerce 1 'real-matrix-element-type)))
	     
	     (declare (fixnum size)
		      (type (real-matrix-store-type (*)) store))
	     (dotimes (k size)
	       (declare (fixnum k))
	       (setf (aref store k) (random unity state)))
	     
	     (make-instance 'real-matrix :n n :m m :store store)))
     (error "arguments N and M to RAND must be positive integers"))))
