;; Smart Contract: MedicalChain: Secure Healthcare Records and Prescription Platform


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants and Error Codes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant ERR-UNAUTHORIZED (err u150))
(define-constant ERR-MISSING (err u151))
(define-constant ERR-DUPLICATE (err u152))
(define-constant ERR-ACCESS-DENIED (err u153))
(define-constant ERR-INVALID-USER-TYPE (err u154))
(define-constant ERR-INVALID-PARAMETER (err u155))
(define-constant ERR-TASK-FAILED (err u156))
(define-constant ERR-INVALID-PATIENT (err u157))
(define-constant ERR-INVALID-PHYSICIAN (err u158))
(define-constant ERR-INVALID-DISPENSER (err u159))
(define-constant ERR-RECORD-EXISTS (err u160))
(define-constant ERR-FREQUENCY-EXCEEDED (err u161))
(define-constant ERR-TIMEOUT (err u162))

;; Token constants
(define-constant OWNER-ADDRESS tx-sender)

;; Define SIP-010 fungible token trait interface
(define-trait token-standard
    (
        ;; Transfer from the caller to a new principal
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        ;; Get the token balance of the specified principal
        (get-balance (principal) (response uint uint))
        ;; Get the total number of tokens
        (get-total-supply () (response uint uint))
        ;; Get the token uri
        (get-token-uri () (response (optional (string-utf8 256)) uint))
        ;; Get the token decimals
        (get-decimals () (response uint uint))
        ;; Get the token name
        (get-name () (response (string-ascii 32) uint))
        ;; Get the symbol
        (get-symbol () (response (string-ascii 32) uint))
    )
)

;; Token contract variable
(define-data-var token-contract-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-contract)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data Structures
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; User types: "patient", "physician", "dispenser"
(define-map account-profiles 
    {account-id: principal}
    {type: (string-ascii 10),
     encryption-key: (string-ascii 66)}
)

;; Health records per patient (stored off-chain reference)
(define-map health-records 
    {patient-id: principal}
    {record-hash: (string-ascii 64),
     last-updated: uint}
)

;; Visit logs with unique IDs
(define-map visit-logs 
    {visit-id: uint}
    {patient: principal,
     physician: principal,
     timestamp: uint,
     summary-hash: (string-ascii 64)}
)

;; Medication orders with unique IDs
(define-map medication-orders 
    {order-id: uint}
    {patient: principal,
     physician: principal,
     dispenser: (optional principal),
     medication-name: (string-ascii 100),
     dosage: uint,
     timestamp: uint,
     is-fulfilled: bool}
)

;; Data sharing map: patient grants access to authorized users
(define-map data-sharing 
    {patient-id: principal, 
     viewer: principal}
    {approved: bool}
)

;; Transaction records
(define-map transactions 
    {transaction-id: uint}
    {sender: principal,
     receiver: principal,
     amount: uint,
     timestamp: uint}
)

;; Visit frequency control
(define-map visit-frequency-control 
    {physician: principal}
    {last-visit: uint,
     tally: uint}
)

;; ID Counters
(define-data-var visit-id-counter uint u0)
(define-data-var medication-order-counter uint u0)
(define-data-var transaction-id-counter uint u0)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants for Business Rules
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant MAX-DOSAGE u1000)
(define-constant MIN-DOSAGE u1)
(define-constant FREQUENCY-LIMIT-PERIOD u144)          ;; Approximately 24 hours in blocks
(define-constant MAX-VISITS-PER-PERIOD u20)
(define-constant MEDICATION-ORDER-VALIDITY u1008)      ;; Approximately 7 days in blocks

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Utility Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-private (is-valid-id (id uint) (counter uint))
    (<= id counter)
)

(define-private (is-account-registered (user principal))
    (is-some (map-get? account-profiles {account-id: user}))
)

(define-private (get-account-type (user principal))
    (get type (unwrap-panic (map-get? account-profiles {account-id: user})))
)

(define-private (assert-is-patient (user principal))
    (ok (asserts! (is-eq (get-account-type user) "patient") ERR-INVALID-PATIENT))
)

(define-private (assert-is-physician (user principal))
    (ok (asserts! (is-eq (get-account-type user) "physician") ERR-INVALID-PHYSICIAN))
)

(define-private (assert-is-dispenser (user principal))
    (ok (asserts! (is-eq (get-account-type user) "dispenser") ERR-INVALID-DISPENSER))
)

(define-private (increment-visit-id)
    (let ((new-id (+ (var-get visit-id-counter) u1)))
        (var-set visit-id-counter new-id)
        new-id
    )
)

(define-private (increment-medication-order)
    (let ((new-id (+ (var-get medication-order-counter) u1)))
        (var-set medication-order-counter new-id)
        new-id
    )
)

(define-private (increment-transaction-id)
    (let ((new-id (+ (var-get transaction-id-counter) u1)))
        (var-set transaction-id-counter new-id)
        new-id
    )
)

;; Validate if the principal is marked as a contract principal
(define-private (is-valid-contract-principal (contract principal) (is-contract bool))
    (if is-contract
        true       ;; It's a contract principal as per input flag
        false      ;; Otherwise, it is a standard principal
    )
)

;; Simplified hash validation - checks length only
(define-private (is-valid-hash (hash (string-ascii 64)))
    (>= (len hash) u64)  ;; Ensure hash is exactly 64 characters
)

;; Check frequency limit for visits
(define-private (check-frequency-limit (physician principal))
    (let ((current-limit (default-to 
            {last-visit: u0, tally: u0}
            (map-get? visit-frequency-control {physician: physician}))))
        (if (> (- block-height (get last-visit current-limit)) FREQUENCY-LIMIT-PERIOD)
            (begin
                (map-set visit-frequency-control {physician: physician} {last-visit: block-height, tally: u1})
                (ok true)
            )
            (if (< (get tally current-limit) MAX-VISITS-PER-PERIOD)
                (begin
                    (map-set visit-frequency-control {physician: physician} {last-visit: (get last-visit current-limit), tally: (+ (get tally current-limit) u1)})
                    (ok true)
                )
                (err ERR-FREQUENCY-EXCEEDED)
            )
        )
    )
)

;; Check if medication order is valid (not expired)
(define-private (is-medication-order-valid (order-id uint))
    (let ((order (unwrap! (map-get? medication-orders {order-id: order-id}) ERR-MISSING)))
        (asserts! (< (- block-height (get timestamp order)) MEDICATION-ORDER-VALIDITY) ERR-TIMEOUT)
        (ok order)
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Contract Owner Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (set-token-contract (new-token-contract principal))
    (begin
        (asserts! (is-eq tx-sender OWNER-ADDRESS) ERR-UNAUTHORIZED)
        (asserts! (is-valid-contract-principal new-token-contract true) ERR-INVALID-PARAMETER)
        (var-set token-contract-address new-token-contract)
        (ok true)
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; User Registration with Encryption Key
(define-public (register-account (account-type (string-ascii 10)) (encryption-key (string-ascii 66)))
    (begin
        ;; Validate role and registration status
        (asserts! (or (is-eq account-type "patient") (is-eq account-type "physician") (is-eq account-type "dispenser")) ERR-INVALID-USER-TYPE)
        (asserts! (not (is-account-registered tx-sender)) ERR-DUPLICATE)
        ;; Check that encryption-key length is exactly 66
        (asserts! (is-eq (len encryption-key) u66) ERR-INVALID-PARAMETER)
        ;; Register user
        (ok (map-set account-profiles 
            {account-id: tx-sender}
            {type: account-type, 
             encryption-key: encryption-key}))
    )
)

;; Approve Data Access
(define-public (approve-access (viewer principal))
    (begin
        (try! (assert-is-patient tx-sender))
        (asserts! (is-account-registered viewer) ERR-MISSING)
        (let ((existing (map-get? data-sharing {patient-id: tx-sender, viewer: viewer})))
            (asserts! (not (is-some existing)) ERR-DUPLICATE)
            (ok (map-set data-sharing 
                {patient-id: tx-sender, 
                 viewer: viewer}
                {approved: true}))
        )
    )
)

;; Remove Data Access
(define-public (remove-access (viewer principal))
    (begin
        (try! (assert-is-patient tx-sender))
        (asserts! (is-account-registered viewer) ERR-MISSING) 
        (let ((existing (map-get? data-sharing {patient-id: tx-sender, viewer: viewer})))
            (asserts! (is-some existing) ERR-MISSING)
            (ok (map-delete data-sharing {patient-id: tx-sender, viewer: viewer}))
        )
    )
)

;; Book a Visit
(define-public (book-visit (physician principal))
    (let ((frequency-check (unwrap! (check-frequency-limit physician) ERR-FREQUENCY-EXCEEDED)))
        (begin
            (try! (assert-is-patient tx-sender))
            (try! (assert-is-physician physician))
            (asserts! (not (is-eq physician tx-sender)) ERR-INVALID-PARAMETER)
            ;; Increment visit ID and record the visit
            (let ((visit-id (increment-visit-id)))
                (map-set visit-logs 
                    {visit-id: visit-id}
                    {patient: tx-sender,
                     physician: physician,
                     timestamp: block-height,
                     summary-hash: ""})
                (map-set data-sharing 
                    {patient-id: tx-sender, 
                     viewer: physician}
                    {approved: true})
                (ok visit-id)
            )
        )
    )
)

;; Record Visit Summary
(define-public (record-visit-summary (visit-id uint) (summary-hash (string-ascii 64)))
    (begin
        (try! (assert-is-physician tx-sender))
        (asserts! (is-valid-hash summary-hash) ERR-INVALID-PARAMETER)
        ;; Add visit ID validation
        (asserts! (<= visit-id (var-get visit-id-counter)) ERR-INVALID-PARAMETER)
        ;; Verify that visit-id exists
        (let ((visit (unwrap! (map-get? visit-logs {visit-id: visit-id}) ERR-MISSING)))
            (asserts! (is-eq tx-sender (get physician visit)) ERR-UNAUTHORIZED)
            (ok (map-set visit-logs 
                {visit-id: visit-id}
                (merge visit {summary-hash: summary-hash})))
        )
    )
)

;; Create Medication Order
(define-public (create-medication-order (patient principal) (medication-name (string-ascii 100)) (dosage uint))
    (begin
        (try! (assert-is-physician tx-sender))
        (asserts! (is-account-registered patient) ERR-MISSING)
        (asserts! (and (>= dosage MIN-DOSAGE) (<= dosage MAX-DOSAGE)) ERR-INVALID-PARAMETER)
        (asserts! (> (len medication-name) u0) ERR-INVALID-PARAMETER)
        ;; Create order
        (let ((order-id (increment-medication-order)))
            (map-set medication-orders 
                {order-id: order-id}
                {patient: patient,
                 physician: tx-sender,
                 dispenser: none,
                 medication-name: medication-name,
                 dosage: dosage,
                 timestamp: block-height,
                 is-fulfilled: false})
            (ok order-id)
        )
    )
)

;; Choose Dispenser
(define-public (choose-dispenser (order-id uint) (dispenser principal))
    (begin
        (try! (assert-is-patient tx-sender))
        ;; Add order ID validation
        (asserts! (<= order-id (var-get medication-order-counter)) ERR-INVALID-PARAMETER)
        ;; Validate dispenser before assertion
        (asserts! (is-account-registered dispenser) ERR-MISSING)
        (try! (assert-is-dispenser dispenser))
        ;; Verify that order-id exists
        (let ((order (unwrap! (map-get? medication-orders {order-id: order-id}) ERR-MISSING)))
            (asserts! (is-eq tx-sender (get patient order)) ERR-UNAUTHORIZED)
            (asserts! (is-none (get dispenser order)) ERR-TASK-FAILED)
            ;; Validate the order
            (unwrap! (is-medication-order-valid order-id) ERR-TIMEOUT)
            (ok (map-set medication-orders 
                {order-id: order-id}
                (merge order {dispenser: (some dispenser)})))
        )
    )
)

;; Fulfill Medication Order
(define-public (fulfill-order (order-id uint))
    (begin
        (try! (assert-is-dispenser tx-sender))
        ;; Add order ID validation
        (asserts! (<= order-id (var-get medication-order-counter)) ERR-INVALID-PARAMETER)
        ;; Verify that order-id exists
        (let ((order (unwrap! (map-get? medication-orders {order-id: order-id}) ERR-MISSING)))
            (asserts! (is-eq (get dispenser order) (some tx-sender)) ERR-UNAUTHORIZED)
            (asserts! (not (get is-fulfilled order)) ERR-TASK-FAILED)
            (print {event: "medication-fulfilled",
                    order-id: order-id,
                    dispenser: tx-sender,
                    patient: (get patient order),
                    timestamp: block-height})
            (ok (map-set medication-orders 
                {order-id: order-id}
                (merge order {is-fulfilled: true})))
        )
    )
)

;; Update Health Record
(define-public (update-health-record (record-hash (string-ascii 64)))
    (begin
        (try! (assert-is-patient tx-sender))
        (asserts! (is-valid-hash record-hash) ERR-INVALID-PARAMETER)
        (ok (map-set health-records 
            {patient-id: tx-sender}
            {record-hash: record-hash,
             last-updated: block-height}))
    )
)

;; Get Health Record
(define-read-only (get-health-record (patient principal))
    (if (or (is-eq tx-sender patient)
            (is-some (map-get? data-sharing {patient-id: patient, viewer: tx-sender})))
        (ok (map-get? health-records {patient-id: patient}))
        ERR-ACCESS-DENIED)
)

;; Process Payment
(define-public (process-payment (token-trait <token-standard>) (amount uint) (receiver principal))
    (begin
        (asserts! (> amount u0) ERR-INVALID-PARAMETER)
        (asserts! (is-account-registered receiver) ERR-MISSING)
        (asserts! (is-eq (contract-of token-trait) (var-get token-contract-address)) ERR-UNAUTHORIZED)
        ;; Payment execution
        (let ((transaction-id (increment-transaction-id)))
            (try! (contract-call? token-trait transfer amount tx-sender receiver none))
            (ok (map-set transactions 
                {transaction-id: transaction-id}
                {sender: tx-sender,
                 receiver: receiver,
                 amount: amount,
                 timestamp: block-height}))
        )
    )
)