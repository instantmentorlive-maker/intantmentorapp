# InstantMentor Backend

A FastAPI backend for InstantMentor - an on-demand mentorship platform with Razorpay split payments.

## Setup

1. Navigate to the backend directory:
   ```bash
   cd server/python_backend
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Configure environment variables in `.env`:
   - `RAZORPAY_KEY_ID`: Your Razorpay test/live key ID
   - `RAZORPAY_KEY_SECRET`: Your Razorpay test/live key secret
   - `PLATFORM_ROUTE_ACCOUNT_ID`: Razorpay Route account ID for platform
   - `RAZORPAY_WEBHOOK_SECRET`: Webhook secret for verifying Razorpay webhooks
   - `DEFAULT_COMMISSION_RATE`: Default platform commission rate (e.g., 0.20 for 20%)

4. Run the server:
   ```bash
   uvicorn app:app --reload
   ```

The API will be available at `http://localhost:8000`.

## API Endpoints

### Mentor Management
- `POST /mentor/create` - Create a new mentor
- `PUT /mentor/{id}/price` - Update mentor's session price
- `POST /mentor/{id}/attach_route_account` - Link Razorpay account

### Student Management
- `POST /student/create` - Register a new student

### Session & Payment
- `POST /session/create` - Create a session with Razorpay order
- `POST /payment/verify` - Verify payment after checkout
- `POST /webhook/razorpay` - Handle Razorpay webhooks

## Testing

### Create Mentor
```bash
curl -X POST "http://localhost:8000/mentor/create" \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com", "price_per_session_inr": 150.0}'
```

### Create Student
```bash
curl -X POST "http://localhost:8000/student/create" \
  -H "Content-Type: application/json" \
  -d '{"name": "Jane Smith", "email": "jane@example.com"}'
```

### Attach Razorpay Account to Mentor (ID: 1)
```bash
curl -X POST "http://localhost:8000/mentor/1/attach_route_account" \
  -H "Content-Type: application/json" \
  -d '{"razorpay_account_id": "acc_mentor123"}'
```

### Create Session
```bash
curl -X POST "http://localhost:8000/session/create" \
  -H "Content-Type: application/json" \
  -d '{"mentor_id": 1, "student_id": 1}'
```

### Verify Payment (use actual Razorpay response)
```bash
curl -X POST "http://localhost:8000/payment/verify" \
  -H "Content-Type: application/json" \
  -d '{"razorpay_payment_id": "pay_xxx", "razorpay_order_id": "order_xxx", "razorpay_signature": "sig_xxx"}'
```

## Frontend Testing

Use the provided `test_checkout.html` to test Razorpay checkout integration locally.