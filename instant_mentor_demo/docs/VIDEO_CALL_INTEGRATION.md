# Video Call Integration - Jitsi Meet

## Why Jitsi Meet?

**Jitsi Meet** is the best free alternative to Agora for video calling:

✅ **Completely Free**: No usage limits, no API keys, no billing
✅ **Open Source**: Full control and transparency
✅ **No Backend Required**: Direct P2P connections
✅ **Professional Quality**: Used by many enterprises
✅ **Cross Platform**: Works on Web, Android, iOS, Desktop
✅ **Rich Features**: Screen sharing, chat, recording, etc.
✅ **Self-Hostable**: Can use own servers if needed

## Current Implementation

### 1. Jitsi Service (`lib/core/services/jitsi_service.dart`)
- Wraps the `jitsi_meet_flutter_sdk` package
- Handles conference joining/leaving
- Configurable server URL via environment

### 2. Integration Flow
1. **Session Request**: Mentor accepts student request
2. **Auto Navigation**: Automatically navigates to `/session/{sessionId}`
3. **Auto Join**: `LiveSessionScreen` auto-joins Jitsi room
4. **Room Naming**: Generates secure room names from session ID
5. **User Info**: Passes user name/email to Jitsi

### 3. Security Features
- Room names are derived from session IDs (not directly exposed)
- Could be enhanced with server-side hashing
- Only session participants can join (via app navigation)

## Room Naming Strategy

Current: `mentor-session-{first8CharsOfSessionId}`
Example: `mentor-session-a1b2c3d4`

**Enhancement Options:**
```dart
// Option 1: Hash with secret
String _generateSecureRoom(String sessionId) {
  final secret = dotenv.env['ROOM_SECRET'] ?? 'default';
  final hash = sha256.convert(utf8.encode('$sessionId$secret'));
  return 'session-${hash.toString().substring(0, 12)}';
}

// Option 2: Time-limited rooms
String _generateTimedRoom(String sessionId) {
  final hour = DateTime.now().hour;
  final day = DateTime.now().day;
  return 'session-$sessionId-$day$hour';
}
```

## Features Available

### ✅ Working Now
- Join/leave video calls
- Auto-navigation from session accept
- Room name generation
- User name/email passing
- Multi-platform support

### 🔄 Available in Jitsi (use native controls)
- Microphone mute/unmute
- Camera on/off
- Screen sharing
- In-call chat
- Recording (if enabled on server)
- Background blur
- Hand raising

### 🚀 Potential Enhancements
- Custom Jitsi server deployment
- Room security with passwords
- Waiting rooms for students
- Session recording integration
- Call quality monitoring
- Integration with our chat system

## Configuration

### Environment Variables (`.env`)
```bash
# Optional: Custom Jitsi server
JITSI_SERVER_URL=https://your-jitsi-server.com

# Optional: Room security
ROOM_SECRET=your-secret-key-here
```

### pubspec.yaml
```yaml
dependencies:
  jitsi_meet_flutter_sdk: ^10.2.0  # Latest stable version
```

## Usage Examples

### Basic Join
```dart
await JitsiService.instance.joinConference(
  room: 'mentor-session-abc123',
  displayName: 'John Doe',
  email: 'john@example.com',
);
```

### Leave Session
```dart
await JitsiService.instance.hangUp();
```

## Comparison with Alternatives

| Feature | Jitsi Meet | Agora | Zoom SDK | WebRTC Direct |
|---------|------------|-------|----------|---------------|
| **Cost** | Free | Paid | Paid | Free |
| **Setup Complexity** | Low | Medium | High | High |
| **Quality** | High | High | High | Variable |
| **Features** | Rich | Rich | Rich | Basic |
| **Scalability** | Good | Excellent | Excellent | Limited |
| **Backend Required** | No | Yes | Yes | Yes |

## Production Recommendations

1. **Use Custom Server**: Deploy own Jitsi server for branding/control
2. **Implement Room Security**: Add password protection or waiting rooms
3. **Monitor Quality**: Track connection stats and user feedback
4. **Backup Plan**: Have fallback to public Jitsi servers
5. **Recording**: Enable server-side recording for session review

## Troubleshooting

### Common Issues
1. **Permissions**: Ensure camera/microphone permissions
2. **Network**: Check firewall settings for WebRTC
3. **Browser Support**: Some features require modern browsers
4. **Mobile**: Test on actual devices, not just emulators

### Debug Commands
```bash
# Check Jitsi server status
curl https://meet.jit.si/

# Test WebRTC connectivity
# Visit: https://test.webrtc.org/
```

## Next Steps

1. **Test thoroughly** on different devices/networks
2. **Consider custom server** for production
3. **Add session recording** if needed
4. **Implement quality monitoring**
5. **Add waiting room** for better control
