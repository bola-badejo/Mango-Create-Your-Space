const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

// Store active sessions
const sessions = new Map();
// Store socket to user mapping
const socketToUser = new Map();

// Session management
class SessionManager {
  constructor() {
    this.sessions = new Map();
  }

  createSession(hostId, title, isPrivate = false) {
    const sessionId = uuidv4();
    const session = {
      id: sessionId,
      hostId,
      title,
      isPrivate,
      participants: new Map(),
      speakers: new Map(),
      status: 'live',
      createdAt: new Date(),
      pendingRequests: new Set()
    };

    // Add host as first speaker
    session.speakers.set(hostId, {
      id: hostId,
      isMuted: false,
      isHost: true
    });

    this.sessions.set(sessionId, session);
    return session;
  }

  getSession(sessionId) {
    return this.sessions.get(sessionId);
  }

  joinSession(sessionId, user) {
    const session = this.sessions.get(sessionId);
    if (!session) return null;

    session.participants.set(user.id, user);
    return session;
  }

  leaveSession(sessionId, userId) {
    const session = this.sessions.get(sessionId);
    if (!session) return;

    session.participants.delete(userId);
    session.speakers.delete(userId);
    session.pendingRequests.delete(userId);

    // If host leaves, end session
    if (session.hostId === userId) {
      this.endSession(sessionId);
    }

    return session;
  }

  requestToSpeak(sessionId, userId) {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.pendingRequests.add(userId);
    }
    return session;
  }

  approveSpeaker(sessionId, userId) {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.pendingRequests.delete(userId);
      session.speakers.set(userId, {
        id: userId,
        isMuted: false,
        isHost: false
      });
    }
    return session;
  }

  toggleMute(sessionId, userId, muted) {
    const session = this.sessions.get(sessionId);
    if (session && session.speakers.has(userId)) {
      session.speakers.get(userId).isMuted = muted;
    }
    return session;
  }

  removeSpeaker(sessionId, userId) {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.speakers.delete(userId);
    }
    return session;
  }

  endSession(sessionId) {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.status = 'ended';
      // Notify all participants
      io.to(sessionId).emit('session_ended', { sessionId });
    }
    this.sessions.delete(sessionId);
  }

  getAllSessions() {
    return Array.from(this.sessions.values()).filter(session => 
      session.status === 'live' && !session.isPrivate
    );
  }
}

const sessionManager = new SessionManager();

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('register_user', (userData) => {
    socketToUser.set(socket.id, userData);
    console.log('User registered:', userData.name);
  });

  socket.on('create_session', (data) => {
    const { host, title, isPrivate } = data;
    const session = sessionManager.createSession(host.id, title, isPrivate);
    
    socket.join(session.id);
    socket.emit('session_created', session);
    
    console.log(`Session created: ${session.id} by ${host.name}`);
  });

  socket.on('join_session', (data) => {
    const { sessionId, user } = data;
    const session = sessionManager.joinSession(sessionId, user);
    
    if (session) {
      socket.join(sessionId);
      socket.emit('session_joined', session);
      
      // Notify others in the session
      socket.to(sessionId).emit('user_joined', {
        user,
        participants: Array.from(session.participants.values()),
        speakers: Array.from(session.speakers.keys())
      });
    } else {
      socket.emit('session_error', { message: 'Session not found' });
    }
  });

  socket.on('leave_session', (data) => {
    const { sessionId, userId } = data;
    const session = sessionManager.leaveSession(sessionId, userId);
    
    if (session) {
      socket.leave(sessionId);
      socket.to(sessionId).emit('user_left', {
        userId,
        participants: Array.from(session.participants.values()),
        speakers: Array.from(session.speakers.keys())
      });
    }
  });

  socket.on('request_to_speak', (data) => {
    const { sessionId, userId } = data;
    const session = sessionManager.requestToSpeak(sessionId, userId);
    
    if (session) {
      // Notify host
      socket.to(sessionId).emit('speaker_requested', {
        userId,
        user: socketToUser.get(socket.id)
      });
    }
  });

  socket.on('approve_speaker', (data) => {
    const { sessionId, userId } = data;
    const session = sessionManager.approveSpeaker(sessionId, userId);
    
    if (session) {
      // Notify the approved user
      io.to(sessionId).emit('speaker_approved', {
        userId,
        speakers: Array.from(session.speakers.keys())
      });
    }
  });

  socket.on('toggle_mute', (data) => {
    const { sessionId, userId, muted } = data;
    const session = sessionManager.toggleMute(sessionId, userId, muted);
    
    if (session) {
      socket.to(sessionId).emit('user_muted', {
        userId,
        muted,
        speakers: Array.from(session.speakers.keys())
      });
    }
  });

  socket.on('remove_speaker', (data) => {
    const { sessionId, userId } = data;
    const session = sessionManager.removeSpeaker(sessionId, userId);
    
    if (session) {
      io.to(sessionId).emit('speaker_removed', {
        userId,
        speakers: Array.from(session.speakers.keys())
      });
    }
  });

  socket.on('end_session', (data) => {
    const { sessionId } = data;
    sessionManager.endSession(sessionId);
  });

  // WebRTC signaling
  socket.on('webrtc_offer', (data) => {
    socket.to(data.target).emit('webrtc_offer', {
      offer: data.offer,
      sender: socket.id
    });
  });

  socket.on('webrtc_answer', (data) => {
    socket.to(data.target).emit('webrtc_answer', {
      answer: data.answer,
      sender: socket.id
    });
  });

  socket.on('webrtc_ice_candidate', (data) => {
    socket.to(data.target).emit('webrtc_ice_candidate', {
      candidate: data.candidate,
      sender: socket.id
    });
  });

  socket.on('get_sessions', () => {
    const sessions = sessionManager.getAllSessions();
    socket.emit('sessions_list', sessions);
  });

  socket.on('disconnect', () => {
    const user = socketToUser.get(socket.id);
    if (user) {
      console.log('User disconnected:', user.name);
      socketToUser.delete(socket.id);
    }
  });
});

// HTTP routes
app.get('/sessions', (req, res) => {
  const sessions = sessionManager.getAllSessions();
  res.json(sessions);
});

app.get('/health', (req, res) => {
  res.json({ status: 'OK', activeSessions: sessionManager.sessions.size });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});