;;; Copyright Open University 2008.

(in-package #:ocml)

;;; A collection of random bits that the rest of OCML is built upon.

;;; {{{ name-mixin
(defclass name-mixin ()
  ((name :initarg :name :accessor name)
   (pretty-name :initarg :pretty-name :accessor pretty-name :initform nil)))

(defmethod generate-name ((named-obj  name-mixin))
  (gentemp (string (type-of named-obj))))

;;;INITIALIZE-INSTANCE :AROUND NAME-MIXIN  ---If no name is provided, we generate one
;;;ourselves
(defmethod initialize-instance :around ((named-obj name-mixin) &rest initargs)
  (unless (or (member :name  initargs)
              (slot-boundp named-obj 'name))
    (setf initargs (append (list :name (generate-name named-obj))
                         initargs)))
  (apply #'call-next-method (cons named-obj  initargs)))
;;; }}}
;;; {{{ ontology-mixin
(defclass ontology-mixin ()
  ((home-ontology :initform *current-ontology* :accessor home-ontology))
  (:documentation "A simple mixin so that each ocml object knows its home ontology."))
;;; }}}
;;; {{{ basic-ocml-object
(defclass basic-ocml-object (documentation-mixin ontology-mixin)
  ())
;;; }}}
;;; {{{ lisp-attachment-mixin
(defclass lisp-attachment-mixin ()
  ((user-defined?       ;;It this flag is t, then the lisp code is user-supplied code,
    :initform nil       ;;otherwise it has been generated by the compiler
    :reader user-defined?) 
   (printable-lisp-fun :initform nil)
   (lisp-fun :initarg :lisp-fun :initform nil :accessor lisp-fun))
  (:documentation "A mixin for OCML objects which have some sort of lisp `semantics'"))

(defmethod initialize-instance :after ((obj lisp-attachment-mixin) &rest initargs)
  (declare (ignore initargs))
  (with-slots (lisp-fun printable-lisp-fun)obj
    (when lisp-fun
      (setf printable-lisp-fun lisp-fun
            lisp-fun (compile-attachment lisp-fun)))))

(defun compile-attachment (fun &optional (prefix "G"))
  (setf fun (eval fun))
  (if (compiled-function-p fun)
      fun
    #-franz-inc
    (compile (gensym (string prefix)) ;;;(if prefix (gentemp prefix)(gensym))
	     fun)
    #+franz-inc
    (compile (gensym (string prefix)) ;;;(if prefix (gentemp prefix)(gensym))
	     (if (excl::function-object-p fun)
		 (excl::func_code fun)
	       fun))))
;;; }}}
;;; {{{ documentation-mixin

(defclass documentation-mixin ()
  ((documentation :initarg :documentation :initform nil))
  (:documentation "A class specifying the basic properties which are
  common to all OCML objects."))

;;;Use this function to get the documentation of any type of OCML entity.
;;;The function documentation is not guaranteed to work on all lisp platforms!!!!!
(defmethod ocml-documentation ((obj documentation-mixin) &optional doc-type)
  (declare (ignore doc-type))
  (with-slots (documentation) obj
    documentation))

(defmethod (setf ocml-documentation) (new-value (obj documentation-mixin) &optional doc-type)
  (declare (ignore doc-type))
  (with-slots (documentation) obj
    (setf documentation new-value)))
;;; }}}
