import 'package:instant_mentor_demo/core/services/supabase_service.dart';

class EmailService {
  static EmailService? _instance;
  static EmailService get instance => _instance ??= EmailService._();

  EmailService._();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Send welcome email to new users
  Future<void> sendWelcomeEmail({
    required String userEmail,
    required String userName,
  }) async {
    final htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #0B1C49; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f8f9fa; }
            .button { 
                display: inline-block; 
                padding: 12px 24px; 
                background-color: #2563EB; 
                color: white; 
                text-decoration: none; 
                border-radius: 8px; 
                margin: 10px 0;
            }
            .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Welcome to InstantMentor!</h1>
            </div>
            <div class="content">
                <h2>Hello $userName,</h2>
                <p>Welcome to InstantMentor - your platform for connecting with expert mentors and advancing your learning journey!</p>
                
                <p>Here's what you can do next:</p>
                <ul>
                    <li>Complete your profile to get better mentor matches</li>
                    <li>Browse our amazing mentors across various subjects</li>
                    <li>Schedule your first mentoring session</li>
                    <li>Join our community and start learning!</li>
                </ul>
                
                <p style="text-align: center;">
                    <a href="https://instantmentor.app/dashboard" class="button">Get Started</a>
                </p>
                
                <p>If you have any questions, our support team is here to help!</p>
                
                <p>Best regards,<br>The InstantMentor Team</p>
            </div>
            <div class="footer">
                <p>© 2025 InstantMentor. All rights reserved.</p>
                <p>You received this email because you signed up for InstantMentor.</p>
            </div>
        </div>
    </body>
    </html>
    ''';

    await _supabase.sendEmail(
      to: userEmail,
      subject: 'Welcome to InstantMentor - Let\'s Begin Your Learning Journey!',
      htmlContent: htmlContent,
      textContent:
          'Welcome to InstantMentor, $userName! Start your learning journey today.',
    );
  }

  /// Send session confirmation email
  Future<void> sendSessionConfirmationEmail({
    required String studentEmail,
    required String mentorEmail,
    required String studentName,
    required String mentorName,
    required DateTime sessionTime,
    required Duration duration,
    required String subject,
    required String sessionId,
  }) async {
    final formattedDate =
        '${sessionTime.day}/${sessionTime.month}/${sessionTime.year}';
    final formattedTime =
        '${sessionTime.hour.toString().padLeft(2, '0')}:${sessionTime.minute.toString().padLeft(2, '0')}';

    // Email to student
    final studentHtmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #0B1C49; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f8f9fa; }
            .session-details { background-color: white; padding: 15px; border-radius: 8px; margin: 15px 0; }
            .button { 
                display: inline-block; 
                padding: 12px 24px; 
                background-color: #2563EB; 
                color: white; 
                text-decoration: none; 
                border-radius: 8px; 
                margin: 10px 5px;
            }
            .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Session Confirmed!</h1>
            </div>
            <div class="content">
                <h2>Hello $studentName,</h2>
                <p>Great news! Your mentoring session has been confirmed.</p>
                
                <div class="session-details">
                    <h3>Session Details:</h3>
                    <p><strong>Mentor:</strong> $mentorName</p>
                    <p><strong>Subject:</strong> $subject</p>
                    <p><strong>Date:</strong> $formattedDate</p>
                    <p><strong>Time:</strong> $formattedTime</p>
                    <p><strong>Duration:</strong> ${duration.inMinutes} minutes</p>
                    <p><strong>Session ID:</strong> $sessionId</p>
                </div>
                
                <p>Please be ready 5 minutes before the session starts. You'll receive a link to join the session closer to the time.</p>
                
                <p style="text-align: center;">
                    <a href="https://instantmentor.app/sessions/$sessionId" class="button">View Session</a>
                    <a href="https://instantmentor.app/calendar" class="button">Add to Calendar</a>
                </p>
                
                <p>Looking forward to your learning session!</p>
                
                <p>Best regards,<br>The InstantMentor Team</p>
            </div>
            <div class="footer">
                <p>© 2025 InstantMentor. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    ''';

    // Email to mentor
    final mentorHtmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #0B1C49; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f8f9fa; }
            .session-details { background-color: white; padding: 15px; border-radius: 8px; margin: 15px 0; }
            .button { 
                display: inline-block; 
                padding: 12px 24px; 
                background-color: #2563EB; 
                color: white; 
                text-decoration: none; 
                border-radius: 8px; 
                margin: 10px 5px;
            }
            .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>New Session Booked!</h1>
            </div>
            <div class="content">
                <h2>Hello $mentorName,</h2>
                <p>You have a new mentoring session booked with a student.</p>
                
                <div class="session-details">
                    <h3>Session Details:</h3>
                    <p><strong>Student:</strong> $studentName</p>
                    <p><strong>Subject:</strong> $subject</p>
                    <p><strong>Date:</strong> $formattedDate</p>
                    <p><strong>Time:</strong> $formattedTime</p>
                    <p><strong>Duration:</strong> ${duration.inMinutes} minutes</p>
                    <p><strong>Session ID:</strong> $sessionId</p>
                </div>
                
                <p>Please prepare any materials you might need for this session. The session link will be available in your dashboard.</p>
                
                <p style="text-align: center;">
                    <a href="https://instantmentor.app/sessions/$sessionId" class="button">View Session</a>
                    <a href="https://instantmentor.app/mentor/dashboard" class="button">Mentor Dashboard</a>
                </p>
                
                <p>Thank you for being an amazing mentor!</p>
                
                <p>Best regards,<br>The InstantMentor Team</p>
            </div>
            <div class="footer">
                <p>© 2025 InstantMentor. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    ''';

    // Send emails to both student and mentor
    await Future.wait([
      _supabase.sendEmail(
        to: studentEmail,
        subject: 'Session Confirmed - $subject with $mentorName',
        htmlContent: studentHtmlContent,
      ),
      _supabase.sendEmail(
        to: mentorEmail,
        subject: 'New Session Booked - $subject with $studentName',
        htmlContent: mentorHtmlContent,
      ),
    ]);
  }

  /// Send session reminder email
  Future<void> sendSessionReminderEmail({
    required String recipientEmail,
    required String recipientName,
    required String otherPartyName,
    required DateTime sessionTime,
    required String subject,
    required String sessionId,
    required bool isForMentor,
  }) async {
    final timeUntilSession = sessionTime.difference(DateTime.now());
    final hoursUntil = timeUntilSession.inHours;
    final minutesUntil = timeUntilSession.inMinutes % 60;

    final htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #2563EB; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f8f9fa; }
            .reminder-box { 
                background-color: #fff3cd; 
                border: 1px solid #ffeaa7; 
                padding: 15px; 
                border-radius: 8px; 
                margin: 15px 0; 
                text-align: center;
            }
            .button { 
                display: inline-block; 
                padding: 12px 24px; 
                background-color: #28a745; 
                color: white; 
                text-decoration: none; 
                border-radius: 8px; 
                margin: 10px 0;
            }
            .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>⏰ Session Reminder</h1>
            </div>
            <div class="content">
                <h2>Hello $recipientName,</h2>
                <p>This is a friendly reminder about your upcoming mentoring session.</p>
                
                <div class="reminder-box">
                    <h3>Your session starts in $hoursUntil hours and $minutesUntil minutes!</h3>
                    <p><strong>${isForMentor ? 'Student' : 'Mentor'}:</strong> $otherPartyName</p>
                    <p><strong>Subject:</strong> $subject</p>
                </div>
                
                <p>${isForMentor ? 'Please prepare any materials you might need for the session.' : 'Please be ready with your questions and learning goals.'}</p>
                
                <p style="text-align: center;">
                    <a href="https://instantmentor.app/sessions/$sessionId" class="button">Join Session</a>
                </p>
                
                <p>We're excited for your learning session!</p>
                
                <p>Best regards,<br>The InstantMentor Team</p>
            </div>
            <div class="footer">
                <p>© 2025 InstantMentor. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    ''';

    await _supabase.sendEmail(
      to: recipientEmail,
      subject: 'Reminder: Your session with $otherPartyName starts soon!',
      htmlContent: htmlContent,
    );
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail({
    required String email,
    required String resetLink,
  }) async {
    final htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #0B1C49; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f8f9fa; }
            .button { 
                display: inline-block; 
                padding: 12px 24px; 
                background-color: #dc3545; 
                color: white; 
                text-decoration: none; 
                border-radius: 8px; 
                margin: 10px 0;
            }
            .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
            .warning { background-color: #f8d7da; padding: 10px; border-radius: 5px; margin: 10px 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Password Reset Request</h1>
            </div>
            <div class="content">
                <h2>Reset Your Password</h2>
                <p>We received a request to reset your InstantMentor account password.</p>
                
                <p>Click the button below to reset your password:</p>
                
                <p style="text-align: center;">
                    <a href="$resetLink" class="button">Reset Password</a>
                </p>
                
                <div class="warning">
                    <p><strong>Important:</strong> This link will expire in 1 hour for security reasons.</p>
                </div>
                
                <p>If you didn't request this password reset, please ignore this email. Your password will remain unchanged.</p>
                
                <p>For security reasons, never share this link with anyone.</p>
                
                <p>Best regards,<br>The InstantMentor Team</p>
            </div>
            <div class="footer">
                <p>© 2025 InstantMentor. All rights reserved.</p>
                <p>If you're having trouble clicking the button, copy and paste this URL into your browser:</p>
                <p style="word-break: break-all;">$resetLink</p>
            </div>
        </div>
    </body>
    </html>
    ''';

    await _supabase.sendEmail(
      to: email,
      subject: 'Reset Your InstantMentor Password',
      htmlContent: htmlContent,
    );
  }

  /// Send session completion email with feedback request
  Future<void> sendSessionCompletionEmail({
    required String recipientEmail,
    required String recipientName,
    required String otherPartyName,
    required String subject,
    required String sessionId,
    required bool isForStudent,
  }) async {
    final htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #28a745; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f8f9fa; }
            .button { 
                display: inline-block; 
                padding: 12px 24px; 
                background-color: #2563EB; 
                color: white; 
                text-decoration: none; 
                border-radius: 8px; 
                margin: 10px 5px;
            }
            .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🎉 Session Completed!</h1>
            </div>
            <div class="content">
                <h2>Hello $recipientName,</h2>
                <p>Your mentoring session about "$subject" with $otherPartyName has been completed!</p>
                
                <p>${isForStudent ? 'We hope you learned something valuable today!' : 'Thank you for sharing your knowledge and expertise!'}</p>
                
                <p>Your feedback is important to us. Please take a moment to rate your session and provide feedback:</p>
                
                <p style="text-align: center;">
                    <a href="https://instantmentor.app/sessions/$sessionId/feedback" class="button">Rate Session</a>
                    ${isForStudent ? '<a href="https://instantmentor.app/mentors/${otherPartyName.toLowerCase().replaceAll(' ', '-')}" class="button">Book Another Session</a>' : '<a href="https://instantmentor.app/mentor/dashboard" class="button">View Dashboard</a>'}
                </p>
                
                <p>${isForStudent ? 'Keep learning and growing!' : 'Keep making a difference in students\' lives!'}</p>
                
                <p>Best regards,<br>The InstantMentor Team</p>
            </div>
            <div class="footer">
                <p>© 2025 InstantMentor. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    ''';

    await _supabase.sendEmail(
      to: recipientEmail,
      subject: 'Session Completed - Please Share Your Feedback',
      htmlContent: htmlContent,
    );
  }
}
