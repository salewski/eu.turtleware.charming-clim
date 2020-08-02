(defpackage #:eu.turtleware.charming-clim/l0
  (:export #:init-terminal
           #:close-terminal
           #:*terminal*

           #:put #:esc #:csi #:sgr
           #:read-input #:keyp

           #:reset-terminal
           #:clear-terminal

           #:clear-line
           #:reset-text-style
           #:set-foreground-color
           #:set-background-color
           #:set-text-style

           #:with-cursor-position
           #:set-cursor-position
           #:save-cursor-position
           #:restore-cursor-position

           #:cursor-up
           #:cursor-down
           #:cursor-right
           #:cursor-left

           #:set-cursor-visibility
           #:set-mouse-tracking

           #:*request-terminal-size*
           #:request-cursor-position

           #:event
           #:terminal-event
           #:unknown-terminal-event #:seq
           #:cursor-position-event #:row #:col
           #:terminal-resize-event #:rows #:cols
           #:keyboard-event #:key #:kch #:mods
           #:pointer-event #:row #:col #:btn #:mods #:state
           #:pointer-motion-event
           #:pointer-press-event
           #:pointer-release-event))

(defpackage #:eu.turtleware.charming-clim/l1
  (:export #:*console* #:*buffer*)
  (:export #:with-console #:with-buffer #:out #:ctl)
  (:export #:process-available-events #:exit)
  (:export #:console #:surface #:handle-event #:handle-repaint))

(defpackage #:eu.turtleware.charming-clim/l2
  (:export))

(defpackage #:eu.turtleware.charming-clim
  (:use #:common-lisp
        #:eu.turtleware.charming-clim/l0
        #:eu.turtleware.charming-clim/l1
        #:eu.turtleware.charming-clim/l2))
