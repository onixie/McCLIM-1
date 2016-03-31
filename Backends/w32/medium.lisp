;;; -*- Mode: Lisp; Package: CLIM-W32 -*-

;;; (c) 2005 Christophe Rhodes (c.rhodes@gold.ac.uk)

;;; This library is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Library General Public
;;; License as published by the Free Software Foundation; either
;;; version 2 of the License, or (at your option) any later version.
;;;
;;; This library is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Library General Public License for more details.
;;;
;;; You should have received a copy of the GNU Library General Public
;;; License along with this library; if not, write to the 
;;; Free Software Foundation, Inc., 59 Temple Place - Suite 330, 
;;; Boston, MA  02111-1307  USA.

(in-package :clim-w32)

(defclass w32-medium (basic-medium)
  ((dc :initform nil
       :accessor w32-medium-dc))
  ;((buffering-output-p :accessor medium-buffering-output-p))
  )

(defmethod (setf medium-text-style) :before (text-style (medium w32-medium))
  (declare (ignore text-style))
  nil)

(defmethod (setf medium-line-style) :before (line-style (medium w32-medium))
  (declare (ignore line-style))
  nil)

(defmethod (setf medium-clipping-region) :after (region (medium w32-medium))
  (declare (ignore region))
  nil)

(defmethod medium-copy-area ((from-drawable w32-medium)
			     from-x from-y width height
                             (to-drawable w32-medium)
			     to-x to-y)
  (declare (ignore from-x from-y width height to-x to-y))
  nil)

#+nil ; FIXME: PIXMAP class
(progn
  (defmethod medium-copy-area ((from-drawable w32-medium)
			       from-x from-y width height
			       (to-drawable pixmap)
			       to-x to-y)
    (declare (ignore from-x from-y width height to-x to-y))
    nil)

  (defmethod medium-copy-area ((from-drawable pixmap)
			       from-x from-y width height
			       (to-drawable w32-medium)
			       to-x to-y)
    (declare (ignore from-x from-y width height to-x to-y))
    nil)

  (defmethod medium-copy-area ((from-drawable pixmap)
			       from-x from-y width height
			       (to-drawable pixmap)
			       to-x to-y)
    (declare (ignore from-x from-y width height to-x to-y))
    nil))

(defmethod medium-draw-point* ((medium w32-medium) x y)
  (declare (ignore x y))
  nil)

(defmethod medium-draw-points* ((medium w32-medium) coord-seq)
  (declare (ignore coord-seq))
  nil)

(defmethod medium-draw-line* ((medium w32-medium) x1 y1 x2 y2)
  (let ((dc (w32-medium-dc medium)))
    (w32api.gdi32::MoveToEx dc (round-coordinate x1) (round-coordinate y1) (cffi:null-pointer))
    (w32api.gdi32::LineTo dc (round-coordinate x2) (round-coordinate y2))))

;; FIXME: Invert the transformation and apply it here, as the :around
;; methods on transform-coordinates-mixin will cause it to be applied
;; twice, and we need to undo one of those. The
;; transform-coordinates-mixin stuff needs to be eliminated.
(defmethod medium-draw-lines* ((medium w32-medium) coord-seq)
  (climi::do-sequence ((x1 y1 x2 y2) coord-seq)
    (medium-draw-line* medium x1 y1 x2 y2)))

(defmethod medium-draw-polygon* ((medium w32-medium) coord-seq closed filled)
  (declare (ignore coord-seq closed filled))
  nil)

(defmethod medium-draw-rectangle* ((medium w32-medium) x1 y1 x2 y2 filled)
  (declare (ignore filled))
  (w32api.gdi32::Rectangle (w32-medium-dc medium) (round-coordinate x1) (round-coordinate y1) (round-coordinate x2) (round-coordinate y2)))

(defmethod medium-draw-rectangles* ((medium w32-medium) position-seq filled)
  (loop for (left top right bottom) on position-seq by #'cddddr
     do (medium-draw-rectangle* medium left top right bottom filled)))

(defmethod medium-draw-ellipse* ((medium w32-medium) center-x center-y
				 radius-1-dx radius-1-dy
				 radius-2-dx radius-2-dy
				 start-angle end-angle filled)
  (declare (ignore filled))
  (w32api.gdi32::ArcTo (w32-medium-dc medium)
		       (round-coordinate (- center-x radius-1-dx))
		       (round-coordinate (- center-y radius-2-dy))
		       (round-coordinate (+ center-x radius-1-dx))
		       (round-coordinate (+ center-y radius-2-dy))
		       (round-coordinate (* (+ center-x radius-1-dx) (cos start-angle)))
		       (round-coordinate (* (+ center-y radius-2-dy) (sin start-angle)))
		       (round-coordinate (* (+ center-x radius-1-dx) (cos end-angle)))
		       (round-coordinate (* (+ center-y radius-2-dy) (sin end-angle)))))

(defmethod medium-draw-circle* ((medium w32-medium)
				center-x center-y radius start-angle end-angle
				filled)
  (declare (ignore filled))
  (w32api.gdi32::AngleArc (w32-medium-dc medium)
			  (round-coordinate center-x)
			  (round-coordinate center-y)
			  (round-coordinate radius)
			  (round-coordinate start-angle)
			  (round-coordinate (- start-angle end-angle))))

(defmethod text-style-ascent (text-style (medium w32-medium))
  (declare (ignore text-style))
  1)

(defmethod text-style-descent (text-style (medium w32-medium))
  (declare (ignore text-style))
  1)

(defmethod text-style-height (text-style (medium w32-medium))
  (+ (text-style-ascent text-style medium)
     (text-style-descent text-style medium)))

(defmethod text-style-character-width (text-style (medium w32-medium) char)
  (declare (ignore text-style char))
  1)

;;; FIXME: this one is nominally backend-independent
(defmethod text-style-width (text-style (medium w32-medium))
  (text-style-character-width text-style medium #\m))

(defmethod text-size
    ((medium w32-medium) string &key text-style (start 0) end)
  (setf string (etypecase string
		 (character (string string))
		 (string string)))
  (let ((width 0)
	(height (text-style-height text-style medium))
	(x (- (or end (length string)) start))
	(y 0)
	(baseline (text-style-ascent text-style medium)))
    (do ((pos (position #\Newline string :start start :end end)
	      (position #\Newline string :start (1+ pos) :end end)))
	((null pos) (values width height x y baseline))
      (let ((start start)
	    (end pos))
	(setf x (- end start))
	(setf y (+ y (text-style-height text-style medium)))
	(setf width (max width x))
	(setf height (+ height (text-style-height text-style medium)))
	(setf baseline (+ baseline (text-style-height text-style medium)))))))

(defmethod climi::text-bounding-rectangle*
    ((medium w32-medium) string &key text-style (start 0) end)
  (text-size medium string :text-style text-style :start start :end end))

(defmethod medium-draw-text* ((medium w32-medium) string x y
                              start end
                              align-x align-y
                              toward-x toward-y transform-glyphs)
  (declare (ignore start end
		   align-x align-y
		   toward-x toward-y transform-glyphs))
  (w32api.gdi32::TextOutW (w32-medium-dc medium) (round-coordinate x) (round-coordinate y) string (length string)))

#+nil
(defmethod medium-buffering-output-p ((medium w32-medium))
  t)

#+nil
(defmethod (setf medium-buffering-output-p) (buffer-p (medium w32-medium))
  buffer-p)

(defmethod medium-draw-glyph ((medium w32-medium) element x y
			      align-x align-y toward-x toward-y
			      transform-glyphs)
  (declare (ignore element x y
		   align-x align-y toward-x toward-y
		   transform-glyphs))
  nil)

(defmethod medium-finish-output ((medium w32-medium))
  nil)

(defmethod medium-force-output ((medium w32-medium))
  nil)

(defmethod medium-clear-area ((medium w32-medium) left top right bottom)
  (declare (ignore left top right bottom))
  nil)

(defmethod medium-beep ((medium w32-medium))
  nil)

(defmethod invoke-with-special-choices (continuation (medium w32-medium))
  (let ((sheet (medium-sheet medium)))
    (funcall continuation (sheet-medium sheet))))

(defmethod medium-miter-limit ((medium w32-medium))
  0)

;;; FIXME: need these to stop the default method attempting to do
;;; pixmaps, which it appears the null backend doesn't support yet.
(defmethod climi::medium-draw-bezier-design* 
    ((medium w32-medium) (design climi::bezier-area))
  nil)
(defmethod climi::medium-draw-bezier-design* 
    ((medium w32-medium) (design climi::bezier-union))
  nil)
(defmethod climi::medium-draw-bezier-design* 
    ((medium w32-medium) (design climi::bezier-difference))
  nil)
