(in-package #:matlisp)

(defun loadtxt (fname &key (type *default-tensor-type*) (format :csv) (delimiters '(#\Space #\Tab #\,)) comments (newlines '(#\Newline #\;)) (skip-rows 0))
  (let* ((f-string (file->string fname))
	 (*read-default-float-format* 'double-float))
    (multiple-value-bind (lns nrows) (split-seq #'(lambda (x) (member x newlines)) f-string)
      (setf nrows (+ nrows 1 (- skip-rows))
	    lns (nthcdr skip-rows lns))
      (unless (null lns)
	(let* ((ncols (1+ (nth-value 1 (split-seq #'(lambda (x) (member x delimiters)) (car lns)))))
	       (ret (zeros (if (> ncols 1) (list nrows ncols) (list nrows)) type)))
	  (if (> ncols 1)
	      (loop :for line :in lns
		 :for i := 0 :then (1+ i)
		 :do (loop :for num :in (split-seq #'(lambda (x) (member x delimiters)) line)
			:for j := 0 :then (1+ j)
			:do (setf (ref ret i j) (read-from-string num))))
	      (loop :for line :in lns
		 :for i := 0 :then (1+ i)
		 :do (setf (ref ret i) (read-from-string (car (split-seq #'(lambda (x) (member x delimiters)) line))))))
	  ret)))))

(defun savetxt (fname mat &key (delimiter #\Tab) (newline #\Newline))
  (with-open-file (out fname :direction :output :if-exists :supersede :if-does-not-exist :create)
    (cond
      ((tensor-matrixp mat)
       (let ((ncols (ncols mat)))
	 (loop :for i :from 0 :below (nrows mat)
	    :do (loop :for j :from 0 :below ncols
		   :do (format out "~a~a" (ref mat i j) (if (= j (1- ncols)) newline delimiter))))))
      ((tensor-vectorp mat)
       (loop :for i :from 0 :below (aref (dimensions mat) 0)
	  :do (format out "~a~a" (ref mat i) newline)))
      (t
       (let ((dims (dimensions mat))
	     (strd (strides mat)))
	 (format out ":head~a~a~a" delimiter (head mat) newline)
	 (format out ":dimensions~a" delimiter)
	 (loop :for i :from 0 :below (length dims)
	    :do (format out "~a~a" (aref dims i) (if (= i (1- (length dims))) newline delimiter)))
	 (format out ":strides~a" delimiter)
	 (loop :for i :from 0 :below (length dims)
	    :do (format out "~a~a" (aref strd i) (if (= i (1- (length dims))) newline delimiter)))
	 (let ((sto (store mat)))
	   (loop :for i :from 0 :below (length sto)
	      :do (format out "~a~a" (aref sto i) (if (= i (1- (length sto))) newline delimiter)))))))
    nil))

;;

(defun loadmtx (fname &key (delimiters '(#\Space #\Tab #\,)) (newlines '(#\Newline #\;)) (skip-rows 0))
  (with-open-file (fs fname)
    (let* ((dims 
	    (do ((line (read-line fs nil nil) (read-line fs nil nil)))
		((null line))
	      (unless (char= (aref line 0) #\%)
		(return (mapcar #'read-from-string (split-seq #'(lambda (x) (member x delimiters)) line))))))
	   (mtx (zeros (subseq dims 0 2) 'real-sparse-tensor))
	   (*read-default-float-format* 'double-float))
      (do ((line (read-line fs nil nil) (read-line fs nil nil)))
	  ((null line) mtx)
	(let ((dat (mapcar #'read-from-string (split-seq #'(lambda (x) (member x delimiters)) line))))
	  (setf (ref mtx (mapcar #'1- (subseq dat 0 2))) (third dat)))))))

  ;; (multiple-value-bind (lns nrows) (split-seq #'(lambda (x) (member x newlines)) f-string)
  ;;     (loop :for 
  ;;     (unless (null lns)
  ;; 	(let* ((ncols (second (multiple-value-list (split-seq #'(lambda (x) (member x delimiters)) (car lns)))))
  ;; 	       (ret (zeros (if (> ncols 1) (list nrows ncols) (list nrows)) 'real-tensor)))
  ;; 	  (if (> ncols 1)
  ;; 	      (loop :for line :in lns
  ;; 		 :for i := 0 :then (1+ i)
  ;; 		 :do (loop :for num :in (split-seq #'(lambda (x) (member x delimiters)) line)
  ;; 			:for j := 0 :then (1+ j)
  ;; 			:do (setf (ref ret i j) (t/coerce (t/field-type real-tensor) (read-from-string num)))))
  ;; 	      (loop :for line :in lns
  ;; 		 :for i := 0 :then (1+ i)
  ;; 		 :do (setf (ref ret i) (t/coerce (t/field-type real-tensor) (read-from-string (car (split-seq #'(lambda (x) (member x delimiters)) line)))))))
  ;; 	  ret)))))
