;; Vault-Forge: Liquid Staking Derivative with Reputation System
;; A comprehensive platform for liquid staking with integrated on-chain reputation

;; ===========================================
;; CONSTANTS AND ERROR CODES
;; ===========================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-AMOUNT (err u403))
(define-constant ERR-POOL-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u405))
(define-constant ERR-INVALID-REPUTATION (err u406))
(define-constant ERR-COOLDOWN-ACTIVE (err u407))

;; Minimum stake amounts
(define-constant MIN-STAKE u1000000) ;; 1 STX minimum
(define-constant REPUTATION-DECAY-BLOCKS u144) ;; ~1 day in blocks

;; ===========================================
;; DATA VARIABLES
;; ===========================================

(define-data-var total-staked uint u0)
(define-data-var total-liquid-tokens uint u0)
(define-data-var reward-rate uint u500) ;; 5% annual (500 basis points)
(define-data-var contract-paused bool false)
(define-data-var reputation-threshold uint u50) ;; Minimum reputation for certain actions

;; ===========================================
;; DATA MAPS
;; ===========================================

;; Staking pools for different assets/positions
(define-map staking-pools
  { pool-id: uint }
  {
    name: (string-ascii 50),
    total-staked: uint,
    total-liquid-tokens: uint,
    active: bool,
    creator: principal,
    created-at: uint
  }
)

;; User staking positions
(define-map user-stakes
  { user: principal, pool-id: uint }
  {
    staked-amount: uint,
    liquid-tokens: uint,
    last-claim: uint,
    entry-block: uint
  }
)

;; Liquid staking derivative tokens
(define-map liquid-balances
  { user: principal, pool-id: uint }
  uint
)

;; Reputation system
(define-map user-reputation
  { user: principal }
  {
    score: uint,
    total-interactions: uint,
    successful-interactions: uint,
    last-update: uint,
    staking-bonus: uint
  }
)

;; Reputation events for tracking
(define-map reputation-events
  { user: principal, event-id: uint }
  {
    event-type: (string-ascii 20),
    impact: int,
    timestamp: uint,
    related-pool: uint
  }
)

;; Pool counter
(define-data-var next-pool-id uint u1)
(define-data-var next-event-id uint u1)

;; ===========================================
;; LIQUID STAKING FUNCTIONS
;; ===========================================

;; Create a new staking pool
(define-public (create-pool (name (string-ascii 50)))
  (let
    (
      (pool-id (var-get next-pool-id))
      (current-block stacks-block-height)
    )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (>= (get-reputation tx-sender) (var-get reputation-threshold)) ERR-INVALID-REPUTATION)
    
    ;; Create the pool
    (map-set staking-pools
      { pool-id: pool-id }
      {
        name: name,
        total-staked: u0,
        total-liquid-tokens: u0,
        active: true,
        creator: tx-sender,
        created-at: current-block
      }
    )
    
    ;; Update pool counter
    (var-set next-pool-id (+ pool-id u1))
    
    ;; Update reputation for pool creation
    (update-reputation tx-sender "POOL_CREATION" 10 pool-id)
    
    (ok pool-id)
  )
)

;; Stake STX and receive liquid derivative tokens
(define-public (stake (pool-id uint) (amount uint))
  (let
    (
      (pool (unwrap! (map-get? staking-pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
      (current-stake (default-to 
        { staked-amount: u0, liquid-tokens: u0, last-claim: stacks-block-height, entry-block: stacks-block-height }
        (map-get? user-stakes { user: tx-sender, pool-id: pool-id })
      ))
      (liquid-tokens (calculate-liquid-tokens amount))
      (current-balance (default-to u0 (map-get? liquid-balances { user: tx-sender, pool-id: pool-id })))
    )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (get active pool) ERR-POOL-NOT-FOUND)
    (asserts! (>= amount MIN-STAKE) ERR-INVALID-AMOUNT)
    (asserts! (>= (stx-get-balance tx-sender) amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update user stake
    (map-set user-stakes
      { user: tx-sender, pool-id: pool-id }
      {
        staked-amount: (+ (get staked-amount current-stake) amount),
        liquid-tokens: (+ (get liquid-tokens current-stake) liquid-tokens),
        last-claim: stacks-block-height,
        entry-block: (get entry-block current-stake)
      }
    )
    
    ;; Update liquid token balance
    (map-set liquid-balances
      { user: tx-sender, pool-id: pool-id }
      (+ current-balance liquid-tokens)
    )
    
    ;; Update pool totals
    (map-set staking-pools
      { pool-id: pool-id }
      (merge pool {
        total-staked: (+ (get total-staked pool) amount),
        total-liquid-tokens: (+ (get total-liquid-tokens pool) liquid-tokens)
      })
    )
    
    ;; Update global totals
    (var-set total-staked (+ (var-get total-staked) amount))
    (var-set total-liquid-tokens (+ (var-get total-liquid-tokens) liquid-tokens))
    
    ;; Update reputation for staking
    (update-reputation tx-sender "STAKE" 5 pool-id)
    
    (ok liquid-tokens)
  )
)

;; Unstake and burn liquid derivative tokens
(define-public (unstake (pool-id uint) (liquid-amount uint))
  (let
    (
      (pool (unwrap! (map-get? staking-pools { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
      (user-stake (unwrap! (map-get? user-stakes { user: tx-sender, pool-id: pool-id }) ERR-INSUFFICIENT-BALANCE))
      (liquid-balance (default-to u0 (map-get? liquid-balances { user: tx-sender, pool-id: pool-id })))
      (stx-amount (calculate-stx-from-liquid liquid-amount pool-id))
    )
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (asserts! (get active pool) ERR-POOL-NOT-FOUND)
    (asserts! (>= liquid-balance liquid-amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> liquid-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Update liquid token balance
    (map-set liquid-balances
      { user: tx-sender, pool-id: pool-id }
      (- liquid-balance liquid-amount)
    )
    
    ;; Update user stake
    (map-set user-stakes
      { user: tx-sender, pool-id: pool-id }
      (merge user-stake {
        staked-amount: (- (get staked-amount user-stake) stx-amount),
        liquid-tokens: (- (get liquid-tokens user-stake) liquid-amount)
      })
    )
    
    ;; Update pool totals
    (map-set staking-pools
      { pool-id: pool-id }
      (merge pool {
        total-staked: (- (get total-staked pool) stx-amount),
        total-liquid-tokens: (- (get total-liquid-tokens pool) liquid-amount)
      })
    )
    
    ;; Update global totals
    (var-set total-staked (- (var-get total-staked) stx-amount))
    (var-set total-liquid-tokens (- (var-get total-liquid-tokens) liquid-amount))
    
    ;; Transfer STX back to user
    (try! (as-contract (stx-transfer? stx-amount tx-sender tx-sender)))
    
    ;; Update reputation for unstaking
    (update-reputation tx-sender "UNSTAKE" 2 pool-id)
    
    (ok stx-amount)
  )
)

;; ===========================================
;; REPUTATION SYSTEM FUNCTIONS
;; ===========================================

;; Initialize reputation for a new user
(define-private (init-reputation (user principal))
  (if (is-none (map-get? user-reputation { user: user }))
    (map-set user-reputation
      { user: user }
      {
        score: u50, ;; Starting reputation
        total-interactions: u0,
        successful-interactions: u0,
        last-update: stacks-block-height,
        staking-bonus: u0
      }
    )
    true
  )
)

;; Update user reputation
(define-private (update-reputation (user principal) (event-type (string-ascii 20)) (impact int) (pool-id uint))
  (let
    (
      (current-rep (default-to 
        { score: u50, total-interactions: u0, successful-interactions: u0, last-update: stacks-block-height, staking-bonus: u0 }
        (map-get? user-reputation { user: user })
      ))
      (event-id (var-get next-event-id))
      (new-score (if (> impact 0)
                  (+ (get score current-rep) (to-uint impact))
                  (if (> (get score current-rep) (to-uint (- 0 impact)))
                    (- (get score current-rep) (to-uint (- 0 impact)))
                    u0)))
      (blocks-passed (- stacks-block-height (get last-update current-rep)))
      (decay-amount (/ (* (get score current-rep) blocks-passed) (* REPUTATION-DECAY-BLOCKS u100)))
      (decayed-score (if (> (get score current-rep) decay-amount) 
                      (- new-score decay-amount) 
                      u0))
    )
    
    ;; Update reputation
    (map-set user-reputation
      { user: user }
      {
        score: decayed-score,
        total-interactions: (+ (get total-interactions current-rep) u1),
        successful-interactions: (if (> impact 0) 
                                  (+ (get successful-interactions current-rep) u1)
                                  (get successful-interactions current-rep)),
        last-update: stacks-block-height,
        staking-bonus: (calculate-staking-bonus user)
      }
    )
    
    ;; Record the event
    (map-set reputation-events
      { user: user, event-id: event-id }
      {
        event-type: event-type,
        impact: impact,
        timestamp: stacks-block-height,
        related-pool: pool-id
      }
    )
    
    (var-set next-event-id (+ event-id u1))
  )
)

;; Calculate staking bonus for reputation
(define-private (calculate-staking-bonus (user principal))
  (let
    (
      (total-user-stake (fold + (map get-user-total-stake (list u1 u2 u3 u4 u5)) u0))
    )
    (/ total-user-stake u100000) ;; 1 reputation point per 1 STX staked
  )
)

;; Report malicious behavior (reduces reputation)
(define-public (report-user (reported-user principal) (reason (string-ascii 50)))
  (begin
    (asserts! (>= (get-reputation tx-sender) u75) ERR-INVALID-REPUTATION)
    (asserts! (not (is-eq tx-sender reported-user)) ERR-UNAUTHORIZED)
    
    (update-reputation reported-user "REPORTED" -10 u0)
    (update-reputation tx-sender "REPORTING" 2 u0)
    
    (ok true)
  )
)

;; Endorse a user (increases reputation)
(define-public (endorse-user (endorsed-user principal))
  (begin
    (asserts! (>= (get-reputation tx-sender) u75) ERR-INVALID-REPUTATION)
    (asserts! (not (is-eq tx-sender endorsed-user)) ERR-UNAUTHORIZED)
    
    (update-reputation endorsed-user "ENDORSED" 5 u0)
    (update-reputation tx-sender "ENDORSING" 1 u0)
    
    (ok true)
  )
)

;; ===========================================
;; HELPER FUNCTIONS
;; ===========================================

;; Calculate liquid tokens from STX amount (1:1 ratio for simplicity)
(define-private (calculate-liquid-tokens (stx-amount uint))
  stx-amount
)

;; Calculate STX amount from liquid tokens
(define-private (calculate-stx-from-liquid (liquid-amount uint) (pool-id uint))
  (let
    (
      (pool (unwrap-panic (map-get? staking-pools { pool-id: pool-id })))
      (pool-staked (get total-staked pool))
      (pool-liquid (get total-liquid-tokens pool))
    )
    (if (is-eq pool-liquid u0)
      u0
      (/ (* liquid-amount pool-staked) pool-liquid)
    )
  )
)

;; Get user's total stake across all pools (helper for reputation calculation)
(define-private (get-user-total-stake (pool-id uint))
  (let
    (
      (user-stake (map-get? user-stakes { user: tx-sender, pool-id: pool-id }))
    )
    (if (is-some user-stake)
      (get staked-amount (unwrap-panic user-stake))
      u0
    )
  )
)

;; ===========================================
;; READ-ONLY FUNCTIONS
;; ===========================================

;; Get user reputation score
(define-read-only (get-reputation (user principal))
  (let
    (
      (rep-data (map-get? user-reputation { user: user }))
    )
    (if (is-some rep-data)
      (get score (unwrap-panic rep-data))
      u50 ;; Default reputation
    )
  )
)

;; Get detailed reputation data
(define-read-only (get-reputation-details (user principal))
  (map-get? user-reputation { user: user })
)

;; Get pool information
(define-read-only (get-pool-info (pool-id uint))
  (map-get? staking-pools { pool-id: pool-id })
)

;; Get user stake in a pool
(define-read-only (get-user-stake (user principal) (pool-id uint))
  (map-get? user-stakes { user: user, pool-id: pool-id })
)

;; Get liquid token balance
(define-read-only (get-liquid-balance (user principal) (pool-id uint))
  (default-to u0 (map-get? liquid-balances { user: user, pool-id: pool-id }))
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-staked: (var-get total-staked),
    total-liquid-tokens: (var-get total-liquid-tokens),
    reward-rate: (var-get reward-rate),
    next-pool-id: (var-get next-pool-id),
    contract-paused: (var-get contract-paused)
  }
)

;; ===========================================
;; ADMIN FUNCTIONS
;; ===========================================

;; Update reward rate (admin only)
(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set reward-rate new-rate)
    (ok true)
  )
)

;; Pause/unpause contract (admin only)
(define-public (set-contract-pause (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set contract-paused paused)
    (ok true)
  )
)

;; Update reputation threshold (admin only)
(define-public (set-reputation-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set reputation-threshold new-threshold)
    (ok true)
  )
)

;; Initialize the contract
(init-reputation CONTRACT-OWNER)