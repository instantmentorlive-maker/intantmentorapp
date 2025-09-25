# InstantMentor - Real-time Mentoring Platform

A comprehensive Flutter application for real-time mentoring with advanced WebSocket communication and WebRTC video calling features.

## 🚀 **Features Implemented**

### ✅ **Video Calling System (NEW!)**
- **WebRTC Peer-to-Peer Video Calls**
  - High-quality video and audio communication
  - WhatsApp-style call interface with animations
  - Picture-in-picture local video display
  - Comprehensive call controls (mute, camera, speaker)

- **Complete Call Management**
  - 11 different call states for full lifecycle management
  - Call history persistence with Supabase
  - Incoming/Outgoing/Active call screens
  - Real-time signaling via WebSocket

- **Professional UI Components**
  - Material 3 design with smooth animations
  - Responsive layout for all screen sizes
  - Accessibility support and high contrast modes
  - Industry-standard call interface design

### ✅ **Real-time Communication System**
- **Instant Call Requests & Accept/Reject Notifications**
  - Beautiful animated call notification interface
  - Video/Audio call initiation and management
  - Real-time accept/reject responses with instant feedback
  - Auto-dismiss timers and professional UI components

- **Chat During or After Call**
  - Complete real-time messaging system with Socket.IO
  - Typing indicators and message status tracking
  - Auto-scroll behavior and message persistence
  - Support for messaging during active video calls

- **Mentor Available/Busy Status Management**
  - Real-time mentor availability broadcasting
  - Quick status presets (Available, In Session, Break, Offline)
  - Custom status messages with instant updates
  - Minimizable floating status widget for mentors

### 🏗️ **Technical Architecture**

#### **Video Calling Integration**
- **WebRTC Implementation**: Peer-to-peer video/audio using flutter_webrtc
- **Signaling Service**: WebSocket-based call setup and management
- **Call Controllers**: Comprehensive call lifecycle management
- **Media Controls**: Real-time audio/video toggle and routing

#### **WebSocket Integration**
- **Socket.IO Client**: Complete real-time bidirectional communication
- **Event-driven Architecture**: 13+ specialized event types
- **Auto-reconnection**: Exponential backoff with connection health monitoring
- **Authentication Integration**: Auto-connect on login, disconnect on logout

#### **State Management**
- **Flutter Riverpod**: Comprehensive provider architecture
- **Real-time Streams**: Live data synchronization across the app
- **Role-based Access**: Different interfaces for students vs mentors

## 🛠️ **Setup Instructions**

### **Prerequisites**
- Flutter SDK (3.0+)
- Node.js (16+) for WebSocket server
- Chrome/Edge browser for web testing

### **Installation**

1. **Install Flutter Dependencies**
   ```bash
   flutter pub get
   ```

2. **Setup WebSocket Server**
   ```bash
   cd websocket_server
   npm install
   ```

### **Running the Application**

1. **Start WebSocket Server**
   ```bash
   cd websocket_server
   npm run dev
   ```
   Server runs on: `http://localhost:3000`

2. **Run Flutter App**
   ```bash
   flutter run -d chrome
   ```

3. **Test Real-time Features**
   - Navigate to "More" → "WebSocket Demo"
   - Test all communication features

4. **Test Video Calling**
   - Navigate to "More" → "Video Call Demo"
   - Test video/audio call initiation
   - Experience all call screens and controls
   - Monitor call state transitions

## 📱 **User Experience**

### **For Students**
- **Floating Help Request Button**: Always accessible help interface
- **Subject Categories**: Math, Programming, Science, General
- **Urgency Levels**: Visual color-coded priority system (Low/Medium/High)
- **Mentor Availability**: Real-time visibility of mentor status
- **Call Notifications**: Professional incoming call interface
- **Video Calling**: Seamless video/audio communication with mentors

### **For Mentors**
- **Status Management Widget**: Quick availability updates
- **Custom Status Messages**: Personalized availability descriptions
- **Help Request Notifications**: Instant student request alerts
- **Call Management**: Professional call interface with accept/reject
- **Real-time Broadcasting**: Automatic status updates to all students
- **Video Call Controls**: Complete call management with media controls

## 🌐 **WebSocket Events**

### **Video Call Management**
- `initiate_call`: Start video/audio calls with WebRTC signaling
- `accept_call`: Accept incoming calls and establish peer connection
- `reject_call`: Reject calls with reasons
- `end_call`: Terminate ongoing calls and cleanup resources
- `ice_candidate`: Exchange network connectivity information
- `call_offer`: Send WebRTC offer for call establishment
- `call_answer`: Respond to call offers

### **Call Management**
- `initiate_call`: Start video/audio calls
- `accept_call`: Accept incoming calls
- `reject_call`: Reject calls with reasons
- `end_call`: Terminate ongoing calls

### **Chat System**
- `send_message`: Real-time messaging
- `user_typing`: Live typing indicators
- `message_received`: Instant message delivery

### **Status Management**
- `mentor_available`: Mentor becomes available
- `mentor_busy`: Mentor goes offline/busy
- `student_request_help`: Student requests assistance

## 🖥️ **Server Implementation**

### **Node.js WebSocket Server**
- **Location**: `websocket_server/`
- **Technology**: Express.js + Socket.IO
- **Features**: 
  - CORS configuration
  - User authentication
  - Connection management
  - Event routing
  - API endpoints for monitoring

## 🏆 **Implementation Status**

**✅ COMPLETED - Production Ready**

All core real-time communication features are fully implemented and tested:
- Real-time calling system
- Chat during calls  
- Mentor availability status
- Student help requests
- WebSocket server infrastructure
- Beautiful responsive UI
- Comprehensive error handling

**Ready for immediate deployment and user testing!**
