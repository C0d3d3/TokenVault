;; TokenVault - A decentralized token staking and rewards platform
;; Users stake tokens to earn rewards from various yield-generating activities

;; Data storage
(define-map staker-profiles principal {
  active: bool,
  strategies: (list 10 uint),
  rewards: uint,
  last-claim: uint,
  stake-count: uint
})

(define-map yield-pools uint {
  creator: principal,
  liquidity: uint,
  reward-rate: uint,
  active: bool,
  strategy-type: uint,
  total-stakers: uint,
  created-at: uint
})

(define-map stake-records {staker: principal, pool-id: uint} {
  timestamp: uint,
  rewarded: bool
})

(define-map strategy-types uint (string-ascii 64))

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PARAMS (err u101))
(define-constant ERR_STAKER_NOT_FOUND (err u102))
(define-constant ERR_POOL_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_ALREADY_REGISTERED (err u105))
(define-constant ERR_ALREADY_STAKED (err u106))
(define-constant ERR_INVALID_PRINCIPAL (err u107))
(define-constant ERR_INVALID_VALUE (err u108))
(define-constant ERR_STRATEGY_NOT_FOUND (err u109))

(define-constant ZERO_ADDRESS 'SP000000000000000000002Q6VF78)
(define-constant MIN_REWARD_RATE u1)
(define-constant MAX_REWARD_RATE u1000)
(define-constant MIN_POOL_LIQUIDITY u1000)
(define-constant MAX_STRATEGY_ID u1000)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-pool-id uint u1)
(define-data-var protocol-fee-percent uint u5) ;; 5% fee
(define-data-var protocol-balance uint u0)

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-owner ZERO_ADDRESS)) ERR_INVALID_PRINCIPAL)
    (ok (var-set contract-owner new-owner))))

(define-public (set-protocol-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee u20) ERR_INVALID_PARAMS) ;; Max 20% fee
    (ok (var-set protocol-fee-percent new-fee))))

(define-public (add-strategy (strategy-id uint) (strategy-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len strategy-name) u0) ERR_INVALID_PARAMS)
    ;; Validate strategy ID
    (asserts! (< strategy-id MAX_STRATEGY_ID) ERR_INVALID_PARAMS)
    (asserts! (is-none (map-get? strategy-types strategy-id)) ERR_ALREADY_REGISTERED)
    (ok (map-set strategy-types strategy-id strategy-name))))

;; User functions
(define-public (register-staker (strategies (list 10 uint)))
  (begin
    (asserts! (is-none (map-get? staker-profiles tx-sender)) ERR_ALREADY_REGISTERED)
    (asserts! (validate-strategies strategies) ERR_INVALID_PARAMS)
    (ok (map-set staker-profiles tx-sender {
      active: true,
      strategies: strategies,
      rewards: u0,
      last-claim: u0,
      stake-count: u0
    }))))

(define-public (update-strategies (strategies (list 10 uint)))
  (let ((staker-profile (unwrap! (map-get? staker-profiles tx-sender) ERR_STAKER_NOT_FOUND)))
    (asserts! (validate-strategies strategies) ERR_INVALID_PARAMS)
    (ok (map-set staker-profiles tx-sender (merge staker-profile {strategies: strategies})))))

(define-public (pause-staking)
  (let ((staker-profile (unwrap! (map-get? staker-profiles tx-sender) ERR_STAKER_NOT_FOUND)))
    (ok (map-set staker-profiles tx-sender (merge staker-profile {active: false})))))

(define-public (resume-staking)
  (let ((staker-profile (unwrap! (map-get? staker-profiles tx-sender) ERR_STAKER_NOT_FOUND)))
    (ok (map-set staker-profiles tx-sender (merge staker-profile {active: true})))))

;; Pool creator functions
(define-public (create-yield-pool (liquidity uint) (reward-rate uint) (strategy-type uint) (stx-amount uint))
  (begin
    (asserts! (>= liquidity MIN_POOL_LIQUIDITY) ERR_INVALID_PARAMS)
    (asserts! (and (>= reward-rate MIN_REWARD_RATE) (<= reward-rate MAX_REWARD_RATE)) ERR_INVALID_PARAMS)
    (asserts! (is-some (map-get? strategy-types strategy-type)) ERR_STRATEGY_NOT_FOUND)
    (asserts! (>= stx-amount liquidity) ERR_INSUFFICIENT_FUNDS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
    
    (let ((pool-id (var-get next-pool-id)))
      ;; Create pool
      (map-set yield-pools pool-id {
        creator: tx-sender,
        liquidity: liquidity,
        reward-rate: reward-rate,
        active: true,
        strategy-type: strategy-type,
        total-stakers: u0,
        created-at: u0
      })
      
      ;; Increment pool ID
      (var-set next-pool-id (+ pool-id u1))
      (ok pool-id))))

(define-public (pause-pool (pool-id uint))
  (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator pool)) ERR_NOT_AUTHORIZED)
    (ok (map-set yield-pools pool-id (merge pool {active: false})))))

(define-public (resume-pool (pool-id uint))
  (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator pool)) ERR_NOT_AUTHORIZED)
    (ok (map-set yield-pools pool-id (merge pool {active: true})))))

(define-public (add-pool-liquidity (pool-id uint) (additional-liquidity uint))
  (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator pool)) ERR_NOT_AUTHORIZED)
    (asserts! (> additional-liquidity u0) ERR_INVALID_PARAMS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? additional-liquidity tx-sender (as-contract tx-sender)))
    
    (ok (map-set yield-pools pool-id 
      (merge pool {liquidity: (+ (get liquidity pool) additional-liquidity)})))))

;; Helper function to check if a strategy matches user preferences
(define-private (check-strategy-match (strategy-type uint) (strategies (list 10 uint)))
  (or
    (and (> (len strategies) u0) (is-eq strategy-type (unwrap-panic (element-at strategies u0))))
    (and (> (len strategies) u1) (is-eq strategy-type (unwrap-panic (element-at strategies u1))))
    (and (> (len strategies) u2) (is-eq strategy-type (unwrap-panic (element-at strategies u2))))
    (and (> (len strategies) u3) (is-eq strategy-type (unwrap-panic (element-at strategies u3))))
    (and (> (len strategies) u4) (is-eq strategy-type (unwrap-panic (element-at strategies u4))))
    (and (> (len strategies) u5) (is-eq strategy-type (unwrap-panic (element-at strategies u5))))
    (and (> (len strategies) u6) (is-eq strategy-type (unwrap-panic (element-at strategies u6))))
    (and (> (len strategies) u7) (is-eq strategy-type (unwrap-panic (element-at strategies u7))))
    (and (> (len strategies) u8) (is-eq strategy-type (unwrap-panic (element-at strategies u8))))
    (and (> (len strategies) u9) (is-eq strategy-type (unwrap-panic (element-at strategies u9))))
  ))

;; Staking and rewards
(define-public (stake-in-pool (pool-id uint))
  (let (
    (staker-profile (unwrap! (map-get? staker-profiles tx-sender) ERR_STAKER_NOT_FOUND))
    (pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND))
    (stake-key {staker: tx-sender, pool-id: pool-id})
  )
    ;; Validate conditions
    (asserts! (get active staker-profile) ERR_STAKER_NOT_FOUND)
    (asserts! (get active pool) ERR_POOL_NOT_FOUND)
    (asserts! (is-none (map-get? stake-records stake-key)) ERR_ALREADY_STAKED)
    (asserts! (>= (get liquidity pool) (get reward-rate pool)) ERR_INSUFFICIENT_FUNDS)
    (asserts! (check-strategy-match (get strategy-type pool) (get strategies staker-profile)) ERR_INVALID_PARAMS)
    
    ;; Calculate rewards
    (let (
      (reward-rate (get reward-rate pool))
      (protocol-fee (/ (* reward-rate (var-get protocol-fee-percent)) u100))
      (staker-reward (- reward-rate protocol-fee))
    )
      ;; Record the stake
      (map-set stake-records stake-key {timestamp: u0, rewarded: true})
      
      ;; Update pool stats
      (map-set yield-pools pool-id (merge pool {
        liquidity: (- (get liquidity pool) reward-rate),
        total-stakers: (+ (get total-stakers pool) u1)
      }))
      
      ;; Update staker stats
      (map-set staker-profiles tx-sender (merge staker-profile {
        rewards: (+ (get rewards staker-profile) staker-reward),
        stake-count: (+ (get stake-count staker-profile) u1)
      }))
      
      ;; Update protocol balance
      (var-set protocol-balance (+ (var-get protocol-balance) protocol-fee))
      
      (ok staker-reward))))

(define-public (claim-rewards)
  (let ((staker-profile (unwrap! (map-get? staker-profiles tx-sender) ERR_STAKER_NOT_FOUND)))
    (let ((rewards (get rewards staker-profile)))
      (asserts! (> rewards u0) ERR_INSUFFICIENT_FUNDS)
      
      ;; Transfer STX to staker
      (try! (as-contract (stx-transfer? rewards tx-sender tx-sender)))
      
      ;; Update staker profile
      (map-set staker-profiles tx-sender (merge staker-profile {
        rewards: u0,
        last-claim: u0
      }))
      
      (ok rewards))))

(define-public (withdraw-protocol-fees)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (let ((amount (var-get protocol-balance)))
      (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
      
      ;; Transfer STX to contract owner
      (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
      
      ;; Reset protocol balance
      (var-set protocol-balance u0)
      
      (ok amount))))

;; Helper function to check if a strategy is valid
(define-private (is-valid-strategy (strategy uint))
  (is-some (map-get? strategy-types strategy)))

;; Helper function to count valid strategies in a list
(define-private (count-valid-strategies (strategies (list 10 uint)))
  (+ 
    (if (and (> (len strategies) u0) (is-valid-strategy (unwrap-panic (element-at strategies u0)))) u1 u0)
    (if (and (> (len strategies) u1) (is-valid-strategy (unwrap-panic (element-at strategies u1)))) u1 u0)
    (if (and (> (len strategies) u2) (is-valid-strategy (unwrap-panic (element-at strategies u2)))) u1 u0)
    (if (and (> (len strategies) u3) (is-valid-strategy (unwrap-panic (element-at strategies u3)))) u1 u0)
    (if (and (> (len strategies) u4) (is-valid-strategy (unwrap-panic (element-at strategies u4)))) u1 u0)
    (if (and (> (len strategies) u5) (is-valid-strategy (unwrap-panic (element-at strategies u5)))) u1 u0)
    (if (and (> (len strategies) u6) (is-valid-strategy (unwrap-panic (element-at strategies u6)))) u1 u0)
    (if (and (> (len strategies) u7) (is-valid-strategy (unwrap-panic (element-at strategies u7)))) u1 u0)
    (if (and (> (len strategies) u8) (is-valid-strategy (unwrap-panic (element-at strategies u8)))) u1 u0)
    (if (and (> (len strategies) u9) (is-valid-strategy (unwrap-panic (element-at strategies u9)))) u1 u0)
  ))

;; Validate staker strategies
(define-private (validate-strategies (strategies (list 10 uint)))
  (let ((strats-len (len strategies)))
    (and 
      (> strats-len u0)
      (<= strats-len u10)
      (is-eq strats-len (count-valid-strategies strategies)))))

;; Read-only functions
(define-read-only (get-staker-profile (staker principal))
  (map-get? staker-profiles staker))

(define-read-only (get-pool (pool-id uint))
  (map-get? yield-pools pool-id))

(define-read-only (get-strategy (strategy-id uint))
  (map-get? strategy-types strategy-id))

(define-read-only (get-protocol-fee)
  (var-get protocol-fee-percent))

(define-read-only (get-protocol-balance)
  (var-get protocol-balance))

(define-read-only (get-stake-record (staker principal) (pool-id uint))
  (map-get? stake-records {staker: staker, pool-id: pool-id}))