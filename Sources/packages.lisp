(defpackage #:eu.turtleware.charming-clim/ll
  (:export #:init-terminal
           #:close-terminal
           #:*terminal*

           #:put #:esc #:csi #:sgr
           #:read-input #:keyp

           #:reset-terminal
           #:clear-terminal

           #:clear-line
           #:set-foreground-color
           #:set-background-color

           #:with-cursor-position
           #:set-cursor-position
           #:save-cursor-position
           #:restore-cursor-position
           #:request-cursor-position

           #:cursor-up
           #:cursor-down
           #:cursor-right
           #:cursor-left

           #:set-cursor-visibility
           #:set-mouse-tracking))

(defpackage #:eu.turtleware.charming-clim/hl
  (:export #:with-console #:out #:ctl))

(defpackage #:eu.turtleware.charming-clim
  (:use #:common-lisp
        #:eu.turtleware.charming-clim/ll
        #:eu.turtleware.charming-clim/hl))