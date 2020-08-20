(in-package #:eu.turtleware.charming-clim)

(defvar *console*)

(defmacro with-console ((&rest args
                         &key
                           ios
                           (console-class ''console)
                         &allow-other-keys)
                        &body body)
  (remf args :console-class)
  `(let ((*terminal* ,ios)
         (console-class ,console-class))
     (loop
       (restart-case
           (let ((*console* (make-instance console-class ,@args)))
             (handler-case (with-buffer (*console*) ,@body)
               (error (e)
                 (set-mouse-tracking nil)
                 (process-available-events)
                 (close-terminal (hnd *console*))
                 (error e))
               (exit (e)
                 (declare (ignore e))
                 (set-mouse-tracking nil)
                 (process-available-events)
                 (close-terminal (hnd *console*))
                 (return))
               (:no-error (&rest values)
                 (declare (ignore values))
                 (set-mouse-tracking nil)
                 (process-available-events)
                 (close-terminal (hnd *console*))
                 (return))))
         (again ()
           :report "Start display again.")
         (change (new-console-class)
           :report "Change the console class."
           :interactive (lambda ()
                          (format *debug-io* "Type the class symbol:~%")
                          (format *debug-io* "~a> '" (package-name *package*))
                          (finish-output *debug-io*)
                          (list (read)))
           (setf console-class new-console-class))))))

(defclass console (output-buffer)
  ((ios :initarg :ios :accessor ios :documentation "Console I/O stream")
   (cur :initarg :cur :accessor cur :documentation "The terminal cursor"
        :reader direct-cursor)
   (ptr :initarg :ptr :accessor ptr :documentation "The pointer cursor")
   (vrt :initarg :vrt :accessor vrt :documentation "The virtual pointer cursor")
   (hnd               :accessor hnd :documentation "Terminal handler"))
  (:default-initargs :ios (error "I/O stream must be specified.")))

(defmethod initialize-instance :after
    ((instance console) &rest args &key ios
     &aux (*terminal* ios) (*console* instance))
  (setf (hnd instance) (init-terminal))
  (setf (cur instance) (make-instance 'tcursor :cvp t))
  (setf (ptr instance) (make-instance 'pointer :cvp t :cep nil))
  (process-available-events t))

(defmethod flush-output ((buffer console) &rest args &key force)
  (declare (ignore args))
  (let* ((cursor (cur buffer))
         (last-fg (fgc cursor))
         (last-bg (bgc cursor))
         (gap 0))
    (set-cursor-position 1 1)
    (iterate-cells (cell crow ccol wrap-p)
        (buffer 1 1 (make-array (* (cols buffer)
                                   (rows buffer))
                                :displaced-to (data buffer)))
      (when wrap-p
        (set-cursor-position crow ccol)
        (setf gap 0))
      (if (and cell (or force (dirty-p cell)))
          (let ((ch (ch cell))
                (fg (fg cell))
                (bg (bg cell)))
            (unless (= fg last-fg)
              (set-foreground-color fg)
              (setf last-fg fg))
            (unless (= bg last-bg)
              (set-background-color bg)
              (setf last-bg bg))
            (when (plusp gap)
              (cursor-right gap)
              (setf gap 0))
            (put ch)
            (setf (dirty-p cell) nil))
          (if force
              (put #\space)
              (incf gap))))
    (set-cursor-position (row cursor) (col cursor))
    (set-foreground-color (fgc cursor))
    (set-background-color (bgc cursor)))
  (finish-output *terminal*))

(defmethod put-cell ((buf console) str
                     &rest cursor-args
                     &key row col fgc bgc &allow-other-keys)
  (let* ((cur (cur buf))
         (row (or row (row cur)))
         (col (or col (col cur)))
         (fgc (or fgc (fgc cur)))
         (bgc (or bgc (bgc cur))))
    (change-cursor-position cur row col)
    (change-cursor-inks cur fgc bgc)
    (multiple-value-bind (final-row final-col)
        (iterate-cells (ch crow ccol wrap-p)
            (buf row col (string str))
          (when wrap-p
            (change-cursor-position cur crow ccol))
          (if (inside-p buf crow ccol)
              (put ch)
              (cursor-right)))
      (set-row final-row cur)
      (set-col final-col cur))))

(defmethod handle-event ((client console) (event pointer-event))
  (let ((ptr (ptr client))
        (row (row event))
        (col (col event)))
    (change-cursor-position ptr row col)
    (change-cursor-data ptr event)))

(defmethod handle-event ((client console) (event terminal-resize-event))
  (let ((rows (rows event))
        (cols (cols event)))
    (setf (rows client) rows)
    (setf (cols client) cols)
    (setf (r2 (clip client)) rows)
    (setf (c2 (clip client)) cols)
    (adjust-array (data client)
                  (list rows cols)
                  :initial-element nil)))

(defmethod handle-event ((client console) (event keyboard-event))
  (cond ((keyp event #\Q :c)
         (signal 'exit))
        ((keyp event #\E :c)
         (error "HI!"))
        ((keyp event #\S :c)
         (swank:create-server :dont-close t))
        ((keyp event #\R :c)
         (ctl (:ink #xffffffff #x00000000))
         (clear-terminal)
         (process-available-events t))))
