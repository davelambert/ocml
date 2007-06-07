;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Package: ocml;   -*-

(in-package "OCML")

(defclass name-mixin ()
  ((name :initarg :name :accessor name)))


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


;;;LISP-ATTACHMENT-MIXIN
(defclass lisp-attachment-mixin ()
  ((user-defined?       ;;It this flag is t, then the lisp code is user-supplied code,
    :initform nil       ;;otherwise it has been generated by the compiler
    :reader user-defined?) 
   (lisp-fun :initarg :lisp-fun :initform nil :accessor lisp-fun))
  (:documentation "A mixin for OCML objects which have some sort of lisp `semantics'"))

(defmethod initialize-instance :after ((obj lisp-attachment-mixin) &rest initargs)
  (declare (ignore initargs))
  (with-slots (lisp-fun)obj
    (when lisp-fun
      (setf lisp-fun (compile-attachment lisp-fun))))) ;;;;;(eval lisp-fun))))

(defun compile-attachment (fun &optional (prefix "G"))
  (setf fun (eval fun))
  (if (compiled-function-p fun)
      fun
      (compile (gensym (string prefix)) ;;;(if prefix (gentemp prefix)(gensym))
               fun)))


;;;;;*********************************************************************
(defclass documentation-mixin ()
  (
   (documentation :initarg :documentation :initform nil))
  (:documentation "A class specifying the basic properties which are common to all
                   ocml objects"))


(defmethod documentation ((obj documentation-mixin)&optional doc-type)
  (declare (ignore doc-type))
  (with-slots (documentation )obj
    documentation))

(defmethod (setf documentation) (new-value (obj documentation-mixin)&optional doc-type)
  (declare (ignore doc-type))
  (with-slots (documentation )obj
    (setf documentation new-value)))

;;;;;*********************************************************************

(defclass ontology-mixin ()
  ((home-ontology :initform *current-ontology* :accessor home-ontology))
  (:documentation "A simple mixin so that each ocml object knows its home ontology"))


;;;;;*********************************************************************

;;;BASIC-OCML-OBJECT
(defclass basic-ocml-object (documentation-mixin ontology-mixin)())

;;;;;*********************************************************************


;(defclass onto-spec-mixin ()
;  ((onto-spec :initarg :onto-spec)
;   )
;  (:documentation "A class providing slots and methods for those ocml objects which
;                   contain additional information about translating to ontolingua"))
  
  
;;;;;*********************************************************************

(defvar *defined-relations* (make-hash-table) "All defined relation types")


(defun add-to-relations-directory (name instance)
  (setf (gethash name *defined-relations*) instance))

(defun remove-all-relations ()
  (clrhash *defined-relations*))

(defun get-relation (name)
  (gethash name *defined-relations*))

(defun remove-relation-internal (name)
  (remhash name *defined-relations*))

(defun all-relations ()
  "Returns all names of relations"
  (map-over-hash-table #'(lambda (name structure)
                           structure ;;ignore
                           name)
                       *defined-relations*))


;;;RELATION 
(defclass ocml-relation (name-mixin lisp-attachment-mixin ;;;;;onto-spec-mixin
                                    basic-ocml-object)
  ((arity :initarg :arity :initform nil :accessor arity)
   (schema :initarg :schema :initform nil :accessor schema )
   (constraint :initarg :constraint :initform nil)
   (def :initarg :def :initform nil)
   (sufficient :initarg :sufficient  :initform nil :accessor sufficient)
   (iff-def :initarg :iff-def :initform nil :accessor iff-def)
   (own-slots :initarg :own-slots  :initform nil)
   (prove-by  :initarg :prove-by :initform nil :accessor prove-by)
   (no-op :initarg :no-op :initform nil)
   (axiom-def :initarg :axiom-def  :initform nil)
   (relation-instances :initform nil :accessor relation-instances)
   (upward-mapping? :initform nil :accessor upward-mapping?)
   (downward-add-exp :initform nil
		     :accessor downward-add-exp)
   (downward-remove-exp :initform nil
                        :accessor downward-remove-exp)
   (slot-of :accessor slot-of       ;This is a list of classes which have a local or inherited slot
            :initform nil)          ;with the same name as this relation
   (defined-by-rule :initform nil
                    :accessor defined-by-rule)
   (cache-values? :initarg :cache-values? :initform nil
                  :accessor cache-values?)            ;Cache the queries if t
   (cache-table :initform nil :accessor relation-cache-table) 
   (fc-nodes :initform nil :accessor fc-nodes )
   (indirect-fc-nodes :initform nil
                      ;;This entry only makes sense if the relation is a slot. If this is the case,
                      ;;say relation is sloti, then this entry contains a reference to all alpha nodes
                      ;;such as (<class> <x> .........<sloti> <value>....)
                      :accessor indirect-fc-nodes)
   (lisp-slots        ;;;The name of the lisp class implementing  an
    :initarg :lisp-slots)
   (lisp-class-name             ;;;The name of the lisp class implementing  an
    :initarg :lisp-class-name)) ;;;OCML class.  Only used to avoid parsing the relation spec
  (:documentation "The class of relations in OCML"))

(defun schema? (thing)
  (and (listp thing)
       (every #'variable? thing)
       (equal (remove-duplicates thing) thing)))

(defun kappa-exp? (thing)
  (and (listp thing)
       (eq (car thing) 'kappa)
       (schema? (second thing))
       (listp (third thing))))

;(defmacro define-relation-internal (name schema documentation &rest options)
 ; (multiple-value-bind (name schema documentation options)
;      (parse-define-relation-form name schema documentation options)
;   `(funcall #'make-ocml-relation ',name :schema ',schema :documentation  ,documentation
;	      ,@(mapcar #'(lambda (x)
;                            (list 'quote x))
;			options))))

(defun define-relation-internal (name schema documentation options)
  (multiple-value-bind (name schema documentation options)
                       (parse-define-relation-form name schema documentation options)
    (prog1 
      (apply #'make-ocml-relation name :schema schema :documentation  documentation
             options
             )
      (record-source-file name 'ocml-relation))))
       
(defun rename-relation (old-name new-name)
  (let ((relation (get-relation old-name)))
    (with-slots (relation-instances  
                 upward-mapping? downward-add-exp downward-remove-exp 
                 slot-of defined-by-rule fc-nodes)
                relation
      (if relation
        (if (can-rename-relation? relation)
          (let ((class (get-ocml-class old-name)))
            (if class
              (ocml-warn 
               "Can't rename a relation associated with a class...the class needs to be renamed first")
              (rename-relation-internal relation old-name new-name)))
          (cond 
           (relation-instances
            (ocml-warn "Cannot rename relation ~s: associated facts must be removed first"
                       old-name))
           (slot-of
            (ocml-warn 
             (string-append "Cannot rename relation ~s, which is a slot of classes ~s."
                            " These classes need to be deleted first")
             old-name slot-of))
           (defined-by-rule
             (ocml-warn "Cannot rename relation ~s: associated backward rules must be removed first"
                        old-name))
           (fc-nodes
            (ocml-warn "Cannot rename relation ~s: associated forward rules must be removed first"
                       old-name))
           ((or upward-mapping? downward-add-exp downward-remove-exp)
            (ocml-warn "Cannot rename relation ~s without losing the associated mappings"
                       old-name))
           (t
            (error "Internal error"))))
        (error "Relation ~s does not exist" old-name)))))


(defun rename-relation-internal (relation old-name new-name)
  (setf (name relation) new-name)
  (remove-relation-internal old-name)
  (add-to-relations-directory new-name relation))
  
(defmethod can-rename-relation? ((relation ocml-relation))
  (with-slots (relation-instances  
                upward-mapping? downward-add-exp downward-remove-exp 
                slot-of defined-by-rule fc-nodes)
              relation
    (not (or relation-instances  
                upward-mapping? downward-add-exp downward-remove-exp 
                slot-of defined-by-rule fc-nodes))))

(defmethod print-object ((obj ocml-relation)stream)
  (with-slots (name) obj
  (format stream "<OCML-RELATION ~S>" name)))

(defun make-ocml-relation (rel &rest options )
  (when (get-relation rel)
    (ocml-warn "Redefining relation ~S" rel))
  (let ((instance (apply #'make-instance
                         'ocml-relation
                         :name rel
                         options)))
    (maybe-process-sufficient-&-iff-def-entries instance)
    instance))


;;; ADD-RELATION-SPEC ---This is called when additional information about an
;;;existing relation is generated by a class definition, which needs to be added to
;;;the existing relation object.  
(defun add-relation-spec (rel-instance instance-var  
                                       &key def axiom-def constraint sufficient iff-def 
                                       lisp-fun no-op prove-by own-slots
                                       lisp-class-name lisp-slots)
  (declare (ignore  lisp-class-name lisp-slots))
  (let ((c  constraint)
        (s sufficient)
        (l lisp-fun)
        (ax axiom-def)
        (d def)
        (o own-slots)
        (i iff-def)
        (p prove-by)
        (n no-op)
        (flag (or constraint sufficient iff-def prove-by)))
    (when (and flag
               (not instance-var))
      (error "Instance variable not specified for class ~S.  It is needed to understand options ~{~s~}"
             (name rel-instance) (append (when c
                       (list :constraint c))
                     (when s
                       (list                       
                        :sufficient s)))))
    (with-slots (schema name constraint sufficient iff-def lisp-fun no-op prove-by def axiom-def
                        own-slots) 
                rel-instance
      (when (and flag (or constraint sufficient iff-def)
                 (not (eq (car schema)instance-var)))
        ;;If we get here it means that we are mixing :constraint/:iff-def/:sufficient options
        ;;which is not allowed (basically because I should make sure that the relation schema
        ;;is consistent with both specs, which is too much work).
        (error
         "Options ~s are based on a different schema from the one used by existing spec of relation ~S"
	 (append (when c
                   (list :constraint c))
                 (when s
                   (list                       
                    :sufficient s))
                 (when i
                   (list                       
                    :iff-def i))
                 (when p
                   (list                       
                    :prove-by p)))
         name))
      (when instance-var
        (setf schema (list instance-var)))
      (when c
        (setf constraint  c))
      (when s
        (setf sufficient s))
      (when i
        (setf iff-def i))
      (when ax
        (setf axiom-def ax))
      (when d
        (setf def d))
      (when p
        (setf prove-by p))
      (when o
        (set-own-slots rel-instance own-slots o))
        
      (when n
        (setf no-op n))
      (when l
        (setf lisp-fun (compile-attachment l)))
      (maybe-process-sufficient-&-iff-def-entries rel-instance))))



;;;MAYBE-PROCESS-SUFFICIENT-&-IFF-DEF-ENTRIES --- modified by Mauro
(defmethod  maybe-process-sufficient-&-iff-def-entries ((obj ocml-relation))
  (with-slots (sufficient iff-def name schema prove-by) obj
    (when sufficient
      (unless (find-bc-rule name)
        (add-backward-rule name "" () (length schema)))
      (setf sufficient
	    (make-bc-rule-clause (list (cons name schema)
				       'if
				       sufficient))))
    (when prove-by
      (unless (find-bc-rule name)
        (add-backward-rule name "" () (length schema)))
      (setf prove-by
	    (make-bc-rule-clause (list (cons name schema)
				       'if
				       prove-by))))
    (when iff-def
      (unless (find-bc-rule name)
        (add-backward-rule name "" () (length schema)))
      (setf iff-def
            (make-bc-rule-clause (list (cons name schema)
                                       'if
				       iff-def))))))

(defun set-own-slots (rel-instance old new)
  (with-slots (name own-slots) rel-instance
    (loop for exp in old
          do
          (unassert1 `(,(car exp) ,name ,(second exp))))
    (loop for exp in new
          do
          (tell1 `(,(car exp) ,name ,(second exp))))
    (setf own-slots new)))
    
          


(defun find-or-create-relation (predicate arity &optional relation-spec)
  (or (get-relation predicate)
      (prog1
        (apply #'make-ocml-relation  predicate :arity arity
                          :schema (loop for i from 1 to arity
                                        collect (make-new-var))
                          relation-spec)
        (record-source-file predicate 'ocml-relation))))
      
      
;;;INITIALIZE-INSTANCE :AFTER OCML-RELATION
(defmethod initialize-instance :after ((relation ocml-relation) &rest initargs)
  (declare (ignore initargs))
  (with-slots (name schema arity ) relation
    (enforce-arity-schema-consistency relation name schema arity)
    (add-to-relations-directory name relation)))
    ;;;;(maybe-update-definition-in-super-ontologies relation)))


;;;CLEAR-ALL-DEFINED-BY-RULE-ENTRIES
(defun clear-all-defined-by-rule-entries ()
  (maphash #'(lambda (key relation)
               (declare (ignore key))
               (reset-defined-by-rule-entry relation))
           *defined-relations*))


(defmethod set-defined-by-rule-entry ((relation ocml-relation) rule)
  (with-slots (defined-by-rule) relation
    (setf defined-by-rule rule)))

(defmethod add-defined-by-rule-entry ((relation ocml-relation) rule)
  (with-slots (defined-by-rule) relation
    (setf defined-by-rule (cons rule defined-by-rule ))))

(defmethod remove-defined-by-rule-entry ((relation ocml-relation) rule)
  (with-slots (defined-by-rule) relation
    (setf defined-by-rule (remove rule defined-by-rule ))))

(defmethod reset-defined-by-rule-entry ((relation ocml-relation))
  (with-slots (defined-by-rule) relation
    (setf defined-by-rule nil)))

;;;ADD-SLOT-OF-ENTRY
(defmethod add-slot-of-entry ((relation ocml-relation) class)
  (with-slots (slot-of) relation
    (unless (member class slot-of)
      (setf slot-of (cons class slot-of)))))
    ;;;;(pushnew class slot-of)))

;;;REMOVE-SLOT-OF-ENTRY
(defmethod remove-slot-of-entry ((relation ocml-relation) class)
  (with-slots (slot-of) relation
    (setf slot-of
          (remove class slot-of))))

;;;SLOTP ---True if a relation is a slot of some domain class
(defmethod slotp ((relation ocml-relation))
  (with-slots (slot-of) relation
    slot-of))

;;;ENFORCE-ARITY-SCHEMA-CONSISTENCY
;;;This is used to make sure that arity and schema slots are consistent in
;;;functions and relations
(defun enforce-arity-schema-consistency (obj name schema arity &aux l)
  ;;;;(when schema
  (setf l (length schema))
  (if (and arity
           (not (= arity l)))
    (progn 
      (ocml-warn
       "Current arity of ~S ~S is ~S. Setting it to ~S to be consistent with schema ~S"
       (type-of obj) name arity (length schema) schema)
      (setf (arity obj) l))
    (unless arity
      (setf (arity obj) l))))


(defun rename-schema (relation)
  (mapcar #'(lambda (var)
                (make-new-var var))
	  (schema (get-relation relation))))

;;;GET-RELATION-TYPE ---This returns the 'type' of a relation.  This can be
;;;  :class - if the relation is a domain class
;;;  :slot  - if the relation is a slot
;;;  :lisp  - if it is defined by means of a lisp attachment
;;;  :predicate - all other cases
(defmethod get-relation-type ((relation ocml-relation))
  (with-slots (slot-of  relation-instances lisp-fun name) relation
    (cond (lisp-fun
           :lisp)
          (slot-of
           :slot)
          ((get-domain-class name)
           :class)
          (t
           :predicate))))

;;;CACHE-VALUE-INTERNAL --Adds a new cached value to the cache table of a relation
(defun cache-value-internal (rel key value)
  (setf (relation-cache-table rel)
        (cons (cons key value)
              (relation-cache-table rel))))

;;;FETCH-CACHED-VALUE --Retrieves a previously cached value from the cache table of a relation
(defun fetch-cached-value (rel key index-table)
  (Let ((value (right-value key (relation-cache-table rel):test #'equal)))
    (when value
      (loop for pair in index-table
            do
            (setf value (subst (car pair)(cdr pair)value)))
      value)))


;;;ADD-ALPHA-NODE-TO-RELATION ---Links an alpha node to a relation.  If the relation is the name
;;;of a class the alpha node is also added to the subclasses of the relation
(defmethod add-alpha-node-to-relation ((relation ocml-relation) node &optional type)
  (with-slots (fc-nodes name) relation
    (setf fc-nodes (nconc fc-nodes (list node)))
    (when (eq type :class)
      (dolist (subclass (subclasses nil (get-domain-class name)))
        (add-alpha-node-to-relation (get-relation (name subclass)) node)))))

(defmethod add-indirect-fc-node ((relation ocml-relation) node)
  (with-slots (indirect-fc-nodes) relation
    (push node indirect-fc-nodes)))


;;;CLEAR-ALL-ALPHA-NODES
(defun clear-all-alpha-nodes ()
  (maphash #'(lambda (key relation)
               (declare (ignore key))
               (reset-alpha-nodes relation t))
           *defined-relations*))

;;;RESET-ALPHA-NODES  
(defmethod reset-alpha-nodes ((relation ocml-relation) &optional recur? &aux class)
  (with-slots (fc-nodes indirect-fc-nodes name) relation
    (setf indirect-fc-nodes nil)
    (setf fc-nodes nil)
    (when (and recur? (setf class (get-domain-class name)))
      (dolist (subclass (subclasses nil class))
        (reset-alpha-nodes (get-relation subclass))))))

;;;REMOVE-ALPHA-NODE RELATION
(defmethod remove-alpha-node ((relation ocml-relation)alpha-node &optional recur? &aux class)
  (with-slots (fc-nodes name) relation
    (setf fc-nodes (remove alpha-node fc-nodes))
    (when (and recur? (setf class (get-domain-class name)))
      (dolist (subclass (subclasses nil class))
        (remove-alpha-node (get-relation subclass)alpha-node)))))

(defmethod remove-alpha-node ((relation (eql nil))alpha-node &optional recur?)
  (declare (ignore relation alpha-node recur?)))

(defmethod remove-indirect-alpha-node ((relation ocml-relation)alpha-node)
  (with-slots (indirect-fc-nodes) relation
    (setf indirect-fc-nodes (remove alpha-node indirect-fc-nodes))))


;;;FIND-RELATION-INSTANCE
(defmethod find-relation-instance ((relation ocml-relation) args)
  (with-slots (relation-instances)relation
    (member args relation-instances :test #'(lambda (x y)
                                                   (equal x (args y))))))


;;;ADD-RELATION-INSTANCE
(defmethod add-relation-instance ((relation ocml-relation) instance)
                                 ;;;;; (instance relation-instance))
  (with-slots (relation-instances name)relation
   ;;;;; (with-slots (predicate args) instance
    (push instance relation-instances)
    (tell-fc-rules name (args instance))))

;;;REMOVE-RELATION-INSTANCE-GEN
(defmethod remove-relation-instance-gen ((relation ocml-relation) args
                                         &optional contains-vars?)
  (if contains-vars?
      (with-slots (relation-instances name)relation
        (loop with deleted-relins
              for rel-instance in relation-instances
              unless (eq :fail
                         (match (args rel-instance) args))
              do
              (push rel-instance deleted-relins)
              finally
              (setf relation-instances (Set-difference relation-instances
                                                       deleted-relins))
              (dolist (rel-instance deleted-relins)
                (unassert-from-fc-rules  name (args rel-instance)))))
      (remove-relation-instance relation args)))

;;;REMOVE-RELATION-INSTANCE
(defmethod remove-relation-instance ((relation ocml-relation) args)
  (with-slots (relation-instances name)relation
    (setf relation-instances
          (remove args relation-instances
                  :test #'(lambda (x y)
			    (equal x (args y)))
                  :count 1))
    (unassert-from-fc-rules  name args)))

;(defmethod remove-relation-instance ((relation ocml-relation) args
;                                     &optional contains-vars?)
;  (with-slots (relation-instances name)relation
;    (setf relation-instances
;          (remove args relation-instances
;                  :test (if contains-vars?
;			    #'(lambda (x y)
;				(not (eq :fail
;					 (match (args y) x))))
;			    #'(lambda (x y)
;				(equal x (args y))))))
;    (unassert-from-fc-rules  name args)))
    

;;;CREATE&ADD-RELATION-INSTANCE
(defun create&add-relation-instance (pred-structure exp original-form documentation)
  (add-relation-instance
   pred-structure
   (make-relation-instance exp original-form documentation)))
  
  
;;;MAYBE-ADD-RELATION-INSTANCE
(defun maybe-add-relation-instance (pred-structure args original-form documentation
                                              &aux (exp (cons (car original-form) args)))
  ;;;A structure for the relation must already exist
  (cond ((find-relation-instance pred-structure args)
         (when (tracing-this-assertion? exp)
	 (format t "~%~S has already been asserted" exp)))
          (t
           (create&add-relation-instance pred-structure exp original-form documentation))))

;;;MATCH-RELATION-INSTANCE ---Finds a relation instance which matches <args> if
;;;it exists.  Otherwise it returns :fail.  Only one successful match is returned.
;(defmethod match-relation-instances ((relation ocml-relation) args &optional env)
;  (with-slots (relation-instances)relation
;    (if relation-instances
;	(loop for instance in relation-instances
;              for result = (match args (args instance)env )
;              until (not (eq result :fail))
;              finally (return result))
;        :fail)))



;;;MATCH-ALL-RELATION-INSTANCES ---Returns all the envs corresponding to successful
;;;matches of <args>.  If no match is found then :fail is returned
;(defmethod match-all-relation-instances ((relation ocml-relation) args &optional env)
;  (with-slots (relation-instances)relation
;    (loop with result
;          for instance in relation-instances
;	  for match = (match args (args instance)env)
;          when (not (eq match :fail))
;          do
;          (push match result)
;	  finally (return (or result :fail)))))


;;;MAYBE-ADD-SLOT-ASSERTION --
(defmethod maybe-add-slot-assertion ((relation ocml-relation) args original-form)
  (with-slots (name) relation
    (destructuring-bind (instancen value) args
      (let ((instance (find-instance instancen)))
        (if instance
            (if (member name (domain-slots instance))
                (add-slot-value-to-instance instance name value)
                (error "~S is not a slot of ~S..when asserting ~S"
                       name instancen original-form))
            (error
             "trying to add a slot value to undefined instance ~S..when parsing assertion ~S"
                   instancen original-form))))))

;;;MAYBE-DELETE-SLOT-ASSERTION ---
(defmethod  maybe-delete-slot-assertion ((relation ocml-relation) args original-form no-checks)
  (declare (ignore original-form))
  (with-slots (name slot-of) relation
    (destructuring-bind (instancen value) args
      (cond ((variable? instancen)
             (if (variable? value)
                 (loop for class in slot-of
                       do
		       (remove-all-slot-values-from-direct-instances
                        class
                        name
                        no-checks))
                 (loop for class in slot-of
                       do
		       (remove-slot-value-from-direct-instances
                        class
                        name
                        value
                        no-checks))))
	    ((variable? value)
             (let ((instance (find-instance instancen)))
               (when instance
		 (remove-local-slot-values instance name no-checks))))
	    (t
             (let ((instance (find-instance instancen)))
               (when instance
		 (maybe-remove-slot-value instance name value no-checks))))))))

 
;;;GENERATE-CANDIDATES OCML-RELATION
(defmethod generate-candidates ((relation ocml-relation) pred args &aux class classes instances)
  (with-slots (slot-of defined-by-rule relation-instances lisp-fun sufficient iff-def prove-by) 
              relation
    (cond (lisp-fun)
          (prove-by
           (values nil nil nil (list prove-by)))
           (iff-def
           (values nil nil nil (list iff-def)))
           (t                    ;;Is it defined by a lisp fun?
           (Progn
             (cond ((setf instances relation-instances))
                   (slot-of
                    (when (= (length args)    ;Slots are binary relations.  There is no point in 
                             2)               ;generating candidates if the goal hasn't got 2 args.
                      (let ((instance-id (car args)))
                        (cond ((and (atom instance-id)
                                 (not (variable? instance-id)))
                            ;;If the first arg to the slot is not a variable, then there is only one
                            ;;plausible candidate: an instance named <instance-id>
                            (setf instances            
                               (find-direct-instance-in-classes instance-id slot-of))
                            (when instances
                              (setf instances (List instances))))
                           (t
			    (setf classes slot-of))))))
                
                ((setf class (get-domain-class pred))
                 (setf instances (append instances (get-direct-instances class)))
                 (setf classes (direct-subclasses nil class))))
                            ;;;;;;(cons class
                                   ;;;;;;  (subclasses nil class))))
          
          (let ((clauses (when defined-by-rule
                           (if (cdr defined-by-rule)
                             (apply #'append
			            (mapcar  #'clauses defined-by-rule))
                             (clauses (car defined-by-rule))))))
            (when sufficient
              (setf clauses (cons sufficient clauses)))
            ;;(when iff-def 
              ;;;(setf clauses (cons iff-def clauses)))              
	    (values nil instances classes clauses)))))))



;;;FIND-ALPHA-NODE-CANDIDATES
(defmethod find-alpha-node-candidates ((relation ocml-relation)   &aux class)
  (with-slots (slot-of  relation-instances lisp-fun name) relation
    (unless lisp-fun                     ;;If it is defined by a lisp fun, we ignore it
      (if relation-instances
          (values relation-instances :relation-instances)
          (if slot-of
              (values 
               (loop for class in slot-of
		     appending (get-direct-instances class))
               :slot)
              (when (setf class (get-domain-class name))
                (values (get-all-instances class)
                        :class)))))))


;;;*******************************************************************

;;;RELATION-INSTANCE 
(defclass relation-instance (basic-ocml-object)
  ((predicate :initarg :predicate)
   (args :initarg  :args :accessor args)
   (original-form :initarg :original-form)
   )
  (:documentation "This class represents the existing relation instances (i.e. assertions)"))

(defun make-relation-instance (parsed-form original-form documentation)
  (make-instance 'relation-instance
                 :predicate (car parsed-form)
		 :args (cdr parsed-form)
                 :original-form original-form
		 :documentation documentation))

(defun relation-instance? (thing)
  (typep thing 'relation-instance))

