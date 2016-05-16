(in-package #:matlisp)

(closer-mop:defgeneric graph->adlist (g)
  (:generic-function-class tensor-method-generator))
(define-tensor-method graph->adlist ((g graph-accessor :x))
  `(with-memoization ()
     (iter (for i from 0 below (1- (length (memoizing (fence g) :type index-store-vector)))) (with ret = (make-array (1- (length (memoizing (fence g)))) :initial-element nil))
	   (iter (for j in-vector (memoizing (δ-i g) :type index-store-vector) from (aref (memoizing (fence g)) i) below (aref (memoizing (fence g)) (1+ i)) with-index m)
		 (push ,@(if (subtypep (cl :x) 'tensor) `((cons j (t/store-ref ,(cl :x) (memoizing (t/store ,(cl :x) g) :type ,(store-type (cl :x))) m))) `(j)) (aref ret i)))
	   (finally (return ret)))))

(defun adlist->graph (ag &optional type &aux (type (or type 'graph-accessor)))
  (let*-typed ((ag (coerce ag 'vector))
	       (ret (zeros (list (length ag) (length ag)) type (iter (for ai in-vector ag) (summing (length ai)))) :type graph-accessor))
    (with-memoization ()
      (iter (for i from 0 below (length ag))
	    (initially (setf (aref (memoizing (fence ret) :type index-store-vector) 0) 0))
	    (setf (aref (memoizing (fence ret)) (1+ i)) (aref (memoizing (fence ret)) i))
	    (iter (for u in (setf (aref ag i) (sort (aref ag i) #'< :key #'(lambda (x) (etypecase x (cons (the index-type (first x))) (index-type x))))))
		  (letv* ((u/ value (etypecase u (cons (the index-type (values (first u) (cdr u)))) (index-type u)))
			  (m (aref (memoizing (fence ret)) (1+ i))))
		    (setf (aref (memoizing (δ-i ret) :type index-store-vector) m) u/)
		    (if value (setf (store-ref (the graph-tensor ret) m) value)))
		  (incf (aref (memoizing (fence ret)) (1+ i))))))
    ret))

(defun hyper->bipartite (hh &optional type full)
  (letv* ((vv (coerce (sort (reduce #'union hh) #'<) 'index-store-vector)) (hh (coerce hh 'vector))
	  (n (length vv)) (m (length hh)))
    (if full
	(let ((hh (symmetrize! (concatenate 'vector (make-array n :initial-element nil) hh))))
	  (adlist->graph hh))
	(let ((ret (zeros (list n m) (or type 'graph-accessor) (iter (for h in-vector hh) (summing (length h))))))
	  (iter (for i from 0 below (length hh))
		(setf (aref hh i) (sort (aref hh i) #'<))
		(iter (for u in (aref hh i))
		      (setf (aref (δ-i ret) (+ (fence ret i) j)) u) (counting t into j)
		      (finally (setf (aref (fence ret) (1+ i)) (+ (fence ret i) j)))))
	  ret))))

(defun order->tree (order &optional type)
  (adlist->graph
   (symmetrize!
    (iter (for i from 0 below (length order))
	  (collect (if (/= (aref order i) i) (list (aref order i))) result-type 'vector)))
   type))

(defun cliquep (g lst)
  (iter main (for u* on lst)
    (iter (for v in (cdr u*)) (or (δ-i g (car u*) v) (return-from main nil)))
    (finally (return-from main t))))

(defun gnp (n p)
  ;;TODO: Implement fast version from "Efficient generation of large random networks" - V. Batagelj, U. Brandes, PRL E 71
  ;;Current alg is O(n^2) and is way too slow.
  (let ((ret (zeros (list n n) (tensor 'index-type 'hash-tensor))))
    (iter (for i from 0 below n)
	  (iter (for j from (1+ i) below n)
		(if (< (random 1d0) p)
		    (setf (ref ret i j) 1
			  (ref ret j i) 1))))
    (copy ret '(index-type graph-accessor))))

;;Oh may we weep for sins
(defun moralize! (adg)
  (let ((cadg (copy adg)))
    (iter (for u from 0 below (length adg))
	  (let ((pa (remove-if #'(lambda (x) (find u (aref adg x))) (aref adg u))))
	    (iter (for p.i in pa) (setf (aref cadg p.i) (union (aref cadg p.i) (list* u pa))))))
    cadg))

(defun symmetrize! (adg)
  (iter (for u from 0 below (length adg))
	(iter (for v in (aref adg u))
	      (setf (aref adg v) (union (aref adg v) (list u)))))
  adg)
;;
(defun graph-queue (init g)
  (declare (type graph-accessor g))
  (let* ((queue (fib:make-heap #'(lambda (a b) (if (and a b) (< a b) (and a t))))))
    (iter (for i from 0 below (1- (length (fence g)))) (fib:insert-key (funcall init g i) queue))
    queue))

(defmacro graphfib ((g graph &key order iterate block-name) init update &rest body)
  (with-gensyms (fe queue)
    (destructuring-bind (init-sym (i) &rest init-body) init
      (assert (eql init-sym :init) nil "key mismatch.")
      (destructuring-bind (update-sym (j w-j fib) &rest update-body) update
	(assert (eql update-sym :update) nil "key mismatch.")
	`(block ,block-name
	   (let*-typed ((,g ,graph :type graph-accessor)
			(,fe (fence ,g) :type index-store-vector)
			(,fib (let* ((,queue (fib:make-heap ,(or order #'(lambda (a b) (if (and a b) (< a b) (and a t)))))))
				(iter (for ,i from 0 below (1- (length (fence ,g)))) (fib:insert-key (progn ,@init-body) ,queue))
				,queue)))
	     (iter (until (= (total-size fib) 0))
		   ,@(when iterate
			   (letv* (((lvar ldir) iterate))
			     `((for ,lvar initially ,@(ecase ldir (:up `(0 then (1+ ,lvar))) (:down `((- (length ,fe) 2) then (1- ,lvar))))))))
		   (letv* ((,w-j ,j (fib:extract-min ,fib) :type t index-type))
		     ,@update-body))
	     ,@body))))))

;;TODO: The clique-check can be eliminated, apparently. See Tarjan's paper.
(defun max-cardinality-search (g &optional start)
  (let* ((order (t/store-allocator index-store-vector (1- (length (fence g)))))
	 (start (or start (random (length order))))
	 (cliques nil)
	 (k (1- (length (fence g)))) (stack nil))
    (graphfib (g g :order (lambda (x y) (> x y)))
      (:init (i) (if (= i start) 1 0))
      (:update (i w-i fib)
	 (letv* ((li ri (fence g i))
		 (δ-clique (iter (for j in-vector (δ-i g) from li below ri) (when (or (member j stack) (fib:node-existsp j fib)) (collect j)))))
	   (if (cliquep g δ-clique)
	       (iter (for j in-vector (δ-i g) from li below ri) (incf (fib:node-key j fib))
		     (finally (setf (aref order (decf k)) i)
			      (setf cliques (let ((c (list (cons i δ-clique)))) (union cliques (union c cliques :test #'subsetp) :test #'subsetp)))
			      (iter (for u in stack) (fib:insert-key (fib:node-key u fib) fib u) (finally (setf stack nil)))))
	       (push i stack))))
      (unless stack (values (reverse order) cliques)))))

;;Naive-implementation, can't use graphfib because of non-monotonicity
;;Use union-find/hash-table in place of list forc sets.
(defun triangulate-graph (g &optional heuristic)
  (let* ((ag (graph->adlist g)) (heuristic (or heuristic :min-fill))
	 (ord (t/store-allocator index-store-vector (length ag))))
    (flet ((cliquify (u)
	     (iter (for v in (aref ag u))
		   (setf (aref ag v) (set-difference (aref ag v) (list u v))))
	     (setf (aref ag u) t))
	   (δ-size (i) (length (aref ag i)))
	   (k-size (i) (iter main (for u* on (aref ag i))
			     (iter (for v in (cdr u*)) (unless (find (car u*) (aref ag v)) (in main (counting t)))))))
      (iter (for i from 0 below (length ord))
	    (setf (aref ord i) (iter (for i from 0 below (length ag))
				     (unless (eql (aref ag i) t)
				       (finding i minimizing (ecase heuristic (:min-fill (δ-size i)) (:min-size (k-size i)))))))
	    (cliquify (aref ord i))))
    ord))

;;Translated from Tim Davis' CSparse
(defun elimination-tree (order g)
  (declare (type graph-accessor g))
  (let ((iord (t/store-allocator index-store-vector (length order)))
	(ancestor (t/store-allocator index-store-vector (length order) :initial-element -1))
	(parent (t/store-allocator index-store-vector (length order) :initial-element -1)))
    (declare (type index-store-vector iord ancestor parent))
    (iter (for i from 0 below (length iord)) (setf (aref iord (aref order i)) i))
    (iter (for u in-vector order)
	  (setf (aref parent u) u)
	  (letv* ((ll rr (fence g (the index-type u)) :type index-type index-type))
	    (iter (for v in-vector (δ-i g) from ll below rr)
		  (when (< (aref iord v) (aref iord u))
		    (iter (for h initially v then (let ((h+ (aref ancestor h))) (setf (aref ancestor h) u)
						       (when (or (< h+ 0) (= h+ u)) (setf (aref parent h) u) (finish))
						       h+)))))))
    (values parent iord)))

;;Translated from Tim Davis' CSparse
(defun cholesky-cover (g order)
  (declare (type graph-accessor g)
	   (type index-store-vector order))
  (letv* ((etree iord (elimination-tree order g)) (color (t/store-allocator #.(tensor 'boolean) (length etree)))
	  (adj (make-array (length etree) :initial-element nil)))
    (iter (for u in-vector order) (setf (aref color u) t) (push u (aref adj u))
	  (letv* ((ll rr (fence g u)))
	    (iter (for v in-vector (δ-i g) from ll below rr with-index iuv)
		  (when (< (aref iord v) (aref iord u))
		    (iter (for w initially v then (aref etree w)) (if (aref color w) (finish) (progn (setf (aref color w) t) (push w (aref adj u)))))))
	    (iter (for v in (aref adj u)) (setf (aref color v) nil))))
    (let ((lg (adlist->graph adj (type-of g))))
      #+nil
      (iter (for u from 0 below (1- (length (fence g))))
	    (letv* ((ll rr (fence g u)))
	      (iter (for v in-vector (δ-i g) from ll below rr with-index iuv)
		    (when (< (aref iord v) (aref iord u)) (setf (ref lg v u) (store-ref g iuv))))))
      (values lg iord))))

(defun chordal-cover (g order &optional type)
  (declare (type graph-accessor g)
	   (type index-store-vector order))
  (let* ((cc (graph->adlist g))
	 (vs (make-array (length cc) :initial-element nil)))
    (iter (for i in-vector order)
	  (iter (for j in (aref cc i))
		(unless (aref vs j)
		  (setf (aref cc j) (union (aref cc j) (remove-if #'(lambda (x) (or (= x j) (aref vs x))) (aref cc i))))))
	  (setf (aref vs i) t))
    (adlist->graph cc type)))

(defun line-graph (hh)
  (letv* ((hh (coerce hh 'vector)) (m (length hh))
	  (ret (zeros (list m m) (tensor t 'hash-tensor))))
    (iter (for i from 0 below (length hh))
	  (iter (for j from (1+ i) below (length hh))
		(when-let (int (intersection (aref hh i) (aref hh j)))
		  (setf (ref ret i j) int
			(ref ret j i) int))))
    (copy ret '(t graph-accessor))))

(defun tree-decomposition (g &optional type heuristic)
  (letv* ((cliques (or (nth-value 1 (max-cardinality-search g)) (nth-value 1 (max-cardinality-search (chordal-cover g (triangulate-graph g heuristic))))))
	  (k (length cliques)))
    (values
     (let ((ret (zeros (list k k) (tensor 'index-type 'hash-tensor))))
       (iter (for cc on cliques)
	     (iter (for cp in (cdr cc))
		   (counting t into j)
		   (if-let (int (intersection (car cc) cp))
		     (setf (ref ret i (+ i j)) (- (length int))
			   (ref ret (+ i j) i) (ref ret i (+ i j)))))
	     (counting t into i))
       (order->tree (dijkstra-prims (copy ret (tensor 'index-type 'simple-graph-tensor))) type))
     (coerce cliques 'vector))))

#+nil
(letv* ((ag (symmetrize! #((1) (2) (0 3) (4) (0))))
	(g (adlist->graph ag)))
    ;;(tree-decomposition (chordal-cover g (triangulate-graph g :min-size)))
    ;;(max-cardinality-search g)
    ;;(moralize! #(() (0) (0) (0) (2) (2)))
    ;;(values (copy tt '(index-type)) (dijkstra-prims tt))

    ;;(tree-decomposition ag)
  (letv* ((tt ci (tree-decomposition g)))
    (graph->adlist tt)
    )
  )

#+nil
(let* ((n 10)
       (n-cycle (symmetrize! (coerce (append (mapcar #'list (range 1 n nil t)) (list '(0))) 'vector)))
       (g (adlist->graph n-cycle)))
					;(display-graph (t))
  (max-cardinality-search (chordal-cover g (triangulate-graph g :min-size)))
  #+nil(letv* ((tt ci (time (tree-decomposition g))))
    t
    ))

#+nil
(let ((g (gnp 1000 0.1)))
  (time (tree-decomposition g)))
#+nil
(let ((g (gnp 100 0.02)))
  (map 'list #'length (nth-value 1 (tree-decomposition g))))

;;
(defun dijkstra (g &optional start)
  (declare (type graph-accessor g))
  (let* ((tree (t/store-allocator index-store-vector (dimensions g 0)))
	 (start (or start (random (length tree)))))
    (setf (aref tree start) start)
    (graphfib (g g :order (lambda (x y) (if (and x y) (< x y) (and x t))))
      (:init (i) (if (= i start) 0 nil))
      (:update (i d-i fib)
	 (letv* ((li ri (fence g i)))
	   (iter (for j in-vector (δ-i g) from li below ri)
		 (when (fib:node-existsp j fib)
		   (let ((d-j+ (+ d-i (if (typep g 'base-tensor) (ref g i j) 1))) (k-j (fib:node-key j fib)))
		     (when (or (not k-j) (< d-j+ k-j))
		       (setf (fib:node-key j fib) d-j+
			     (aref tree j) i)))))))
      tree)))

(defun dijkstra-prims (g &optional start)
  (declare (type graph-accessor g))
  (let* ((tree (t/store-allocator index-store-vector (dimensions g 0)))
	 (start (or start (random (length tree)))))
    (setf (aref tree start) start)
    (graphfib (g g :order (lambda (x y) (if (and x y) (< x y) (and x t))))
      (:init (i) (if (= i start) 0 nil))
      (:update (i w-i fib)
	 (letv* ((li ri (fence g i)))
	   (iter (for j in-vector (δ-i g) from li below ri)
		 (when (fib:node-existsp j fib)
		   (let ((w-ij (if (typep g 'base-tensor) (ref g i j) 1)) (k-j (fib:node-key j fib)))
		     (when (or (not k-j) (< w-ij k-j))
		       (setf (fib:node-key j fib) w-ij
			     (aref tree j) i)))))))
      tree)))
;;
(defun directed-subgraph (g)
  (let ((adg (graph->adlist g)))
    (iter (for u from 0 below (length adg)) (setf (aref adg u) (remove-if #'(lambda (x) (declare (type index-type x u)) (δ-i g x u)) (aref adg u))))
    (adlist->graph adg (class-of g))))

;;1/2 approximation,
(defun max-dag (g)
  "1/2 approximation to the Maximum acyclic subgraph problem (anything better is NP-hard assuming UGC)."
  (let* ((g (directed-subgraph g)) (gt (transpose g))
	 (adg (make-array (dimensions g -1) :initial-element nil)))
    (graphfib (g g :order #'(lambda (a b) (< (first a) (first b))))
      (:init (i) (list (δ-i g i :size) (δ-i gt i :size)))
      (:update (i d-i fib)
	 (map nil #'(lambda (v) (when (fib:node-existsp v fib)
				  (letv* (((a b) (fib:node-key v fib)))
				    (setf (fib:node-key v fib) (list (1- a) b))))) (δ-i gt i t))
	 (map nil #'(lambda (v) (when (fib:node-existsp v fib)
				  (letv* (((a b) (fib:node-key v fib)))
				    (setf (fib:node-key v fib) (list a (1- b)))))) (δ-i g i t))
	 (if (>= (first d-i) (second d-i))
	     (map nil #'(lambda (v) (if (fib:node-existsp v fib) (pushnew v (aref adg i)))) (δ-i g i t))
	     (map nil #'(lambda (v) (if (fib:node-existsp v fib) (pushnew i (aref adg v)))) (δ-i gt i t))))
      (adlist->graph adg (type-of g)))))

(defun topological-order (dag)
  (let ((dagt (transpose dag))
	(order (t/store-allocator index-store-vector (dimensions dag -1)))
	(visited (make-array (dimensions dag -1) :element-type 'boolean :initial-element nil)))
    (iter outer (for cu in-vector visited with-index u) (with ii = -1)
	  (unless cu
	    (iter (for tu in-graph dag from u in-order :sfd with-parent tp with-color color with-visited-array visited)
		  (setf (aref order (incf ii)) tu)
		  (when (some #'(lambda (x) (aref color x)) (δ-i dagt tu t))
		    (return-from outer))))
	  (finally (return-from outer order)))))

#+nil
(let ((g (display-graph (primal-graph '((<- 0 1) (<- 1 2) (<- 2 0)) nil t) nil t)))
  (topological-order g)
  #+nil(iter (for tu in-graph g with-parent tp in-order :dfs)
	(print (list tu tp)))
  )

#+nil
(let ((g *dbg*))
  (topological-order g)
  #+nil(iter (for tu in-graph g with-parent tp in-order :dfs)
	(print (list tu tp)))
  )

#+nil
(let ((g (display-graph (primal-graph '((<- 0 1) (<- 1 2) (<- 2 0)) nil t) nil t)))
  (topological-order g)
  #+nil(iter (for tu in-graph g with-parent tp in-order :dfs)
	(print (list tu tp)))
  )

#+nil(defparameter *wiki-graph* (copy (let ((mat (zeros '(6 6) '(index-type stride-accessor hash-table))))
				   (map nil #'(lambda (x)
						(destructuring-bind (i j w) x
						    (setf (ref mat i j) w
							  (ref mat j i) w)))
					'((0 1 7)
					  (0 2 9)
					  (0 5 14)
					  (1 2 10)
					  (1 3 15)
					  (2 5 2)
					  (2 3 11)
					  (3 4 6)
					  (4 5 9)))
				   mat)
				 '(index-type graph-accessor)))
;;
