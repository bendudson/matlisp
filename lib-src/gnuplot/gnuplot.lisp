(in-package :matlisp)
(defvar *current-gnuplot-process* nil)

(defun open-gnuplot-stream (&optional (gnuplot-binary (pathname "/usr/bin/gnuplot")))
  (#+:sbcl
   sb-ext:run-program
   #+:ccl
   ccl:run-program
   gnuplot-binary nil :input :stream :wait nil :output t))

(defun gnuplot-send (str &rest args)
  (unless *current-gnuplot-process*
    (setf *current-gnuplot-process* (open-gnuplot-stream)))
  (let ((stream (#+:sbcl
		 sb-ext:process-input
		 #+:ccl
		 ccl:external-process-input-stream
		 *current-gnuplot-process*)))
    (apply #'format (append (list stream str) args))
    (finish-output stream)))

(defun plot2d (data &key (lines t) (color (list "#FF0000")))
  (with-open-file (s "/tmp/matlisp-gnuplot.out" :direction :output :if-exists :supersede :if-does-not-exist :create)
    (loop :for i :from 0 :below (loop :for x :in data :minimizing (size x))
       :do (loop :for x :in data :do (format s "~a " (coerce (ref x i) 'single-float)) :finally (format s "~%"))))
  (if lines
      (gnuplot-send "plot '/tmp/matlisp-gnuplot.out' with lines linecolor rgb ~s~%" color)
      (gnuplot-send "plot '/tmp/matlisp-gnuplot.out'~%")))

;; (defclass gnuplot-plot-info ()
;;   ((title
;;     :initform "GNU PLOT"
;;     :accessor gnuplot-title)
;;    (x-label
;;     :initform "X"
;;     :accessor gnuplot-x-label)
;;    (y-label
;;     :initform "Y"
;;     :accessor gnuplot-y-label)
;;    (x-data
;;     :accessor gnuplot-x-data)
;;    (y-data
;;     :accessor gnuplot-y-data)
;;    (z-data
;;     :accessor gnuplot-z-data)))


;; (defun gnuplot-plot (info  &key (stream (#+:sbcl
;; 							       sb-ext:process-input
;; 							       *current-gnuplot-stream*)))
;;   (with-accessors ((title gnuplot-title)
;; 		   (x-label gnuplot-x-label)
;; 		   (y-label gnuplot-y-label)
;; 		   (x-data gnuplot-x-data)
;; 		   (y-data gnuplot-y-data)
;; 		   (z-data gnuplot-z-data))
;;       info
;;     (format stream "~&set title '~S'~%" title)
;;     (format stream "~&set xlabel '~S'~%" x-label)
;;     (format stream "~&set ylabel '~S'~%" y-label)
;;     (finish-output stream)
;;     (map nil #'(lambda (x y z)
;; 		 (with-open-file (s "/tmp/gnuplot.out" :direction :output
;; 				    :if-exists :overwrite)
;; 		   (map nil #'(lambda (xs ys zs)
;; 				(if zs
;; 				    (format s "~A ~A ~A~%" xs ys zs)
;; 				    (format s "~A ~A~%" xs ys)))
;; 			x y z)
;; 		   (format stream "~A '/tmp/gnuplot.out'~%"
;; 			   (if z "splot" "plot"))
;; 		   (finish-output stream)
;; 		   (sleep 5)))
;; 	 x-data y-data z-data)
;;     ))
