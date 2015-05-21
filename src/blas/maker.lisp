(in-package #:matlisp)

(deft/generic (t/zeros #'subtypep) sym (dims &optional initial-element))

(deft/method t/zeros (class stride-accessor) (dims &optional initial-element)
  (with-gensyms (astrs adims sizs)
    `(letv* ((,adims (coerce ,dims 'index-store-vector) :type index-store-vector)
	     (,astrs ,sizs (,(if (hash-table-storep class) 'make-stride-cmj 'make-stride) ,adims) :type index-store-vector index-type))
       (make-instance ',class
		      :dimensions ,adims
		      :head 0 :strides ,astrs
		      :store (t/store-allocator ,class
						,(if (hash-table-storep class)
						     `(cl:max (cl:ceiling (cl:* *default-sparsity* ,sizs)) (or ,initial-element 0))
						     sizs)
						,@(when initial-element `((t/coerce ,(field-type class) ,initial-element))))))))

(deft/method t/zeros (class graph-accessor) (dims &optional nz)
  (with-gensyms (adims nnz)
    `(letv* ((,adims (coerce ,dims 'index-store-vector) :type (index-store-vector 2))
	     (,nnz (max (ceiling (* *default-sparsity* (lvec-foldr #'* ,adims))) (or ,nz 0))))
       (make-instance ',class
		      :dimensions ,adims
		      :fence (t/store-allocator index-store-vector (1+ (aref ,adims 1))) ;;Compressed Columns by default
		      :neighbours (t/store-allocator index-store-vector ,nnz)
		      ,@(when (subtypep class 'base-tensor) `(:store (t/store-allocator ,class ,nnz)))))))

#+nil
(deft/method t/zeros (class compressed-sparse-matrix) (dims &optional nz)
  (with-gensyms (dsym)
    `(let ((,dsym ,dims))
       (destructuring-bind (vr vd) (t/store-allocator ,class ,dsym ,nz)
	 (make-instance ',class
			:dimensions (make-index-store ,dims)
			:neighbour-start (allocate-index-store (1+ (second ,dsym)))
			:neighbour-id vr
			:store vd)))))

;;
;; (deft/method t/zeros (class permutation-cycle) (dims &optional nz)
;;   (using-gensyms (decl (dims))
;;     `(let (,@decl)
;;        (declare (type index-type ,dims))
;;        (with-no-init-checks
;; 	   (make-instance ',class
;; 			  :store nil
;; 			  :size 0)))))

;; (deft/method t/zeros (class permutation-action) (dims &optional nz)
;;   (using-gensyms (decl (dims))
;;     `(let (,@decl)
;;        (declare (type index-type ,dims))
;;        (with-no-init-checks
;; 	   (make-instance ',class
;; 			  :store (index-id ,dims)
;; 			  :size ,dims)))))

;; (deft/method t/zeros (class permutation-pivot-flip) (dims &optional nz)
;;   (using-gensyms (decl (dims))
;;     `(let (,@decl)
;;        (declare (type index-type ,dims))
;;        (with-no-init-checks
;; 	   (make-instance ',class
;; 			  :store (index-id ,dims)
;; 			  :size ,dims)))))

;;
(defgeneric zeros-generic (dims dtype &optional initial-element)
  (:documentation "
    A generic version of @func{zeros}.
")
  (:method ((dims list) (dtype t) &optional initial-element)
    ;;(assert (tensor-leafp dtype) nil 'tensor-abstract-class :tensor-class dtype)
    (compile-and-eval
     `(defmethod zeros-generic ((dims list) (dtype (eql ',dtype)) &optional initial-element)
	(if initial-element
	    (t/zeros ,dtype dims initial-element)
	    (t/zeros ,dtype dims))))
    (zeros-generic dims dtype initial-element)))


(definline zeros (dims &optional (type *default-tensor-type*) initial-element)
"
    Create a tensor with dimensions @arg{dims} of class @arg{dtype}.
    The optional argument @arg{initial-element} is used in two completely
    incompatible ways.

    If @arg{dtype} is a dense tensor, then @arg{initial-element}, is used to
    initialize all the elements. If @arg{dtype} is however, a sparse tensor,
    it is used for computing the number of nonzeros slots in the store.

    Example:
    > (zeros 3)
    #<REAL-TENSOR #(3)
      0.0000      0.0000      0.0000     
    >

    > (zeros 3 'complex-tensor 2)
    #<COMPLEX-TENSOR #(3)
      2.0000      2.0000      2.0000     
    >

    > (zeros '(10000 10000) 'real-compressed-sparse-matrix 10000)
    #<REAL-COMPRESSED-SPARSE-MATRIX #(10000 10000), store-size: 10000>
"
  (with-no-init-checks
    (let ((type (etypecase type (standard-class (class-name type)) (symbol type) (list (apply #'tensor type)))))
      (etypecase dims
	(list (zeros-generic dims type initial-element))
	(vector (zeros-generic (lvec->list dims) type initial-element))
	(fixnum (zeros-generic (list dims) type initial-element))))))

(declaim (ftype (function ((or list vector fixnum) &optional t t) t) zeros))
