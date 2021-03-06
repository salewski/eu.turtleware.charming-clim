(in-package #:eu.turtleware.charming-clim)

(defclass frame-manager ()
  ((frames :initarg :frames :accessor frames :documentation "All frames")
   (active :initarg :active :accessor active :documentation "Active frame"))
  (:default-initargs :frames nil :active nil))

(defclass frame (surface)
  ((fn :initarg :fn :accessor fn)
   (ap :initarg :ap :accessor ap))
  (:default-initargs :r1 1 :c1 1 :r2 24 :c2 80
                     :sink *buffer*
                     :fn (constantly t) :ap nil))

(defun render-application (fm frame)
  (declare (ignore fm))
  (with-buffer (frame)
    (funcall (fn frame) frame)
    (ctl (:fls :force t))))

(defun render-decorations (fm frame)
  (declare (ignore fm))
  (let ((r1 (r1 frame))
        (c1 (c1 frame))
        (r2 (r2 frame))
        (c2 (c2 frame)))
    (ctl (:clr r1 c1 r2 c2))
    (loop with col = (1+ c2)
          for row from (1+ r1) upto (1- r2)
          do (out (:row row :col col) " ")
          finally (out (:col col :row r1 :fgc #xff224400) "x")
                  (when (or (> (rows frame) (1+ (- r2 r1)))
                            (> (cols frame) (1+ (- c2 c1))))
                    (out (:col col :row (1- r2)) "&"))
                  (out (:col col :row r2) "/"))))

(defun display-screen (fm)
  (ctl (:clr 1 1 (rows *console*) (cols *console*))
       (:bgc #x33333300) (:fgc #xbbbbbb00))
  (dolist (frame (frames fm))
    (unless (eq frame (active fm))
      (render-decorations fm frame)
      (render-application fm frame)))
  (alexandria:when-let ((frame (active fm)))
    (ctl (:bgc #x33336600) (:fgc #xffffff00))
    (render-decorations fm frame)
    (render-application fm frame))
  (ctl (:bgc #x11111100) (:fgc #xbbbbbb00)))

(defun ensure-demos (fm)
  (unless (frames fm)
    (setf (frames fm)
          (list (make-lambda-demo    :r1 2  :c1 4  :r2 13 :c2 43)
                (make-noise-demo     :r1 2  :c1 50 :r2 13 :c2 77)
                (make-animation-demo :r1 5  :c1 10 :r2 11 :c2 70)
                (make-report-demo    :r1 15 :c1 10 :r2 20 :c2 70)))))

(defun show-screen ()
  (loop with fm = (make-instance 'frame-manager)
        do (ensure-demos fm)
        do (process-available-events)
        do (display-screen fm)
        do (show-modeline)
        do (ctl (:fls))))

(let ((cycle-start (get-internal-real-time))
      (frame-count 0)
      (last-second 0))
  (defun get-fps ()
    (if (> (- (get-internal-real-time) cycle-start)
           internal-time-units-per-second)
        (setf cycle-start (get-internal-real-time)
              last-second frame-count
              frame-count 0)
        (incf frame-count))
    last-second))

(defun get-cpf ()
  (prog1 *counter*
    (setf *counter* 0)))

(defun show-modeline ()
  (let* ((row (rows *console*))
         (col (cols *console*))
         (cells (* row col))
         (fps (get-fps))
         (wch (get-cpf))
         (vel (* fps wch))
         (wpc (truncate wch cells))
         (str (format nil "Cells ~d (~d x ~d), FPS: ~d, WCH: ~d, WPC: ~d, VEL: ~d"
                      cells row col fps wch wpc vel))
         (rem (- col (length str)))
         (fil (if (plusp rem)
                  (make-string rem :initial-element #\space)
                  ""))
         (str (subseq (format nil "~a~a" str fil) 0 col)))
    (ctl (:bgc #x11111100)
         (:fgc #xbbbbbb00))
    (out (:row row :col 1) str)))

(defun start-display ()
  (with-console (:ios *terminal-io*)
    (show-screen)))


(defun lambda-demo (frame)
  (declare (ignore frame))
  (flet ((ll (row col)
           (or (and (< (abs (- (+ col row) 26)) 2)
                    (<= col 20))
               (< (abs (- (+ (- 40 col) row) 26)) 2))))
    (with-clipping (*buffer* :fn #'ll :r1 2 :r2 11)
      (out (:row (1+ (random 12))
            :col (1+ (random 40))
            :bgc #x00000000
            :fgc #xbb000000)
           (alexandria:random-elt '("X" "O"))))
    (with-clipping (*buffer* :fn (lambda (row col)
                                   (or (= row 1)
                                       (= row 12)
                                       (funcall (complement #'ll) row col))))
      (out (:row (1+ (random 12))
            :col (1+ (random 40))
            :bgc #x00000000
            :fgc (alexandria:random-elt '(#x00444400 #x00444400 #x00664400)))
           (alexandria:random-elt '("+" "-"))))))

(defun noise-demo (frame)
  (loop for row from 1 upto (rows frame)
        do (loop for col from 1 upto (cols frame)
                 do (out (:row row
                          :col col
                          :bgc (alexandria:random-elt `(#x00000000 #x08080800))
                          :fgc (alexandria:random-elt (ap frame)))
                         (alexandria:random-elt '("+" "-"))))))

(defun make-lambda-demo (&rest args)
  (apply #'make-instance 'frame :fn #'lambda-demo :rows 12 :cols 40
         args))

(defun make-noise-demo (&rest args)
  (let ((frame (apply #'make-instance 'frame :fn #'noise-demo args)))
    (unless (ap frame)
      (setf (ap frame) '(#xffff8800 #x88ffff00)))
    (setf (rows frame) (1+ (- (r2 frame) (r1 frame)))
          (cols frame) (1+ (- (c2 frame) (c1 frame))))
    frame))


(defclass animation-frame (frame)
  ((sqr-speed :initarg :sqr-speed :reader sqr-speed)
   (direction :initarg :direction :accessor direction)
   (last-time :initarg :last-time :accessor last-time)
   (current-row :accessor current-row)
   (current-col :accessor current-col)
   (minimum-col :accessor minimum-col)
   (maximum-col :accessor maximum-col))
  (:default-initargs :sqr-speed 5
                     :direction 1
                     :last-time (get-internal-real-time)))

(defmethod initialize-instance :after
    ((frame animation-frame) &rest args)
  (let ((rows (rows frame))
        (cols (cols frame)))
   (setf (current-row frame) (1+ (truncate rows 2))
         (current-col frame) (1+ (truncate cols 2))
         (minimum-col frame) (+ 1    2)
         (maximum-col frame) (- cols 2))))

(defun animation-demo (frame)
  (let* ((rows (rows frame))
         (cols (cols frame))
         (speed (sqr-speed frame))
         (now (get-internal-real-time))
         (delta (/ (- now (last-time frame))
                   internal-time-units-per-second))
         (direction (direction frame))
         (current-col (current-col frame))
         (minimum-col (minimum-col frame))
         (maximum-col (maximum-col frame)))
    ;; Set colors and clear the window background.
    (ctl (:bgc #x44440000)
         (:fgc #xffbb0000)
         (:clr 1 1 rows cols))
    ;; Advance the square.
    (incf current-col (* delta speed direction))
    ;; Draw the rectangle.
    (loop with row = (current-row frame)
          with col = (alexandria:clamp (round current-col)
                                       minimum-col
                                       maximum-col)
          for r from (- row 1) upto (+ row 1)
          do (loop for c from (- col 2) upto (+ col 2)
                   do (out (:row r :col c
                            ;:bgc #xffffff00
                            :fgc #xff00ff00) "#")))
    ;; Update variables
    (setf (current-col frame) current-col
          (direction frame) (cond ((< current-col minimum-col) +1)
                                  ((> current-col maximum-col) -1)
                                  (t direction))
          (last-time frame) now)))

(defun make-animation-demo (&rest args)
  (apply #'make-instance 'animation-frame :fn 'animation-demo args))

(defun make-report-demo (&rest args)
  (flet ((reporter (frame)
           (let ((str "I'd like to report an event here!")
                 (rows (rows frame)))
             (ctl (:bgc #x00000000))
             (clear-rectangle 1 1 rows (cols frame))
             (loop for row from 1 upto rows
                   for id from 0
                   for string = (format nil "XXX ~d/~d: ~a" id (1- rows) str)
                   do (out (:row row :col 1 :fgc #xff888800) string)))))
    (apply #'make-instance 'frame :fn #'reporter args)))
