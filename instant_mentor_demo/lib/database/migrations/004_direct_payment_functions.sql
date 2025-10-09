-- Direct payment completion function (no student wallet reserve)
-- Splits funds between platform revenue and mentor locked earnings

DROP FUNCTION IF EXISTS process_direct_session_completion(UUID, UUID, UUID, INTEGER, INTEGER, INTEGER, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION process_direct_session_completion(
    p_session_id UUID,
    p_student_id UUID,
    p_mentor_id UUID,
    p_total_amount INTEGER,
    p_mentor_amount INTEGER,
    p_platform_fee INTEGER,
    p_currency TEXT,
    p_payment_gateway TEXT,
    p_payment_intent_id TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- 1) Platform fee from external gateway to platform revenue
    IF p_platform_fee > 0 THEN
        INSERT INTO ledger_transactions (
            user_uid, transaction_type, direction, amount, from_account, to_account,
            session_id, description, payment_intent_id
        ) VALUES (
            p_student_id, 'fee', 'debit', p_platform_fee, 'externalGateway', 'platformRevenue',
            p_session_id, 'Platform fee booked (direct payment)', p_payment_intent_id
        );
    END IF;

    -- 2) Mentor lock from external gateway to mentor locked
    IF p_mentor_amount > 0 THEN
        INSERT INTO ledger_transactions (
            user_uid, transaction_type, direction, amount, from_account, to_account,
            session_id, description, payment_intent_id
        ) VALUES (
            p_mentor_id, 'mentorLock', 'credit', p_mentor_amount, 'externalGateway', 'mentorLocked',
            p_session_id, 'Mentor share locked (direct payment)', p_payment_intent_id
        );

        -- Reflect in mentor earnings
        UPDATE mentor_earnings
        SET earnings_locked = earnings_locked + p_mentor_amount
        WHERE mentor_uid = p_mentor_id;
    END IF;

    -- 3) Upsert session_payments record
    INSERT INTO session_payments (
        session_id, student_uid, mentor_uid, amount_total, amount_mentor, amount_platform,
        currency, payment_mode, payment_gateway, status, payment_intent_id, captured_at, updated_at
    ) VALUES (
        p_session_id, p_student_id, p_mentor_id, p_total_amount, p_mentor_amount, p_platform_fee,
        COALESCE(p_currency, 'INR'), 'direct', p_payment_gateway, 'captured', p_payment_intent_id, NOW(), NOW()
    )
    ON CONFLICT (session_id) DO UPDATE SET
        student_uid = EXCLUDED.student_uid,
        mentor_uid = EXCLUDED.mentor_uid,
        amount_total = EXCLUDED.amount_total,
        amount_mentor = EXCLUDED.amount_mentor,
        amount_platform = EXCLUDED.amount_platform,
        currency = EXCLUDED.currency,
        payment_mode = 'direct',
        payment_gateway = EXCLUDED.payment_gateway,
        status = 'captured',
        payment_intent_id = EXCLUDED.payment_intent_id,
        captured_at = NOW(),
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
