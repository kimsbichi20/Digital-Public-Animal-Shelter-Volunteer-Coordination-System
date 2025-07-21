;; Volunteer Application Contract
;; Manages volunteer registration, screening, and application process

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-VOLUNTEER-EXISTS (err u101))
(define-constant ERR-VOLUNTEER-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-INVALID-INPUT (err u104))

;; Data Variables
(define-data-var next-volunteer-id uint u1)

;; Data Maps
(define-map volunteers
  { volunteer-id: uint }
  {
    name: (string-ascii 100),
    email: (string-ascii 100),
    phone: (string-ascii 20),
    skills: (list 10 (string-ascii 50)),
    status: (string-ascii 20),
    application-date: uint,
    approved-date: (optional uint),
    emergency-contact: (string-ascii 100),
    notes: (string-ascii 500)
  }
)

(define-map volunteer-by-email
  { email: (string-ascii 100) }
  { volunteer-id: uint }
)

(define-map volunteer-stats
  { volunteer-id: uint }
  {
    total-applications: uint,
    approved-applications: uint,
    rejected-applications: uint,
    last-activity: uint
  }
)

;; Public Functions

;; Register new volunteer
(define-public (register-volunteer
  (name (string-ascii 100))
  (email (string-ascii 100))
  (phone (string-ascii 20))
  (skills (list 10 (string-ascii 50)))
  (emergency-contact (string-ascii 100)))
  (let ((volunteer-id (var-get next-volunteer-id)))
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len email) u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? volunteer-by-email { email: email })) ERR-VOLUNTEER-EXISTS)

    (map-set volunteers
      { volunteer-id: volunteer-id }
      {
        name: name,
        email: email,
        phone: phone,
        skills: skills,
        status: "pending",
        application-date: block-height,
        approved-date: none,
        emergency-contact: emergency-contact,
        notes: ""
      }
    )

    (map-set volunteer-by-email
      { email: email }
      { volunteer-id: volunteer-id }
    )

    (map-set volunteer-stats
      { volunteer-id: volunteer-id }
      {
        total-applications: u1,
        approved-applications: u0,
        rejected-applications: u0,
        last-activity: block-height
      }
    )

    (var-set next-volunteer-id (+ volunteer-id u1))
    (ok volunteer-id)
  )
)

;; Approve volunteer application
(define-public (approve-volunteer (volunteer-id uint))
  (let ((volunteer-data (unwrap! (map-get? volunteers { volunteer-id: volunteer-id }) ERR-VOLUNTEER-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status volunteer-data) "pending") ERR-INVALID-STATUS)

    (map-set volunteers
      { volunteer-id: volunteer-id }
      (merge volunteer-data {
        status: "approved",
        approved-date: (some block-height)
      })
    )

    (let ((stats (default-to
      { total-applications: u0, approved-applications: u0, rejected-applications: u0, last-activity: u0 }
      (map-get? volunteer-stats { volunteer-id: volunteer-id }))))
      (map-set volunteer-stats
        { volunteer-id: volunteer-id }
        (merge stats {
          approved-applications: (+ (get approved-applications stats) u1),
          last-activity: block-height
        })
      )
    )

    (ok true)
  )
)

;; Reject volunteer application
(define-public (reject-volunteer (volunteer-id uint) (reason (string-ascii 500)))
  (let ((volunteer-data (unwrap! (map-get? volunteers { volunteer-id: volunteer-id }) ERR-VOLUNTEER-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status volunteer-data) "pending") ERR-INVALID-STATUS)

    (map-set volunteers
      { volunteer-id: volunteer-id }
      (merge volunteer-data {
        status: "rejected",
        notes: reason
      })
    )

    (let ((stats (default-to
      { total-applications: u0, approved-applications: u0, rejected-applications: u0, last-activity: u0 }
      (map-get? volunteer-stats { volunteer-id: volunteer-id }))))
      (map-set volunteer-stats
        { volunteer-id: volunteer-id }
        (merge stats {
          rejected-applications: (+ (get rejected-applications stats) u1),
          last-activity: block-height
        })
      )
    )

    (ok true)
  )
)

;; Update volunteer information
(define-public (update-volunteer-info
  (volunteer-id uint)
  (phone (string-ascii 20))
  (skills (list 10 (string-ascii 50)))
  (emergency-contact (string-ascii 100)))
  (let ((volunteer-data (unwrap! (map-get? volunteers { volunteer-id: volunteer-id }) ERR-VOLUNTEER-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set volunteers
      { volunteer-id: volunteer-id }
      (merge volunteer-data {
        phone: phone,
        skills: skills,
        emergency-contact: emergency-contact
      })
    )

    (ok true)
  )
)

;; Deactivate volunteer
(define-public (deactivate-volunteer (volunteer-id uint))
  (let ((volunteer-data (unwrap! (map-get? volunteers { volunteer-id: volunteer-id }) ERR-VOLUNTEER-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set volunteers
      { volunteer-id: volunteer-id }
      (merge volunteer-data { status: "inactive" })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get volunteer information
(define-read-only (get-volunteer (volunteer-id uint))
  (map-get? volunteers { volunteer-id: volunteer-id })
)

;; Get volunteer by email
(define-read-only (get-volunteer-by-email (email (string-ascii 100)))
  (match (map-get? volunteer-by-email { email: email })
    volunteer-ref (map-get? volunteers { volunteer-id: (get volunteer-id volunteer-ref) })
    none
  )
)

;; Get volunteer statistics
(define-read-only (get-volunteer-stats (volunteer-id uint))
  (map-get? volunteer-stats { volunteer-id: volunteer-id })
)

;; Check if volunteer is approved
(define-read-only (is-volunteer-approved (volunteer-id uint))
  (match (map-get? volunteers { volunteer-id: volunteer-id })
    volunteer-data (is-eq (get status volunteer-data) "approved")
    false
  )
)

;; Get next volunteer ID
(define-read-only (get-next-volunteer-id)
  (var-get next-volunteer-id)
)

;; Get total volunteers count
(define-read-only (get-total-volunteers)
  (- (var-get next-volunteer-id) u1)
)
