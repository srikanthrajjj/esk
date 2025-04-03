const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const path = require('path');
const fs = require('fs');
const { Server } = require('socket.io');

// Create Express app
const app = express();

// Serve static files from the 'dist' directory
app.use(express.static(path.join(__dirname, 'dist')));

// Create HTTP server
const server = http.createServer(app);

// Create a Socket.io server with CORS configuration
const io = new Server(server, {
  cors: {
    origin: '*',  // Allow all origins in development
    methods: ['GET', 'POST'],
    credentials: true
  },
  pingTimeout: 60000,
  pingInterval: 25000,
  transports: ['websocket'],
  allowEIO3: true
});

// Store connected clients with timestamps
const clients = {};

// Store messages for debugging with timestamp
const messageHistory = [];

// Store pending messages for offline users with expiry
const pendingMessages = {
  'victim-michael': []
};

// Initialize message count and connection stats
let messageCount = 0;
let totalConnections = 0;
let failedConnections = 0;

// Handle Socket.io connections
io.on('connection', (socket) => {
  totalConnections++;
  console.log(`Client connected: ${socket.id} (Total: ${totalConnections})`);
  
  // Handle user registration
  socket.on('register', (data) => {
    try {
      const { userId, userType } = data;
      
      // Validate user ID format
      let validUserId = userId;
      if (userType === 'officer' && !userId.startsWith('off')) {
        validUserId = 'off1';
      } else if (userType === 'victim' && !userId.startsWith('victim-')) {
        validUserId = 'victim-michael';
      } else if (userType === 'admin' && !userId.startsWith('admin-')) {
        validUserId = 'admin-user';
      }
      
      console.log(`Client registered: ${validUserId} (${userType})`);
      
      // Store client info with timestamp
      clients[socket.id] = { 
        userId: validUserId, 
        userType, 
        socket,
        connectedAt: new Date().toISOString()
      };
      
      // If this is the victim connecting, send any pending messages
      if (validUserId === 'victim-michael' && pendingMessages[validUserId]?.length > 0) {
        console.log(`Sending ${pendingMessages[validUserId].length} pending messages to victim`);
        pendingMessages[validUserId].forEach(message => {
          socket.emit('message', message);
        });
        // Clear pending messages after sending
        pendingMessages[validUserId] = [];
      }
      
      // Notify all clients about new connection
      io.emit('message', {
        type: 'USER_CONNECTED',
        payload: { userId: validUserId, userType },
        senderId: validUserId,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error in register:', error);
      failedConnections++;
    }
  });
  
  // Handle ping to keep connection alive
  socket.on('ping', () => {
    socket.emit('pong');
  });

  // Handle errors
  socket.on('error', (error) => {
    console.error(`Socket error for ${socket.id}:`, error);
    failedConnections++;
  });
  
  // Handle messages
  socket.on('message', (message) => {
    try {
      console.log(`Received message from ${socket.id}:`, message);
      
      // Store message for debugging
      messageHistory.push({
        ...message,
        receivedAt: new Date().toISOString(),
        socketId: socket.id
      });
      
      // For NEW_CASE_ADDED messages, we need to ensure the victim receives it
      if (message.type === 'NEW_CASE_ADDED') {
        // Find the victim's socket
        const victimSocket = Object.values(clients).find(
          client => client.userId === 'victim-michael'
        );
        
        if (victimSocket) {
          console.log('Sending new case to victim:', message);
          victimSocket.socket.emit('message', message);
        } else {
          console.log('Victim offline, storing message for later delivery');
          pendingMessages['victim-michael'].push(message);
        }
      } else if (message.type === 'POLICE_TO_VICTIM_MESSAGE') {
        // Find the victim's socket
        const victimSocket = Object.values(clients).find(
          client => client.userId === 'victim-michael'
        );
        
        if (victimSocket) {
          console.log('Sending police message to victim:', message);
          victimSocket.socket.emit('message', {
            ...message,
            senderId: socket.userId,
            timestamp: new Date().toISOString()
          });
        } else {
          console.log('Victim offline, storing message for later delivery');
          pendingMessages['victim-michael'].push({
            ...message,
            senderId: socket.userId,
            timestamp: new Date().toISOString()
          });
        }
      } else if (message.type === 'VICTIM_MESSAGE') {
        // Find the police officer's socket
        const policeSocket = Object.values(clients).find(
          client => client.userId === 'off1'
        );
        
        if (policeSocket) {
          console.log('Sending victim message to police:', message);
          policeSocket.socket.emit('message', {
            ...message,
            senderId: socket.userId,
            timestamp: new Date().toISOString()
          });
        } else {
          console.log('Police socket not found');
        }
      } else if (message.type === 'MESSAGE_READ') {
        // Handle read receipts
        const recipientId = message.payload.recipientId;
        const recipientSocket = Object.values(clients).find(
          client => client.userId === recipientId
        );
        
        if (recipientSocket) {
          console.log('Sending read receipt:', message);
          recipientSocket.socket.emit('message', {
            ...message,
            senderId: socket.userId,
            timestamp: new Date().toISOString()
          });
        } else {
          console.log('Recipient socket not found');
        }
      } else {
        // For other messages, broadcast to all
        io.emit('message', {
          ...message,
          senderId: socket.userId,
          timestamp: new Date().toISOString()
        });
      }
      
      messageCount++;
      console.log(`[SERVER STATS] Connected clients: ${io.sockets.sockets.size}, Messages: ${messageCount}`);
    } catch (error) {
      console.error('Error processing message:', error);
    }
  });
  
  // Handle disconnection
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
    
    if (clients[socket.id]) {
      const { userId, userType } = clients[socket.id];
      
      // Notify all clients about disconnection
      io.emit('message', {
        type: 'USER_DISCONNECTED',
        payload: { userId, userType },
        senderId: userId,
        timestamp: new Date().toISOString()
      });
      
      // Remove client from memory
      delete clients[socket.id];
    }
  });
});

// Add a catch-all route to serve index.html for client-side routing
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

// Start the server with error handling
const PORT = process.env.PORT || 3002;
const HOST = '0.0.0.0';  // Listen on all network interfaces

// Configure CORS for production
io.origins((origin, callback) => {
  const allowedOrigins = [
    'https://your-netlify-app.netlify.app', // Replace with your Netlify URL
    'http://localhost:5173',
    'http://localhost:5174'
  ];
  
  // In development, allow all connections
  if (!origin || allowedOrigins.includes(origin)) {
    callback(null, true);
  } else {
    console.log(`Origin ${origin} not allowed by CORS`);
    callback(new Error('Not allowed by CORS'));
  }
});

server.on('error', (error) => {
  console.error('Server error:', error);
  if (error.code === 'EADDRINUSE') {
    console.log(`Port ${PORT} is in use, trying to close existing connection...`);
    require('child_process').exec(`npx kill-port ${PORT}`, (err) => {
      if (err) {
        console.error('Failed to kill port:', err);
      } else {
        console.log(`Port ${PORT} freed, restarting server...`);
        startServer();
      }
    });
  }
});

function startServer() {
  server.listen(PORT, HOST, () => {
    console.log(`WebSocket server running on ${HOST}:${PORT}`);
  });
}

startServer();

// Log server statistics every 30 seconds
setInterval(() => {
  const connectedClients = Object.keys(clients).length;
  console.log(`[SERVER STATS] Connected clients: ${connectedClients}, Total connections: ${totalConnections}, Failed: ${failedConnections}, Messages: ${messageCount}`);
}, 30000); 