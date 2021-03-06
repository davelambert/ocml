;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Package: ocml;   -*-

(in-package "OCML")

;;;This file contains the code which handles the communication between the obj/relation
;;;part of ocml and the forward chainer 


;;;TELL-FC-RULES --Tells FC that a new fact has been asserted
(defun tell-fc-rules (predicate args)
  (mapc #'(lambda (node)
              (run-alpha-test  node args))
          (fc-nodes (get-relation predicate))))

 ;;;; (maybe-trigger-downward-add-exp predicate args))

 ;;; (maybe-trigger-downward-mapping-rule predicate ))
  ;;;(maybe-trigger-reflection-rules))
    


;;;UNASSERT-FROM-FC-RULES ---The opposite of tell-fc-rules
(defun unassert-from-fc-rules (predicate args)
  (when (tracing-this-assertion? (cons predicate args))
              (print-with-spaces (1+ *task-level*)
                                 "Unasserting ~S" (cons predicate args)))
  (mapc #'(lambda (node)
	    (remove-wm-pattern-from-rete  node args))
	(fc-nodes (get-relation predicate))))

  ;;;;;(maybe-trigger-downward-remove-exp predicate args))



;;;TELL-SLOT-VALUES-TO-FC-RULES---Informs fc about the new values of a slot.
(defun tell-slot-values-to-fc-rules (slot name values
                                          &optional (ontology
                                                     *current-ontology*))
  (Let* ((relation (if (eq ontology *current-ontology*)
                     (get-relation slot)
                     (get-relation-from-ontology slot ontology)))
         (nodes (fc-nodes relation))
         (indirect-nodes (indirect-fc-nodes relation)))
    (when nodes
      (loop for value in values
            do
            (loop for node in nodes
                  do
                  (run-alpha-test  node (list name value)))))
    (when indirect-nodes
      (loop for node in indirect-nodes
            do
            (match-alpha-node-against-possible-instance node name slot
                                                        values)))))

  ;;;;(maybe-trigger-downward-add-exp slot name values))
  ;;;;;(maybe-trigger-downward-mapping-rule slot))
  ;;;;(maybe-trigger-reflection-rules))

;;;REMOVE-SLOT-VALUES-FROM-FC-RULES 
(defun remove-slot-values-from-fc-rules (slot name values &optional (ontology
                                                                     *current-ontology*))
  (Let* ((relation (if (eq ontology *current-ontology*)
                     (get-relation slot)
                     (get-relation-from-ontology slot ontology)))
         (nodes (fc-nodes relation))
         (indirect-nodes (indirect-fc-nodes relation)))
    (when nodes
      (loop for value in values
            do
            (loop for node in nodes
                  do
                  (remove-wm-pattern-from-rete  node (list name value)))))
    (when indirect-nodes
      (loop for node in indirect-nodes
            do
            (match-alpha-node-against-possible-instance node name slot values :remove)))))

;;; Called when a new instance is created.
(defun tell-fc-new-instance (instance parent)
  (let ((name (name instance))
        (fc-nodes (fc-nodes (get-relation parent))))
    (dolist (node fc-nodes)
      (match-alpha-node-against-instance node instance))
    (dolist (slot (domain-slots instance))
      (dolist (value (get-slot-values instance slot))
        (dolist (node (fc-nodes (get-relation slot)))
          (run-alpha-test node (list name value)))))))

;;;REMOVE-ALL-INSTANCE-INFO-FROM-FC-RULES ---Called when an instance is deleted.
(defmethod remove-all-instance-info-from-fc-rules ((instance basic-domain-class)parent)
  
  (with-slots (name) instance
    (when (tracing-this-assertion? (list parent name))
              (print-with-spaces (1+ *task-level*)
                                 "Removing instance ~s of class ~s" 
                                 name parent))
      (loop with relation = (get-relation parent)
            with fc-nodes = (fc-nodes relation)
            for node in fc-nodes
            for pattern = (alpha-node-pattern node)
            for env = (match name (car pattern))
            do
            (unless (eq env :fail)
              (maybe-remove-instance-spec-inputs node name)))
      (loop for slot in (domain-slots instance)
            do
            (loop for value in (get-slot-values instance slot)
                  do
                  (loop for node in (fc-nodes (get-relation slot))
                        do
                        (remove-wm-pattern-from-rete  node (list name value)))))))

(defun run-fc-rules (&optional (packets :all))
  "Run the forward-chainer rules."
  (let ((rules (merge-rules (if (eq packets :all)
                                (all-rule-packets)
                                (mapcar #'get-rule-packet packets)))))
    (compile-fc-rules rules)
    (do-interpreter-cycle rules)))

;;;UNASSERT-CLASS-SLOTS-FROM-ALL-INSTANCES ----
;;;This function is called when a domain class is redefined, to ensure that
;;;all slot info for the local slots of the class is removed from the rule
;;;system before the class redefinition destroys this information.
;;;  The class
;;;redefinition code should also ensure that the new information added by the
;;;class redefinition is passed to the rule system.  
;(defun unassert-class-slots-from-all-instances (class slots-to-recompute)
;  (loop for instance in (get-all-instances        ;;This gets ALL instances, 
;                         class)                   ;;not just the direct ones.
;	do
;	(loop for slot in slots-to-recompute
;	      for values = (get-slot-values instance slot)
;	      when values
;	      do
;	      (unassert-slot-values-from-fc-rules slot (name instance) values))))

;;;UPDATE-FC-INSTANCE-OF-LINKS ---When a class is redefined, this function is called
;;;to remove the obsolete instance-of links and add the new one.
;;;NOT USED ANYMORE
;(defun update-fc-instance-of-links (name  new-supers lost-supers)
;  (dolist (super new-supers)
;    (tell-fc-rules super (list name)))
;  (dolist (super lost-supers)
;    (unassert-from-fc-rules super (list name))))

;;;NEW-FC-RULE
;(defun new-fc-rule (rule if-part then-part )()
;  (compile-fc-rule rule if-part then-part))

