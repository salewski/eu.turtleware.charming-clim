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
    ((instance console) &rest args &key ios fgc bgc
     &aux (*terminal* ios) (*console* instance))
  (declare (ignore args))
  (setf (hnd instance) (init-terminal))
  (setf (cur instance) (make-instance 'tcursor :cvp nil :fgc fgc :bgc bgc))
  (setf (ptr instance) (make-instance 'pointer :cvp t :cep t))
  (process-available-events t))

;;; Cursors are showed after flushing output and they are presented in direct
;;; mode, so they don't modify the actual buffered cell. When we move cursor
;;; we want to "see" its previous content.
(defun show-cursors (console)
  (let* ((ptr (ptr console))
         (row (row ptr))
         (col (col ptr))
         (txt (txt ptr))
         (chr (chr (get-cell console row col))))
    (letf (((mode console) :dir))
      (out (:row row :col col :txt txt :fgc #xff0000ff)
           (if (char= chr #\space)
               #\X
               chr)))))

(defmethod flush-output ((buffer console) &rest args &key force)
  (declare (ignore args))
  (let* ((cursor (cur buffer))
         (last-fgc (fgc cursor))
         (last-bgc (bgc cursor))
         (last-txt (txt cursor))
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
          (let ((chr (chr cell))
                (fgc (fgc cell))
                (bgc (bgc cell))
                (txt (txt cell)))
            (unless (= fgc last-fgc)
              (set-foreground-color fgc)
              (setf last-fgc fgc))
            (unless (= bgc last-bgc)
              (set-background-color bgc)
              (setf last-bgc bgc))
            (alexandria:when-let ((diff (text-style-diff txt last-txt)))
              (set-text-style diff)
              (setf last-txt txt))
            (when (plusp gap)
              (cursor-right gap)
              (setf gap 0))
            (put chr)
            (setf (dirty-p cell) nil))
          (if force
              (put #\space)
              (incf gap))))
    (set-cursor-position (row cursor) (col cursor))
    (set-foreground-color (fgc cursor))
    (set-background-color (bgc cursor))
    (set-text-style (txt cursor))
    (show-cursors buffer))
  (finish-output *terminal*))

(defmethod put-cell ((buf console) str &rest cursor-args)
  (let* ((cur (cur buf)))
    (apply #'update-pen cur cursor-args)
    (iterate-cells (chr crow ccol wrap-p)
        (buf (row cur) (col cur) (string str))
      (when wrap-p
        (set-cursor-position crow ccol))
      (if (inside-p buf crow ccol)
          (put chr)
          (cursor-right)))
    (set-cursor-position (row cur) (col cur))))

(defmethod handle-event :before ((client console) (event pointer-event))
  (let ((ptr (ptr client))
        (row (row event))
        (col (col event)))
    (change-cursor-position ptr row col)
    (change-cursor-data ptr event)))

(defmethod handle-event :before ((client console) (event terminal-resize-event))
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
