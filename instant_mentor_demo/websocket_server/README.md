# WebSocket Server for InstantMentor Real-time Communication

This directory contains a Node.js WebSocket server implementation for handling real-time communication features in the InstantMentor app.

## Features

- **Call Management**: Handle call initiation, acceptance, rejection, and ending
- **Mentor Status**: Track and broadcast mentor availability status
- **Student Help Requests**: Manage help requests from students to mentors
- **Real-time Chat**: Support live messaging during sessions
- **Presence Tracking**: Monitor user online/offline status

## API/Service Requirements

### WebSocket Events

#### Call Events
- `initiate_call`: Student/Mentor initiates a video/audio call
- `accept_call`: Accept incoming call
- `reject_call`: Reject incoming call with reason
- `end_call`: End ongoing call

#### Status Events
- `mentor_available`: Mentor sets status to available
- `mentor_busy`: Mentor sets status to busy/offline
- `student_request_help`: Student requests help from mentor

#### Chat Events
- `send_message`: Send real-time message
- `user_typing`: Show typing indicator
- `user_stopped_typing`: Hide typing indicator

#### Presence Events
- `user_online`: User comes online
- `user_offline`: User goes offline

## Quick Setup

### Prerequisites
- Node.js 16+ 
- npm or yarn

### Installation

```bash
# Navigate to this directory
cd websocket_server

# Install dependencies
npm install

# Start development server
npm run dev

# Start production server
npm start
```

### Environment Variables

Create a `.env` file:

```
PORT=3000
CORS_ORIGIN=http://localhost:3000,http://localhost:8080
JWT_SECRET=your_jwt_secret_here
DB_CONNECTION_STRING=your_database_url_here
```

## Server Implementation

The server handles the following real-time communication scenarios:

1. **Instant Call Requests & Accept/Reject Notifications**
   - Students can initiate calls to mentors
   - Mentors receive real-time call notifications
   - Accept/reject responses are instantly delivered
   - Call state management throughout the session

2. **Chat During or After Call**
   - Real-time messaging during active calls
   - Message persistence for post-call review
   - Typing indicators and read receipts
   - File sharing support

3. **Mentor Available/Busy Status**
   - Real-time status updates
   - Automatic status broadcasting to students
   - Custom status messages
   - Presence tracking

## Integration with Flutter App

The Flutter app connects to this WebSocket server using Socket.IO client:

```dart
// Connection URL
final wsUrl = 'http://localhost:3000'; // Development
final wsUrl = 'wss://your-domain.com'; // Production

// Events are handled by WebSocketService in the Flutter app
await webSocketService.connect(
  userId: currentUser.id,
  userRole: currentUser.role,
  serverUrl: wsUrl,
);
```

## Testing

Use the WebSocket demo screen in the Flutter app to test all real-time features:

1. Open the app and navigate to "More" → "WebSocket Demo"
2. Test connection status
3. Try chat functionality
4. Test call initiation/acceptance
5. Verify mentor status updates

## Production Deployment

For production deployment, consider:

- Using Redis for session management
- Implementing proper authentication/authorization
- Setting up SSL/TLS for WSS connections
- Load balancing for multiple server instances
- Database integration for message persistence
- Push notification integration for offline users

## Security Considerations

- Validate all incoming WebSocket messages
- Implement rate limiting
- Use JWT tokens for authentication
- Sanitize user inputs
- Log all security events

## Monitoring

- Track connection counts
- Monitor message throughput
- Log error rates
- Measure response times
- Set up alerts for critical events
