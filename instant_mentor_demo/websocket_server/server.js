const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const app = express();
const server = http.createServer(app);

// Configure CORS
const corsOptions = {
  origin: process.env.CORS_ORIGIN?.split(',') || ["http://localhost:3000", "http://localhost:8080"],
  credentials: true
};

app.use(cors(corsOptions));
app.use(express.json());

// Configure Socket.IO
const io = socketIo(server, {
  cors: corsOptions,
  transports: ['websocket', 'polling']
});

// In-memory storage (use Redis in production)
const connectedUsers = new Map(); // userId -> socket info
const mentorStatuses = new Map(); // mentorId -> status info
const activeCalls = new Map(); // callId -> call info
const chatRooms = new Map(); // roomId -> participants

// Middleware for socket authentication (simplified)
io.use((socket, next) => {
  const userId = socket.handshake.auth.userId;
  const userRole = socket.handshake.auth.userRole;
  
  if (!userId || !userRole) {
    return next(new Error('Authentication required'));
  }
  
  socket.userId = userId;
  socket.userRole = userRole;
  next();
});

io.on('connection', (socket) => {
  console.log(`🌐 User connected: ${socket.userId} (${socket.userRole})`);
  
  // Store user connection
  connectedUsers.set(socket.userId, {
    socketId: socket.id,
    userId: socket.userId,
    userRole: socket.userRole,
    connectedAt: new Date(),
    lastSeen: new Date()
  });

  // Broadcast user online status
  socket.broadcast.emit('user_online', {
    userId: socket.userId,
    userRole: socket.userRole,
    timestamp: new Date().toISOString()
  });

  // Send current mentor statuses to new connection
  if (socket.userRole === 'student') {
    const availableMentors = Array.from(mentorStatuses.values())
      .filter(status => status.isAvailable);
    
    socket.emit('mentor_statuses', availableMentors);
  }

  // Handle user presence
  socket.on('user_online', (data) => {
    console.log(`📡 User online: ${socket.userId}`);
    socket.broadcast.emit('user_online', {
      userId: socket.userId,
      userRole: socket.userRole,
      ...data
    });
  });

  // Handle chat messages
  socket.on('send_message', (data) => {
    console.log(`💬 Message from ${socket.userId}:`, data);
    
    const message = {
      id: uuidv4(),
      senderId: socket.userId,
      receiverId: data.receiverId,
      content: data.content,
      timestamp: new Date().toISOString(),
      type: data.type || 'text'
    };

    // Send to specific user if receiverId provided
    if (data.receiverId) {
      const receiverConnection = connectedUsers.get(data.receiverId);
      if (receiverConnection) {
        io.to(receiverConnection.socketId).emit('message_received', message);
      }
    } else {
      // Broadcast to all users (group chat)
      socket.broadcast.emit('message_received', message);
    }

    // Confirm message sent
    socket.emit('message_sent', message);
  });

  // Handle typing indicators
  socket.on('user_typing', (data) => {
    if (data.receiverId) {
      const receiverConnection = connectedUsers.get(data.receiverId);
      if (receiverConnection) {
        io.to(receiverConnection.socketId).emit('user_typing', {
          userId: socket.userId,
          ...data
        });
      }
    }
  });

  socket.on('user_stopped_typing', (data) => {
    if (data.receiverId) {
      const receiverConnection = connectedUsers.get(data.receiverId);
      if (receiverConnection) {
        io.to(receiverConnection.socketId).emit('user_stopped_typing', {
          userId: socket.userId,
          ...data
        });
      }
    }
  });

  // Handle call initiation
  socket.on('initiate_call', (data) => {
    console.log(`📞 Call initiated by ${socket.userId} to ${data.receiverId}`);
    
    const callId = uuidv4();
    const call = {
      id: callId,
      callerId: socket.userId,
      receiverId: data.receiverId,
      callType: data.callType || 'video',
      status: 'ringing',
      initiatedAt: new Date().toISOString(),
      ...data
    };

    activeCalls.set(callId, call);

    // Send call notification to receiver
    const receiverConnection = connectedUsers.get(data.receiverId);
    if (receiverConnection) {
      io.to(receiverConnection.socketId).emit('call_initiated', {
        callId,
        callerId: socket.userId,
        callerName: data.callerName || 'Unknown Caller',
        callType: data.callType || 'video',
        ...data
      });
    }

    // Confirm call initiated to caller
    socket.emit('call_initiated_confirmed', { callId, ...call });
  });

  // Handle call acceptance
  socket.on('accept_call', (data) => {
    console.log(`✅ Call accepted by ${socket.userId}: ${data.callId}`);
    
    const call = activeCalls.get(data.callId);
    if (call) {
      call.status = 'accepted';
      call.acceptedAt = new Date().toISOString();
      
      // Notify caller
      const callerConnection = connectedUsers.get(call.callerId);
      if (callerConnection) {
        io.to(callerConnection.socketId).emit('call_accepted', {
          callId: data.callId,
          acceptedBy: socket.userId,
          ...data
        });
      }
    }
  });

  // Handle call rejection
  socket.on('reject_call', (data) => {
    console.log(`❌ Call rejected by ${socket.userId}: ${data.callId}`);
    
    const call = activeCalls.get(data.callId);
    if (call) {
      call.status = 'rejected';
      call.rejectedAt = new Date().toISOString();
      call.rejectionReason = data.reason || 'Call declined';
      
      // Notify caller
      const callerConnection = connectedUsers.get(call.callerId);
      if (callerConnection) {
        io.to(callerConnection.socketId).emit('call_rejected', {
          callId: data.callId,
          rejectedBy: socket.userId,
          reason: data.reason || 'Call declined',
          ...data
        });
      }
      
      // Remove call from active calls
      activeCalls.delete(data.callId);
    }
  });

  // Handle call ending
  socket.on('end_call', (data) => {
    console.log(`📞 Call ended by ${socket.userId}: ${data.callId}`);
    
    const call = activeCalls.get(data.callId);
    if (call) {
      call.status = 'ended';
      call.endedAt = new Date().toISOString();
      
      // Notify other participant
      const otherUserId = call.callerId === socket.userId ? call.receiverId : call.callerId;
      const otherConnection = connectedUsers.get(otherUserId);
      if (otherConnection) {
        io.to(otherConnection.socketId).emit('call_ended', {
          callId: data.callId,
          endedBy: socket.userId,
          ...data
        });
      }
      
      // Remove call from active calls
      activeCalls.delete(data.callId);
    }
  });

  // Handle mentor status updates
  socket.on('mentor_available', (data) => {
    if (socket.userRole === 'mentor') {
      console.log(`👨‍🏫 Mentor ${socket.userId} is now available`);
      
      const status = {
        mentorId: socket.userId,
        isAvailable: true,
        statusMessage: data.statusMessage || 'Available for sessions',
        updatedAt: new Date().toISOString(),
        ...data
      };
      
      mentorStatuses.set(socket.userId, status);
      
      // Broadcast to all students
      socket.broadcast.emit('mentor_status_update', status);
    }
  });

  socket.on('mentor_busy', (data) => {
    if (socket.userRole === 'mentor') {
      console.log(`👨‍🏫 Mentor ${socket.userId} is now busy`);
      
      const status = {
        mentorId: socket.userId,
        isAvailable: false,
        statusMessage: data.statusMessage || 'Currently busy',
        updatedAt: new Date().toISOString(),
        ...data
      };
      
      mentorStatuses.set(socket.userId, status);
      
      // Broadcast to all students
      socket.broadcast.emit('mentor_status_update', status);
    }
  });

  // Handle student help requests
  socket.on('student_request_help', (data) => {
    console.log(`🆘 Help request from ${socket.userId}:`, data);
    
    const helpRequest = {
      id: uuidv4(),
      studentId: socket.userId,
      mentorId: data.mentorId,
      subject: data.subject,
      message: data.message || '',
      urgency: data.urgency || 'medium',
      requestedAt: new Date().toISOString(),
      status: 'pending',
      ...data
    };

    if (data.mentorId === 'broadcast_to_mentors') {
      // Broadcast to all available mentors
      connectedUsers.forEach((connection, userId) => {
        if (connection.userRole === 'mentor') {
          const mentorStatus = mentorStatuses.get(userId);
          if (mentorStatus?.isAvailable) {
            io.to(connection.socketId).emit('help_request_received', helpRequest);
          }
        }
      });
    } else {
      // Send to specific mentor
      const mentorConnection = connectedUsers.get(data.mentorId);
      if (mentorConnection) {
        io.to(mentorConnection.socketId).emit('help_request_received', helpRequest);
      }
    }

    // Confirm request sent
    socket.emit('help_request_sent', helpRequest);
  });

  // Handle session management
  socket.on('join_session', (data) => {
    const sessionId = data.sessionId;
    socket.join(sessionId);
    
    console.log(`📚 ${socket.userId} joined session: ${sessionId}`);
    
    // Notify other session participants
    socket.to(sessionId).emit('user_joined_session', {
      userId: socket.userId,
      userRole: socket.userRole,
      sessionId,
      joinedAt: new Date().toISOString()
    });
  });

  socket.on('leave_session', (data) => {
    const sessionId = data.sessionId;
    socket.leave(sessionId);
    
    console.log(`📚 ${socket.userId} left session: ${sessionId}`);
    
    // Notify other session participants
    socket.to(sessionId).emit('user_left_session', {
      userId: socket.userId,
      userRole: socket.userRole,
      sessionId,
      leftAt: new Date().toISOString()
    });
  });

  // Handle ping for connection health
  socket.on('ping', (data) => {
    const user = connectedUsers.get(socket.userId);
    if (user) {
      user.lastSeen = new Date();
    }
    socket.emit('pong', { timestamp: new Date().toISOString() });
  });

  // Handle disconnection
  socket.on('disconnect', (reason) => {
    console.log(`🔌 User disconnected: ${socket.userId} (${reason})`);
    
    // Remove from connected users
    connectedUsers.delete(socket.userId);
    
    // Update mentor status to offline if mentor
    if (socket.userRole === 'mentor') {
      const status = {
        mentorId: socket.userId,
        isAvailable: false,
        statusMessage: 'Offline',
        updatedAt: new Date().toISOString()
      };
      mentorStatuses.set(socket.userId, status);
      socket.broadcast.emit('mentor_status_update', status);
    }
    
    // End any active calls
    activeCalls.forEach((call, callId) => {
      if (call.callerId === socket.userId || call.receiverId === socket.userId) {
        const otherUserId = call.callerId === socket.userId ? call.receiverId : call.callerId;
        const otherConnection = connectedUsers.get(otherUserId);
        if (otherConnection) {
          io.to(otherConnection.socketId).emit('call_ended', {
            callId,
            endedBy: socket.userId,
            reason: 'User disconnected'
          });
        }
        activeCalls.delete(callId);
      }
    });
    
    // Broadcast user offline status
    socket.broadcast.emit('user_offline', {
      userId: socket.userId,
      userRole: socket.userRole,
      timestamp: new Date().toISOString()
    });
  });
});

// API endpoints for status monitoring
app.get('/api/status', (req, res) => {
  res.json({
    status: 'online',
    connectedUsers: connectedUsers.size,
    activeCalls: activeCalls.size,
    availableMentors: Array.from(mentorStatuses.values()).filter(s => s.isAvailable).length,
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

app.get('/api/users', (req, res) => {
  const users = Array.from(connectedUsers.values()).map(user => ({
    userId: user.userId,
    userRole: user.userRole,
    connectedAt: user.connectedAt,
    lastSeen: user.lastSeen
  }));
  res.json(users);
});

app.get('/api/mentors', (req, res) => {
  const mentors = Array.from(mentorStatuses.values());
  res.json(mentors);
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 InstantMentor WebSocket Server running on port ${PORT}`);
  console.log(`📡 Socket.IO endpoint: http://localhost:${PORT}`);
  console.log(`📊 Status API: http://localhost:${PORT}/api/status`);
});
