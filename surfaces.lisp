(in-package #:eu.turtleware.charming-clim)

(defclass surface (vbuffer)
  ((vbuf :initarg :vbuf :accessor vbuf :documentation "Underlying vbuffer")
   (row0 :initarg :row0 :accessor row0 :documentation "Scroll row offset")
   (col0 :initarg :col0 :accessor col0 :documentation "Scroll col offset")
   (r1 :initarg :r1 :accessor r1 :documentation "Displacement row offset")
   (c1 :initarg :c1 :accessor c1 :documentation "Displacement col offset")
   (r2 :initarg :r2 :accessor r2 :documentation "Fill pointer row")
   (c2 :initarg :c2 :accessor c2 :documentation "Fill pointer col"))
  (:default-initargs :vbuf (error "VBuf is obligatory")
                     :clip nil
                     :row0 0
                     :col0 0))

(defmethod initialize-instance :after
    ((buf surface) &key r1 c1 r2 c2 rows cols)
  (unless rows
    (setf rows (1+ (- r2 r1)))
    (setf (rows buf) rows))
  (unless cols
    (setf cols (1+ (- c2 c1)))
    (setf (cols buf) cols))
  (setf (clip buf) (make-instance 'vclip :r2 rows :c2 cols)
        (data buf) (make-array (list rows cols)
                               :adjustable t
                               :initial-element nil)))

(defmethod put-cell ((buf surface) row col)
  (let* ((vrow (1- (+ (r1 buf) (- (row0 buf)) row)))
         (vcol (1- (+ (c1 buf) (- (col0 buf)) col)))
         (cell (get-cell buf row col)))
    (when (and (<= (r1 buf) vrow (r2 buf))
               (<= (c1 buf) vcol (c2 buf)))
      (set-cell (vbuf buf) vrow vcol (ch cell) (fg cell) (bg cell)))
    (setf (dirty-p cell) nil)))

(defmethod flush-buffer ((buffer surface) &key r1 c1 r2 c2 force)
  (loop for row from 1 upto (rows buffer)
        do (loop for col from 1 upto (cols buffer)
                 do (put-cell buffer row col))))

(defun move-to-row (buf row0)
  (let* ((rows (rows buf))
         (height (1+ (- (r2 buf) (r1 buf))))
         (vrow1 (- 1    row0))
         (vrow2 (- rows row0)))
    (when (if (> height rows)
              (and (<= 1 vrow1 height)
                   (<= 1 vrow2 height))
              (and (<= vrow1 1)
                   (>= vrow2 height)))
      (setf (row0 buf) row0))))

(defun move-to-col (buf col0)
  (let* ((cols (cols buf))
         (width (1+ (- (c2 buf) (c1 buf))))
         (vcol1 (- 1    col0))
         (vcol2 (- cols col0)))
    (when (if (> width cols)
              (and (<= 1 vcol1 width)
                   (<= 1 vcol2 width))
              (and (<= vcol1 1)
                   (>= vcol2 width)))
      (setf (col0 buf) col0))))

(defun scroll-buffer (buf row-dx col-dx)
  (flet ((quantity (screen-size buffer-size dx)
           (if (alexandria:xor (> screen-size buffer-size)
                               (minusp dx))
               0
               (- buffer-size screen-size))))
    (unless (zerop row-dx)
      (let ((height (1+ (- (r2 buf) (r1 buf)))))
        (or (move-to-row buf (+ (row0 buf) row-dx))
            (setf (row0 buf)
                  (quantity height (rows buf) row-dx)))))
    (unless (zerop col-dx)
      (let ((width (1+ (- (c2 buf) (c1 buf)))))
        (or (move-to-col buf (+ (col0 buf) col-dx))
            (setf (col0 buf)
                  (quantity width (cols buf) col-dx)))))))
