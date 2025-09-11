-- Seed data for mentor_profiles
-- Run this in Supabase SQL Editor after applying 003_mentor_profiles.sql

INSERT INTO public.mentor_profiles (
  user_id, name, email, profile_image, bio,
  hourly_rate, rating, rating_count, total_sessions,
  years_of_experience, is_available, exams, subjects, specializations
) VALUES
  ('mentor_1', 'Dr. Sarah Smith', 'sarah.smith@email.com', NULL,
   'Experienced mathematics mentor with 8+ years of teaching JEE and NEET aspirants.',
   50.0, 4.8, 240, 245, 8, TRUE,
   ARRAY['JEE','NEET'], ARRAY['Mathematics'], ARRAY['Mathematics','JEE','NEET']
  ),
  ('mentor_2', 'Prof. Raj Kumar', 'raj.kumar@email.com', NULL,
   'Physics expert specializing in JEE Main and Advanced preparation.',
   45.0, 4.9, 200, 189, 6, TRUE,
   ARRAY['JEE'], ARRAY['Physics'], ARRAY['Physics','JEE','Class 12']
  ),
  ('mentor_3', 'Dr. Priya Sharma', 'priya.sharma@email.com', NULL,
   'Chemistry mentor with special focus on organic chemistry for NEET preparation.',
   40.0, 4.7, 150, 156, 5, FALSE,
   ARRAY['NEET'], ARRAY['Chemistry'], ARRAY['Chemistry','NEET','Organic Chemistry']
  ),
  ('mentor_4', 'Mr. Vikash Singh', 'vikash.singh@email.com', NULL,
   'English language expert helping students with IELTS and communication skills.',
   35.0, 4.6, 90, 98, 4, TRUE,
   ARRAY['IELTS'], ARRAY['English'], ARRAY['English','IELTS','Communication']
  ),
  ('mentor_5', 'Dr. Anjali Gupta', 'anjali.gupta@email.com', NULL,
   'Biology expert with medical background, specializing in NEET preparation.',
   55.0, 4.9, 320, 312, 10, TRUE,
   ARRAY['NEET'], ARRAY['Biology'], ARRAY['Biology','NEET','Botany']
  )
ON CONFLICT (user_id) DO UPDATE SET
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  bio = EXCLUDED.bio,
  hourly_rate = EXCLUDED.hourly_rate,
  rating = EXCLUDED.rating,
  rating_count = EXCLUDED.rating_count,
  total_sessions = EXCLUDED.total_sessions,
  years_of_experience = EXCLUDED.years_of_experience,
  is_available = EXCLUDED.is_available,
  exams = EXCLUDED.exams,
  subjects = EXCLUDED.subjects,
  specializations = EXCLUDED.specializations;
