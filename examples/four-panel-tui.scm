#!/usr/bin/env guile
!#

(add-to-load-path (dirname (dirname (current-filename))))
(add-to-load-path "/opt/homebrew/share/guile/site/3.0")

(use-modules (canary terminal)
             (canary style)
             (canary protocol)
             (canary app)
             (canary layout)
             (canary borders)
             (canary table)
             (canary zones)
             (ice-9 match)
             (oop goops))

;;; Model
(define-class <model> ()
  (active-env #:init-value "develop" #:accessor active-env)
  (active-tab #:init-value 'overview #:accessor active-tab))

;;; Init
(define (init m)
  #f)

;;; Update
(define (update m msg)
  (cond
   ((is-a? msg <key-msg>)
    (let ((k (key msg)))
      (cond
       ((or (and (char? k) (char=? k #\q))
            (and (char? k) (char=? k #\Q)))
        (values m (quit-cmd)))
       ((and (char? k) (char=? k #\1))
        (set! (active-tab m) 'overview)
        (values m #f))
       ((and (char? k) (char=? k #\2))
        (set! (active-tab m) 'production)
        (values m #f))
       (else (values m #f)))))
   ((is-a? msg <mouse-msg>)
    (values m #f))
   (else (values m #f))))

;;; View
(define (view m)
  (zone-scan
   (hbox
    ;; Panel 1: Env bar (narrow vertical - D, N, P, S)
    (vbox (boxed (txt "D" #:bold? #t) #:border border-thick #:fg "#5599ff" #:bg "#0044aa")
          (boxed (txt "N") #:border border-normal #:fg "#333")
          (boxed (txt "P") #:border border-normal #:fg "#333")
          (boxed (txt "S") #:border border-normal #:fg "#333"))
    "  "

    ;; Panel 2: Resource tree
    (vbox (txt "Resources" #:bold? #t #:fg "#00ff87")
          (spacer 1)
          (txt "▼ ● CONFIGMAPS       65" #:fg "#ffaa00")
          (txt "▼ ● DEPLOYMENTS     30" #:fg "#ffaa00")
          (txt "▼ ● PODS            84" #:fg "#ffaa00")
          (txt "▼ ● SERVICES        36" #:fg "#ffaa00")
          (txt "▼ ● STATEFULSETS     2" #:fg "#ffaa00")
          (txt "▼ ● DATABASES        4" #:fg "#ffaa00"))
    "  "

    ;; Panel 3+4: Main area (breadcrumb, tabs, content)
    (vbox
     ;; Breadcrumb
     (hbox (txt (active-env m) #:bold? #t #:fg "#00ff87")
           (txt " • " #:fg "#666")
           (txt "Overview" #:fg "#ffffff")
           (txt " • " #:fg "#666")
           (txt "production" #:fg "#666"))
     (spacer 1)

     ;; Tab bar
     (hbox (boxed (txt " Overview " #:bold? #t)
                  #:border border-rounded
                  #:fg (if (eq? (active-tab m) 'overview) "#00ff87" "#333"))
           " "
           (boxed (txt " production " #:bold? #t)
                  #:border border-rounded
                  #:fg (if (eq? (active-tab m) 'production) "#00ff87" "#333")))
     (spacer 1)

     ;; Main content
     (match (active-tab m)
       ('overview
        (let ((tbl (make-table #:headers '("NAME" "NAMESPACE" "KIND")
                              #:border border-rounded)))
          (table-add-row tbl '("kube-root-ca.crt" "ack" ":ConfigMap"))
          (table-add-row tbl '("kube-root-ca.crt" "argocd" ":ConfigMap"))
          (table-add-row tbl '("kube-root-ca.crt" "cert-manager" ":ConfigMap"))
          (table-add-row tbl '("clamav-develop" "clamav" ":ConfigMap"))
          (table-add-row tbl '("kube-root-ca.crt" "clamav" ":ConfigMap"))
          (table-add-row tbl '("kube-root-ca.crt" "cron-jobs-develop" ":ConfigMap"))
          (table-add-row tbl '("agent-helm-check-config" "datadog" ":ConfigMap"))
          (table-add-row tbl '("agent-install-info" "datadog" ":ConfigMap"))
          (table-add-row tbl '("agent-kube-state-metrics-core-config" "datadog" ":ConfigMap"))
          (table-add-row tbl '("agent-leader-election" "datadog" ":ConfigMap"))
          (table-add-row tbl '("agent-orchestrator-" "datadog" ":ConfigMap"))
          (table-render tbl)))
       ('production
        (vbox (txt "Production Environment" #:bold? #t #:fg "#00ff87")
              (spacer 1)
              (txt "Environment-specific resources and configuration would appear here" #:fg "#666"))))

     (spacer 1)
     (txt "Keys: 1-2 switch tabs | q quit" #:fg "#666")))))

;;; Run
(define model (make <model>))
(define app (make-app model (current-module)))
(run-app app)
