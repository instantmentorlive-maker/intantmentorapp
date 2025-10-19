from fastapi import FastAPI, HTTPException, Depends, Request
from sqlalchemy import create_engine, Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
import razorpay
from pydantic import BaseModel
import os
from dotenv import load_dotenv
from datetime import datetime
import json

load_dotenv()

DATABASE_URL = "sqlite:///./instantmentor.db"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class Mentor(Base):
    __tablename__ = "mentors"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    phone = Column(String)
    price_per_session_inr = Column(Float, nullable=False)
    razorpay_account_id = Column(String)
    verified = Column(Boolean, default=False)
    commission_rate = Column(Float, default=0.20)

class Student(Base):
    __tablename__ = "students"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)

class Session(Base):
    __tablename__ = "sessions"
    id = Column(Integer, primary_key=True, index=True)
    mentor_id = Column(Integer, ForeignKey("mentors.id"))
    student_id = Column(Integer, ForeignKey("students.id"))
    price_paise = Column(Integer, nullable=False)
    status = Column(String, default="pending")
    razorpay_order_id = Column(String)
    razorpay_payment_id = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("sessions.id"))
    amount_paise = Column(Integer, nullable=False)
    mentor_share_paise = Column(Integer, nullable=False)
    platform_share_paise = Column(Integer, nullable=False)
    status = Column(String, default="pending")
    razorpay_raw = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

Base.metadata.create_all(bind=engine)

class MentorCreate(BaseModel):
    name: str
    email: str
    phone: str = None
    price_per_session_inr: float

class MentorUpdatePrice(BaseModel):
    price_per_session_inr: float

class MentorAttachAccount(BaseModel):
    razorpay_account_id: str

class StudentCreate(BaseModel):
    name: str
    email: str

class SessionCreate(BaseModel):
    mentor_id: int
    student_id: int

class PaymentVerify(BaseModel):
    razorpay_payment_id: str
    razorpay_order_id: str
    razorpay_signature: str

client = razorpay.Client(auth=(os.getenv("RAZORPAY_KEY_ID"), os.getenv("RAZORPAY_KEY_SECRET")))
PLATFORM_ROUTE_ACCOUNT_ID = os.getenv("PLATFORM_ROUTE_ACCOUNT_ID")
WEBHOOK_SECRET = os.getenv("RAZORPAY_WEBHOOK_SECRET")
DEFAULT_COMMISSION_RATE = float(os.getenv("DEFAULT_COMMISSION_RATE", 0.20))

app = FastAPI()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.post("/mentor/create")
def create_mentor(mentor: MentorCreate, db: Session = Depends(get_db)):
    db_mentor = Mentor(**mentor.dict())
    db.add(db_mentor)
    db.commit()
    db.refresh(db_mentor)
    return db_mentor

@app.put("/mentor/{mentor_id}/price")
def update_mentor_price(mentor_id: int, update: MentorUpdatePrice, db: Session = Depends(get_db)):
    mentor = db.query(Mentor).filter(Mentor.id == mentor_id).first()
    if not mentor:
        raise HTTPException(status_code=404, detail="Mentor not found")
    mentor.price_per_session_inr = update.price_per_session_inr
    db.commit()
    return {"message": "Price updated"}

@app.post("/mentor/{mentor_id}/attach_route_account")
def attach_account(mentor_id: int, attach: MentorAttachAccount, db: Session = Depends(get_db)):
    mentor = db.query(Mentor).filter(Mentor.id == mentor_id).first()
    if not mentor:
        raise HTTPException(status_code=404, detail="Mentor not found")
    mentor.razorpay_account_id = attach.razorpay_account_id
    db.commit()
    return {"message": "Account attached"}

@app.post("/student/create")
def create_student(student: StudentCreate, db: Session = Depends(get_db)):
    db_student = Student(**student.dict())
    db.add(db_student)
    db.commit()
    db.refresh(db_student)
    return db_student

@app.post("/session/create")
def create_session(session_req: SessionCreate, db: Session = Depends(get_db)):
    mentor = db.query(Mentor).filter(Mentor.id == session_req.mentor_id).first()
    if not mentor:
        raise HTTPException(status_code=404, detail="Mentor not found")
    student = db.query(Student).filter(Student.id == session_req.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    if not mentor.razorpay_account_id:
        raise HTTPException(status_code=400, detail="Mentor not linked to Razorpay")
    total_paise = int(mentor.price_per_session_inr * 100)
    commission_rate = mentor.commission_rate or DEFAULT_COMMISSION_RATE
    platform_share = int(total_paise * commission_rate)
    mentor_share = total_paise - platform_share
    order_data = {
        "amount": total_paise,
        "currency": "INR",
        "transfers": [
            {
                "account": mentor.razorpay_account_id,
                "amount": mentor_share,
                "currency": "INR"
            },
            {
                "account": PLATFORM_ROUTE_ACCOUNT_ID,
                "amount": platform_share,
                "currency": "INR"
            }
        ]
    }
    order = client.order.create(order_data)
    db_session = Session(
        mentor_id=session_req.mentor_id,
        student_id=session_req.student_id,
        price_paise=total_paise,
        razorpay_order_id=order["id"]
    )
    db.add(db_session)
    db.commit()
    db.refresh(db_session)
    transaction = Transaction(
        session_id=db_session.id,
        amount_paise=total_paise,
        mentor_share_paise=mentor_share,
        platform_share_paise=platform_share
    )
    db.add(transaction)
    db.commit()
    return {
        "order_id": order["id"],
        "amount": total_paise,
        "mentor_share": mentor_share,
        "platform_share": platform_share
    }

@app.post("/payment/verify")
def verify_payment(verify: PaymentVerify, db: Session = Depends(get_db)):
    try:
        client.utility.verify_payment_signature({
            "razorpay_order_id": verify.razorpay_order_id,
            "razorpay_payment_id": verify.razorpay_payment_id,
            "razorpay_signature": verify.razorpay_signature
        })
    except:
        raise HTTPException(status_code=400, detail="Invalid signature")
    session = db.query(Session).filter(Session.razorpay_order_id == verify.razorpay_order_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    session.status = "paid"
    session.razorpay_payment_id = verify.razorpay_payment_id
    transaction = db.query(Transaction).filter(Transaction.session_id == session.id).first()
    if transaction:
        transaction.status = "paid"
    db.commit()
    return {"message": "Payment verified"}

@app.post("/webhook/razorpay")
async def razorpay_webhook(request: Request, db: Session = Depends(get_db)):
    body = await request.body()
    signature = request.headers.get("X-Razorpay-Signature")
    try:
        client.utility.verify_webhook_signature(body, signature, WEBHOOK_SECRET)
    except:
        raise HTTPException(status_code=400, detail="Invalid webhook signature")
    data = json.loads(body)
    event = data["event"]
    if event in ["payment.captured", "order.paid", "transfer.processed"]:
        payment_id = data["payload"]["payment"]["entity"]["id"]
        session = db.query(Session).filter(Session.razorpay_payment_id == payment_id).first()
        if session:
            transaction = db.query(Transaction).filter(Transaction.session_id == session.id).first()
            if transaction:
                transaction.razorpay_raw = json.dumps(data)
                db.commit()
    return {"status": "ok"}