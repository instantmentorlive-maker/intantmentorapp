-- Enhanced Payments Schema for InstantMentor App
-- Based on the payments architecture document
-- Supabase PostgreSQL implementation

-- ===========================================================================
-- USER PAYMENT PROFILES TABLE
-- ===========================================================================

CREATE TABLE IF NOT EXISTS user_payment_profiles (
    uid UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    roles TEXT[] DEFAULT '{}', -- ["student", "mentor"]
    kyc_status TEXT DEFAULT 'unverified' CHECK (kyc_status IN ('unverified', 'pending', 'verified')),
    
    -- Stripe information
    stripe_customer_id TEXT,
    stripe_account_id TEXT, -- For mentors (Express accounts)
    stripe_onboarding_complete BOOLEAN DEFAULT FALSE,
    
    -- Razorpay information
    razorpay_customer_id TEXT,
    razorpay_contact_id TEXT, -- For mentors
    razorpay_fund_account_id TEXT,
    
    -- Bank account information for payouts
    bank_account_number TEXT,
    bank_ifsc_code TEXT,
    bank_account_holder_name TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_payment_profiles_roles ON user_payment_profiles USING GIN(roles);
CREATE INDEX IF NOT EXISTS idx_user_payment_profiles_kyc_status ON user_payment_profiles(kyc_status);

-- ===========================================================================
-- ENHANCED WALLETS TABLE
-- ===========================================================================

CREATE TABLE IF NOT EXISTS enhanced_wallets (
    user_uid UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    currency TEXT DEFAULT 'INR' NOT NULL,
    balance_available INTEGER DEFAULT 0 NOT NULL, -- in minor units (paise)
    balance_locked INTEGER DEFAULT 0 NOT NULL,    -- in minor units (paise)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT positive_balances CHECK (balance_available >= 0 AND balance_locked >= 0)
);

-- Index for currency lookups
CREATE INDEX IF NOT EXISTS idx_enhanced_wallets_currency ON enhanced_wallets(currency);

-- ===========================================================================
-- MENTOR EARNINGS TABLE
-- ===========================================================================

CREATE TABLE IF NOT EXISTS mentor_earnings (
    mentor_uid UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    currency TEXT DEFAULT 'INR' NOT NULL,
    earnings_available INTEGER DEFAULT 0 NOT NULL, -- in minor units (paise)
    earnings_locked INTEGER DEFAULT 0 NOT NULL,    -- in minor units (paise)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT positive_earnings CHECK (earnings_available >= 0 AND earnings_locked >= 0)
);

-- Index for currency lookups
CREATE INDEX IF NOT EXISTS idx_mentor_earnings_currency ON mentor_earnings(currency);

-- ===========================================================================
-- LEDGER TRANSACTIONS TABLE (Append-only audit trail)
-- ===========================================================================

CREATE TABLE IF NOT EXISTS ledger_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_uid UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN (
        'topup', 'reserve', 'release', 'capture', 'refund', 'payout', 'fee', 'mentorLock', 'mentorRelease'
    )),
    direction TEXT NOT NULL CHECK (direction IN ('debit', 'credit')),
    amount INTEGER NOT NULL CHECK (amount > 0), -- in minor units (paise)
    currency TEXT DEFAULT 'INR' NOT NULL,
    
    -- Account classification
    from_account TEXT NOT NULL CHECK (from_account IN (
        'studentAvailable', 'studentLocked', 'mentorAvailable', 'mentorLocked', 'platformRevenue', 'externalGateway'
    )),
    to_account TEXT NOT NULL CHECK (to_account IN (
        'studentAvailable', 'studentLocked', 'mentorAvailable', 'mentorLocked', 'platformRevenue', 'externalGateway'
    )),
    
    -- Reference information
    session_id UUID, -- Links to mentoring sessions
    payment_intent_id TEXT, -- Stripe/Razorpay payment intent ID
    reference_id TEXT, -- Generic reference for external systems
    
    -- Metadata
    description TEXT,
    metadata JSONB DEFAULT '{}',
    -- Idempotency for safe retries/webhook replays
    idempotency_key TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    CONSTRAINT different_accounts CHECK (from_account != to_account)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_ledger_transactions_user_uid ON ledger_transactions(user_uid);
CREATE INDEX IF NOT EXISTS idx_ledger_transactions_type ON ledger_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_ledger_transactions_session_id ON ledger_transactions(session_id);
CREATE INDEX IF NOT EXISTS idx_ledger_transactions_created_at ON ledger_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ledger_transactions_payment_intent ON ledger_transactions(payment_intent_id);
-- Ensure idempotency keys are unique when provided
CREATE UNIQUE INDEX IF NOT EXISTS ux_ledger_transactions_idempotency
    ON ledger_transactions(idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- ===========================================================================
-- SESSION PAYMENTS TABLE
-- ===========================================================================

CREATE TABLE IF NOT EXISTS session_payments (
    session_id UUID PRIMARY KEY,
    student_uid UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    mentor_uid UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Payment details
    amount_total INTEGER NOT NULL CHECK (amount_total > 0), -- in minor units
    amount_mentor INTEGER NOT NULL CHECK (amount_mentor >= 0), -- mentor's share
    amount_platform INTEGER NOT NULL CHECK (amount_platform >= 0), -- platform fee
    currency TEXT DEFAULT 'INR' NOT NULL,
    
    -- Payment flow
    payment_mode TEXT NOT NULL CHECK (payment_mode IN ('wallet', 'direct')),
    payment_gateway TEXT CHECK (payment_gateway IN ('stripe', 'razorpay')),
    
    -- Status tracking
    status TEXT DEFAULT 'created' CHECK (status IN ('created', 'reserved', 'captured', 'released', 'refunded')),
    
    -- External references
    payment_intent_id TEXT,
    charge_id TEXT,
    
    -- Timestamps
    reserved_at TIMESTAMP WITH TIME ZONE,
    captured_at TIMESTAMP WITH TIME ZONE,
    released_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT valid_amounts CHECK (amount_total = amount_mentor + amount_platform)
);

-- Indexes for session payments
CREATE INDEX IF NOT EXISTS idx_session_payments_student ON session_payments(student_uid);
CREATE INDEX IF NOT EXISTS idx_session_payments_mentor ON session_payments(mentor_uid);
CREATE INDEX IF NOT EXISTS idx_session_payments_status ON session_payments(status);
CREATE INDEX IF NOT EXISTS idx_session_payments_created_at ON session_payments(created_at DESC);

-- ===========================================================================
-- PAYOUT REQUESTS TABLE
-- ===========================================================================

CREATE TABLE IF NOT EXISTS payout_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mentor_uid UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Payout details
    amount INTEGER NOT NULL CHECK (amount > 0), -- in minor units
    currency TEXT DEFAULT 'INR' NOT NULL,
    
    -- Processing information
    status TEXT DEFAULT 'created' CHECK (status IN ('created', 'pending', 'paid', 'failed')),
    gateway TEXT CHECK (gateway IN ('stripe', 'razorpay')),
    
    -- External references
    payout_id TEXT, -- Gateway payout ID
    transfer_id TEXT, -- Gateway transfer ID
    
    -- Bank account snapshot (for audit)
    bank_account_number TEXT,
    bank_ifsc_code TEXT,
    bank_account_holder_name TEXT,
    
    -- Processing timestamps
    processed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Error handling
    failure_reason TEXT,
    retry_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for payout requests
CREATE INDEX IF NOT EXISTS idx_payout_requests_mentor ON payout_requests(mentor_uid);
CREATE INDEX IF NOT EXISTS idx_payout_requests_status ON payout_requests(status);
CREATE INDEX IF NOT EXISTS idx_payout_requests_created_at ON payout_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payout_requests_gateway ON payout_requests(gateway);

-- ===========================================================================
-- FUNCTIONS AND TRIGGERS
-- ===========================================================================

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_user_payment_profiles_updated_at
    BEFORE UPDATE ON user_payment_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_enhanced_wallets_updated_at
    BEFORE UPDATE ON enhanced_wallets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_mentor_earnings_updated_at
    BEFORE UPDATE ON mentor_earnings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_session_payments_updated_at
    BEFORE UPDATE ON session_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_payout_requests_updated_at
    BEFORE UPDATE ON payout_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ===========================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ===========================================================================

-- Enable RLS on all tables
ALTER TABLE user_payment_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE enhanced_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentor_earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_requests ENABLE ROW LEVEL SECURITY;

-- User payment profiles: Users can only access their own profile
CREATE POLICY "Users can view own payment profile" ON user_payment_profiles
    FOR SELECT USING (auth.uid() = uid);

CREATE POLICY "Users can update own payment profile" ON user_payment_profiles
    FOR UPDATE USING (auth.uid() = uid);

CREATE POLICY "Users can insert own payment profile" ON user_payment_profiles
    FOR INSERT WITH CHECK (auth.uid() = uid);

-- Enhanced wallets: Users can only access their own wallet
CREATE POLICY "Users can view own wallet" ON enhanced_wallets
    FOR SELECT USING (auth.uid() = user_uid);

CREATE POLICY "Users can update own wallet" ON enhanced_wallets
    FOR UPDATE USING (auth.uid() = user_uid);

CREATE POLICY "Users can insert own wallet" ON enhanced_wallets
    FOR INSERT WITH CHECK (auth.uid() = user_uid);

-- Mentor earnings: Mentors can only access their own earnings
CREATE POLICY "Mentors can view own earnings" ON mentor_earnings
    FOR SELECT USING (auth.uid() = mentor_uid);

CREATE POLICY "Mentors can update own earnings" ON mentor_earnings
    FOR UPDATE USING (auth.uid() = mentor_uid);

CREATE POLICY "Mentors can insert own earnings" ON mentor_earnings
    FOR INSERT WITH CHECK (auth.uid() = mentor_uid);

-- Ledger transactions: Users can view transactions related to them
CREATE POLICY "Users can view own transactions" ON ledger_transactions
    FOR SELECT USING (auth.uid() = user_uid);

CREATE POLICY "System can insert transactions" ON ledger_transactions
    FOR INSERT WITH CHECK (true); -- Controlled by application logic

-- Session payments: Students and mentors can view their session payments
CREATE POLICY "Users can view related session payments" ON session_payments
    FOR SELECT USING (auth.uid() = student_uid OR auth.uid() = mentor_uid);

CREATE POLICY "System can manage session payments" ON session_payments
    FOR ALL USING (true); -- Controlled by application logic

-- Payout requests: Mentors can view their own payout requests
CREATE POLICY "Mentors can view own payout requests" ON payout_requests
    FOR SELECT USING (auth.uid() = mentor_uid);

CREATE POLICY "Mentors can insert own payout requests" ON payout_requests
    FOR INSERT WITH CHECK (auth.uid() = mentor_uid);

CREATE POLICY "System can update payout requests" ON payout_requests
    FOR UPDATE USING (true); -- Controlled by application logic

-- ===========================================================================
-- INITIAL DATA SETUP FUNCTIONS
-- ===========================================================================

-- Function to initialize wallet for new user
CREATE OR REPLACE FUNCTION initialize_user_wallet(user_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO enhanced_wallets (user_uid, currency, balance_available, balance_locked)
    VALUES (user_id, 'INR', 0, 0)
    ON CONFLICT (user_uid) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to release all due mentor earnings (T+24h after capture)
CREATE OR REPLACE FUNCTION release_due_mentor_earnings()
RETURNS INTEGER AS $$
DECLARE
    r RECORD;
    released_count INTEGER := 0;
BEGIN
    FOR r IN (
        SELECT sp.session_id, sp.mentor_uid, sp.amount_mentor
        FROM session_payments sp
        WHERE sp.status = 'captured'
          AND sp.captured_at IS NOT NULL
          AND sp.released_at IS NULL
          AND sp.captured_at <= NOW() - INTERVAL '24 hours'
    ) LOOP
        PERFORM release_mentor_earnings(r.session_id, r.mentor_uid, r.amount_mentor);
        released_count := released_count + 1;
    END LOOP;
    RETURN released_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- process_session_refund wrapper
CREATE OR REPLACE FUNCTION process_session_refund(
    session_id UUID,
    student_id UUID,
    mentor_id UUID,
    refund_total INTEGER,
    refund_mentor_share INTEGER,
    refund_platform_share INTEGER
)
RETURNS VOID AS $$
BEGIN
    PERFORM refund_session_payment(session_id, student_id, mentor_id, refund_total, refund_mentor_share, refund_platform_share);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================================================
-- RPC WRAPPER FUNCTIONS (compat with app code)
-- ===========================================================================

-- process_wallet_topup wrapper
CREATE OR REPLACE FUNCTION process_wallet_topup(
    user_id UUID,
    amount_minor INTEGER,
    transaction_data JSONB DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    PERFORM wallet_topup(
        user_id,
        amount_minor,
        COALESCE(transaction_data->>'gatewayId', transaction_data->>'payment_intent_id')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- process_funds_reserve wrapper
CREATE OR REPLACE FUNCTION process_funds_reserve(
    user_id UUID,
    amount_minor INTEGER,
    session_id UUID,
    transaction_data JSONB DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN wallet_reserve_funds(user_id, amount_minor, session_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- process_funds_release wrapper
CREATE OR REPLACE FUNCTION process_funds_release(
    user_id UUID,
    amount_minor INTEGER,
    session_id UUID,
    transaction_data JSONB DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    PERFORM wallet_release_reservation(user_id, amount_minor, session_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- process_session_completion wrapper
CREATE OR REPLACE FUNCTION process_session_completion(
    session_id UUID,
    student_id UUID,
    mentor_id UUID,
    total_amount INTEGER,
    mentor_amount INTEGER,
    platform_fee INTEGER,
    transactions_data JSONB DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    PERFORM capture_session_payment(session_id, student_id, mentor_id, total_amount, mentor_amount, platform_fee);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- process_mentor_earnings_release wrapper
CREATE OR REPLACE FUNCTION process_mentor_earnings_release(
    mentor_id UUID,
    amount_minor INTEGER,
    session_id UUID,
    transaction_data JSONB DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    PERFORM release_mentor_earnings(session_id, mentor_id, amount_minor);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================================================
-- COMPATIBILITY VIEWS (to match app queries expecting simple names)
-- ===========================================================================

-- Wallets view expected by app (wallets)
CREATE OR REPLACE VIEW wallets AS
SELECT 
  ew.user_uid AS uid,
  ew.currency AS currency,
  ew.balance_available AS balance_available,
  ew.balance_locked AS balance_locked,
  ew.updated_at AS "updatedAt"
FROM enhanced_wallets ew;

-- Earnings view expected by app (earnings)
CREATE OR REPLACE VIEW earnings AS
SELECT 
  me.mentor_uid AS "mentorUid",
  me.currency AS currency,
  me.earnings_available AS earnings_available,
  me.earnings_locked AS earnings_locked,
  me.updated_at AS "updatedAt"
FROM mentor_earnings me;

-- Transactions view expected by app (transactions)
CREATE OR REPLACE VIEW transactions AS
SELECT 
  lt.id AS "txId",
  lt.transaction_type AS "type",
  lt.direction AS "direction",
  lt.amount AS amount,
  lt.currency AS currency,
  lt.from_account AS "fromAccount",
  lt.to_account AS "toAccount",
  lt.user_uid AS "userId",
  NULL::UUID AS "counterpartyUserId",
  lt.session_id AS "sessionId",
  NULL::TEXT AS gateway,
  COALESCE(lt.payment_intent_id, lt.reference_id) AS "gatewayId",
  lt.idempotency_key AS "idempotencyKey",
  lt.created_at AS "createdAt",
  lt.metadata AS metadata
FROM ledger_transactions lt;

-- Function to initialize earnings for new mentor
CREATE OR REPLACE FUNCTION initialize_mentor_earnings(mentor_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO mentor_earnings (mentor_uid, currency, earnings_available, earnings_locked)
    VALUES (mentor_id, 'INR', 0, 0)
    ON CONFLICT (mentor_uid) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to initialize payment profile for new user
CREATE OR REPLACE FUNCTION initialize_payment_profile(user_id UUID, user_roles TEXT[])
RETURNS VOID AS $$
BEGIN
    INSERT INTO user_payment_profiles (uid, roles, kyc_status)
    VALUES (user_id, user_roles, 'unverified')
    ON CONFLICT (uid) DO NOTHING;
    
    -- Initialize wallet for all users
    PERFORM initialize_user_wallet(user_id);
    
    -- Initialize earnings for mentors
    IF 'mentor' = ANY(user_roles) THEN
        PERFORM initialize_mentor_earnings(user_id);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================================================
-- WALLET OPERATION FUNCTIONS
-- ===========================================================================

-- Function to add funds to wallet (topup)
CREATE OR REPLACE FUNCTION wallet_topup(
    user_id UUID,
    amount_minor INTEGER,
    payment_intent_id TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Update wallet balance
    UPDATE enhanced_wallets
    SET balance_available = balance_available + amount_minor
    WHERE user_uid = user_id;
    
    -- Record transaction
    INSERT INTO ledger_transactions (
        user_uid, transaction_type, direction, amount, from_account, to_account,
        payment_intent_id, description
    ) VALUES (
        user_id, 'topup', 'credit', amount_minor, 'externalGateway', 'studentAvailable',
        payment_intent_id, 'Wallet top-up'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reserve funds for session
CREATE OR REPLACE FUNCTION wallet_reserve_funds(
    user_id UUID,
    amount_minor INTEGER,
    session_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    current_balance INTEGER;
BEGIN
    -- Check available balance
    SELECT balance_available INTO current_balance
    FROM enhanced_wallets
    WHERE user_uid = user_id;
    
    IF current_balance < amount_minor THEN
        RETURN FALSE; -- Insufficient balance
    END IF;
    
    -- Move funds from available to locked
    UPDATE enhanced_wallets
    SET balance_available = balance_available - amount_minor,
        balance_locked = balance_locked + amount_minor
    WHERE user_uid = user_id;
    
    -- Record transaction
    INSERT INTO ledger_transactions (
        user_uid, transaction_type, direction, amount, from_account, to_account,
        session_id, description
    ) VALUES (
        user_id, 'reserve', 'debit', amount_minor, 'studentAvailable', 'studentLocked',
        session_id, 'Funds reserved for session'
    );
    
    -- Update session status to reserved
    UPDATE session_payments
    SET status = 'reserved', reserved_at = NOW(), updated_at = NOW()
    WHERE session_payments.session_id = session_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to capture session payment (split between mentor and platform)
CREATE OR REPLACE FUNCTION capture_session_payment(
    session_id UUID,
    student_id UUID,
    mentor_id UUID,
    total_amount INTEGER,
    mentor_amount INTEGER,
    platform_fee INTEGER
)
RETURNS VOID AS $$
BEGIN
    -- 1) Debit student's locked funds (wallet mode)
    UPDATE enhanced_wallets
    SET balance_locked = balance_locked - total_amount
    WHERE user_uid = student_id;

    -- 2) Lock mentor share (do NOT make available yet)
    UPDATE mentor_earnings
    SET earnings_locked = earnings_locked + mentor_amount
    WHERE mentor_uid = mentor_id;

    -- 3) Append ledger entries that reflect the split
    -- 3a) Capture from student locked to external gateway (gross)
    INSERT INTO ledger_transactions (
        user_uid, transaction_type, direction, amount, from_account, to_account,
        session_id, description
    ) VALUES (
        student_id, 'capture', 'debit', total_amount, 'studentLocked', 'externalGateway',
        session_id, 'Session payment captured (wallet mode)'
    );

    -- 3b) Platform fee from external gateway to platform revenue
    IF platform_fee > 0 THEN
        INSERT INTO ledger_transactions (
            user_uid, transaction_type, direction, amount, from_account, to_account,
            session_id, description
        ) VALUES (
            student_id, 'fee', 'debit', platform_fee, 'externalGateway', 'platformRevenue',
            session_id, 'Platform fee booked'
        );
    END IF;

    -- 3c) Mentor lock from external gateway to mentor locked
    IF mentor_amount > 0 THEN
        INSERT INTO ledger_transactions (
            user_uid, transaction_type, direction, amount, from_account, to_account,
            session_id, description
        ) VALUES (
            mentor_id, 'mentorLock', 'credit', mentor_amount, 'externalGateway', 'mentorLocked',
            session_id, 'Mentor share locked (to be released after T+delay)'
        );
    END IF;

    -- 4) Update session state to captured
    UPDATE session_payments
    SET status = 'captured', captured_at = NOW(), updated_at = NOW(),
        amount_total = total_amount,
        amount_mentor = mentor_amount,
        amount_platform = platform_fee
    WHERE session_payments.session_id = session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to release reserved funds back to available (pre-start cancel)
CREATE OR REPLACE FUNCTION wallet_release_reservation(
    user_id UUID,
    amount_minor INTEGER,
    session_id UUID
)
RETURNS VOID AS $$
BEGIN
    -- Move funds from locked back to available
    UPDATE enhanced_wallets
    SET balance_locked = GREATEST(balance_locked - amount_minor, 0),
        balance_available = balance_available + amount_minor
    WHERE user_uid = user_id;

    -- Append ledger entry
    INSERT INTO ledger_transactions (
        user_uid, transaction_type, direction, amount, from_account, to_account,
        session_id, description
    ) VALUES (
        user_id, 'release', 'credit', amount_minor, 'studentLocked', 'studentAvailable',
        session_id, 'Reservation released (pre-start cancel)'
    );

    -- Update session status
    UPDATE session_payments
    SET status = 'released', released_at = NOW(), updated_at = NOW()
    WHERE session_payments.session_id = session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to release mentor locked earnings after delay window
CREATE OR REPLACE FUNCTION release_mentor_earnings(
    session_id UUID,
    mentor_id UUID,
    amount_minor INTEGER
)
RETURNS VOID AS $$
BEGIN
    -- Move mentor earnings from locked to available
    UPDATE mentor_earnings
    SET earnings_locked = GREATEST(earnings_locked - amount_minor, 0),
        earnings_available = earnings_available + amount_minor
    WHERE mentor_uid = mentor_id;

    -- Append ledger entry
    INSERT INTO ledger_transactions (
        user_uid, transaction_type, direction, amount, from_account, to_account,
        session_id, description
    ) VALUES (
        mentor_id, 'mentorRelease', 'credit', amount_minor, 'mentorLocked', 'mentorAvailable',
        session_id, 'Mentor earnings released after delay'
    );

    -- Update session status (if fully released, mark released)
    UPDATE session_payments
    SET status = 'released', released_at = NOW(), updated_at = NOW()
    WHERE session_id = session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process a post-capture refund (amounts provided by caller)
CREATE OR REPLACE FUNCTION refund_session_payment(
    session_id UUID,
    student_id UUID,
    mentor_id UUID,
    refund_total INTEGER,
    refund_mentor_share INTEGER,
    refund_platform_share INTEGER
)
RETURNS VOID AS $$
BEGIN
    -- 1) Refund to student wallet (or act as accounting entry)
    UPDATE enhanced_wallets
    SET balance_available = balance_available + refund_total
    WHERE user_uid = student_id;

    INSERT INTO ledger_transactions (
        user_uid, transaction_type, direction, amount, from_account, to_account,
        session_id, description
    ) VALUES (
        student_id, 'refund', 'credit', refund_total, 'externalGateway', 'studentAvailable',
        session_id, 'Refund to student (post-capture)'
    );

    -- 2) Reverse platform revenue if any
    IF refund_platform_share > 0 THEN
        INSERT INTO ledger_transactions (
            user_uid, transaction_type, direction, amount, from_account, to_account,
            session_id, description
        ) VALUES (
            student_id, 'refund', 'debit', refund_platform_share, 'platformRevenue', 'externalGateway',
            session_id, 'Platform fee reversed (refund)'
        );
    END IF;

    -- 3) Reduce mentor earnings (prefer locked; if insufficient, reduce available)
    IF refund_mentor_share > 0 THEN
        DECLARE v_locked_before INTEGER;
        DECLARE v_from_locked INTEGER;
        DECLARE v_from_available INTEGER;
        BEGIN
            SELECT earnings_locked INTO v_locked_before FROM mentor_earnings WHERE mentor_uid = mentor_id;
            v_from_locked := LEAST(COALESCE(v_locked_before, 0), refund_mentor_share);
            v_from_available := GREATEST(refund_mentor_share - v_from_locked, 0);

            UPDATE mentor_earnings
            SET earnings_locked = earnings_locked - v_from_locked,
                earnings_available = GREATEST(earnings_available - v_from_available, 0)
            WHERE mentor_uid = mentor_id;

            IF v_from_locked > 0 THEN
                INSERT INTO ledger_transactions (
                    user_uid, transaction_type, direction, amount, from_account, to_account,
                    session_id, description
                ) VALUES (
                    mentor_id, 'refund', 'debit', v_from_locked, 'mentorLocked', 'externalGateway',
                    session_id, 'Mentor share reversed from locked (refund)'
                );
            END IF;

            IF v_from_available > 0 THEN
                INSERT INTO ledger_transactions (
                    user_uid, transaction_type, direction, amount, from_account, to_account,
                    session_id, description
                ) VALUES (
                    mentor_id, 'refund', 'debit', v_from_available, 'mentorAvailable', 'externalGateway',
                    session_id, 'Mentor share reversed from available (refund)'
                );
            END IF;
        END;
    END IF;

    -- 4) Mark session as refunded (idempotent by session)
    UPDATE session_payments
    SET status = 'refunded', updated_at = NOW()
    WHERE session_payments.session_id = session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;