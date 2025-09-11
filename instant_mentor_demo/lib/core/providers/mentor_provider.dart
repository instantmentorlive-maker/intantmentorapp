import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';

// Mock mentor data provider
final mentorsProvider = Provider<List<Mentor>>((ref) {
  return [
    Mentor(
      id: 'mentor_1',
      name: 'Dr. Sarah Smith',
      email: 'sarah.smith@email.com',
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
      specializations: ['Mathematics', 'JEE', 'NEET'],
      qualifications: ['PhD Mathematics', 'IIT Alumni'],
      hourlyRate: 50.0,
      rating: 4.8,
      totalSessions: 245,
      isAvailable: true,
      totalEarnings: 12250.0,
      bio: 'Experienced mathematics mentor with 8+ years of teaching JEE and NEET aspirants.',
      yearsOfExperience: 8,
    ),
    Mentor(
      id: 'mentor_2',
      name: 'Prof. Raj Kumar',
      email: 'raj.kumar@email.com',
      createdAt: DateTime.now().subtract(const Duration(days: 400)),
      specializations: ['Physics', 'JEE', 'Class 12'],
      qualifications: ['M.Sc Physics', 'B.Ed'],
      hourlyRate: 45.0,
      rating: 4.9,
      totalSessions: 189,
      isAvailable: true,
      totalEarnings: 8505.0,
      bio: 'Physics expert specializing in JEE Main and Advanced preparation.',
      yearsOfExperience: 6,
    ),
    Mentor(
      id: 'mentor_3',
      name: 'Dr. Priya Sharma',
      email: 'priya.sharma@email.com',
      createdAt: DateTime.now().subtract(const Duration(days: 200)),
      specializations: ['Chemistry', 'NEET', 'Organic Chemistry'],
      qualifications: ['PhD Chemistry', 'Research Scholar'],
      hourlyRate: 40.0,
      rating: 4.7,
      totalSessions: 156,
      isAvailable: false,
      totalEarnings: 6240.0,
      bio: 'Chemistry mentor with special focus on organic chemistry for NEET preparation.',
      yearsOfExperience: 5,
    ),
    Mentor(
      id: 'mentor_4',
      name: 'Mr. Vikash Singh',
      email: 'vikash.singh@email.com',
      createdAt: DateTime.now().subtract(const Duration(days: 180)),
      specializations: ['English', 'IELTS', 'Communication'],
      qualifications: ['MA English', 'IELTS Certified'],
      hourlyRate: 35.0,
      rating: 4.6,
      totalSessions: 98,
      isAvailable: true,
      totalEarnings: 3430.0,
      bio: 'English language expert helping students with IELTS and communication skills.',
      yearsOfExperience: 4,
    ),
    Mentor(
      id: 'mentor_5',
      name: 'Dr. Anjali Gupta',
      email: 'anjali.gupta@email.com',
      createdAt: DateTime.now().subtract(const Duration(days: 500)),
      specializations: ['Biology', 'NEET', 'Botany'],
      qualifications: ['PhD Biology', 'Medical Background'],
      hourlyRate: 55.0,
      rating: 4.9,
      totalSessions: 312,
      isAvailable: true,
      totalEarnings: 17160.0,
      bio: 'Biology expert with medical background, specializing in NEET preparation.',
      yearsOfExperience: 10,
    ),
  ];
});

// Available mentors filter
final availableMentorsProvider = Provider<List<Mentor>>((ref) {
  final mentors = ref.watch(mentorsProvider);
  return mentors.where((mentor) => mentor.isAvailable).toList();
});

// Mentor by ID provider
final mentorByIdProvider = Provider.family<Mentor?, String>((ref, id) {
  final mentors = ref.watch(mentorsProvider);
  try {
    return mentors.firstWhere((mentor) => mentor.id == id);
  } catch (e) {
    return null;
  }
});

// Top rated mentors provider
final topRatedMentorsProvider = Provider<List<Mentor>>((ref) {
  final mentors = ref.watch(mentorsProvider);
  final sortedMentors = [...mentors];
  sortedMentors.sort((a, b) => b.rating.compareTo(a.rating));
  return sortedMentors.take(5).toList();
});

// Mentors by subject provider
final mentorsBySubjectProvider = Provider.family<List<Mentor>, String>((ref, subject) {
  final mentors = ref.watch(mentorsProvider);
  return mentors.where((mentor) => 
    mentor.specializations.any((spec) => 
      spec.toLowerCase().contains(subject.toLowerCase())
    )
  ).toList();
});
