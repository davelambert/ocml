;;; Namespace support for OCML.
;;;
;;; Copyright (C) 2007, 2008 The Open University.
;;;
;;; Authored by Dave Lambert

;;; We use symbol munging to implement namespaces, not package
;;; manipulation.  Although the Lisp symbol "foo:bar" looks like the
;;; XML element "<foo:bar>", they're fundamentally different.  In XML,
;;; the namespaces mapped to from the various prefixes can, and do,
;;; change, even within the same document.  In Lisp, the package name
;;; is forever, and we can't have that: if two sources were to use the
;;; same prefix, they must use it for the *same ontology*, and that
;;; simply isn't what we need.

(in-package :ocml)


;;; Should be the chars acecptable in a an XML/RDF/OWL token.
(define-constant +token-chars+
    (concatenate 'list "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
  "Legal characters in a namespaced symbol's 'local name'.")

(define-constant +valid-whitespace+
    (list #\space #\return #\linefeed #\tab #\( #\) #\' #\` #\")
  "Characters which can legitimately follow a valid token.")

(define-constant +namespace-separator+ #\:)

(defun register-namespace (prefix namespace)
  (check-type prefix string)
  (check-type namespace (or string symbol))
  (setf (prefix->uri prefix)
        (if (symbolp namespace)
            (namespace-uri-of
             (get-ontology namespace :error-if-not-found t))
            namespace)))

(defun assumed-namespace-uri (ontology-name)
  "Generate a unique namespace for ontologies which don't explicitly declare one."
  (format nil "http://www.kmi.open.ac.uk/projects/ocml/namespaces/assumed/~A#"
          ontology-name))

(defun ocml-encode-symbol (symbol-name)
  (check-type symbol-name string)
  (intern symbol-name :ocml))

(defun read-wsml-identifier (stream char1 char2)
  (declare (ignore char1 char2))
  (let ((iri (char= #\" (peek-char nil stream))))
    (ocml-encode-symbol (if iri
			    (read stream)
			    (read-ocml-symbolic-thing stream)))))

(defun read-ocml-symbolic-thing (stream)
  (flet ((peek ()
	   (peek-char  nil  stream  nil :eof)))
    (let (char chars prefix)
      (loop (setf char (peek))
	 (cond ((eq char :eof)
		(return))
	       ((char= +namespace-separator+ char)
		(when prefix
		  (error "Multiple namespace prefixes found: \"~A\" and \"~A\"."
			 prefix (concatenate 'string (reverse chars))))
		(setf prefix (concatenate 'string (reverse chars)))
		(setf chars '())
		(read-char stream))
               ((member char +valid-whitespace+) (return))
	       ((not (ocml-token-char? char))
                (error "Illegal character '~S' in OCML token '~A'."
                       char (concatenate 'string (reverse chars))))
	       (t (push char chars)
		  (read-char stream))))
      ;; If there's a prefix, check it's valid, map it to an ontology.
      ;; If there's no prefix, use *CURRENT-ONTOLOGY*.
      (let ((namespace (if prefix
                           (or (prefix->uri prefix)
                               (error "Unrecognised namespace prefix \"~A\"."
                                      prefix))
                           (namespace-uri-of *current-ontology*)))
	    (symbol (concatenate 'string (reverse chars))))
	(format nil "~A~A" namespace symbol)))))

(defun ocml-token-char? (char)
  (member char +token-chars+))

(defun prefix->uri (prefix)
  "Lookup the namespace IRI that PREFIX currently maps to."
  (cdr (assoc prefix *namespace-prefixes* :test #'string=)))

(defun (setf prefix->uri) (iri prefix)
  (let ((pair (assoc prefix *namespace-prefixes* :test #'string=)))
    (if pair
	(setf (cdr pair) iri)
	(push (cons prefix iri) *namespace-prefixes*)))
  prefix)

(defun merge-included-namespaces (ontologies)
  "Calculate the prefixes to be used in an ontology including
ONTOLOGIES."
  ;; If a namespace has more than one prefix, we just choose the first
  ;; one.  If a prefix refers to more than one namespace, we alter the
  ;; prefixes to be unique.
  (let ((unique-number 0)
        (*namespace-prefixes* '())
        (mappings (apply #'append (mapcar (lambda (o) (namespaces-of (get-ontology o)))
                                          ontologies))))
    (format t "mappings: ~A~%" mappings)
    (dolist (map mappings)
      (let ((prefix (first map))
            (namespace (let ((ns (second map)))
                         (if (symbolp ns)
                             (namespace-uri-of (get-ontology ns))
                             ns))))
        (unless (member namespace *namespace-prefixes* :key #'cdr)
          (when (member prefix *namespace-prefixes* :key #'car)
            (setf prefix (format nil "~A~A" prefix (incf unique-number))))
          (register-namespace prefix namespace))))
    *namespace-prefixes*))

(eval-when (:load-toplevel :execute)
  (set-dispatch-macro-character #\# #\_ #'read-wsml-identifier))
