const express = require('express');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');

// Create Express app
const app = express();

// Serve static files from the 'dist' directory
app.use(express.static(path.join(__dirname, 'dist')));

// Create HTTP server
const server = http.createServer(app);

// Initialize Socket.IO
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Store client information
const clients = {};
let messagesCount = 0;
let totalConnections = 0;
let failedConnections = 0;

// Store messages that couldn't be delivered (offline recipients)
const pendingMessages = {};

// Report server stats every 30 seconds
setInterval(() => {
  const clientCount = Object.keys(clients).length;
  console.log(`[SERVER STATS] Connected clients: ${clientCount}, Total connections: ${totalConnections}, Failed: ${failedConnections}, Messages: ${messagesCount}`);
}, 30000);

// Socket.IO connection handler
io.on('connection', (socket) => {
  totalConnections++;
  console.log(`Client connected: ${socket.id} (Total: ${totalConnections})`);

  // Handle client registration
  socket.on('register', ({ userId, userType }) => {
    try {
      // Validate user ID format based on user type
      let validUserId = userId;
      
      if (userType === 'officer' && !userId.startsWith('off')) {
        validUserId = 'off1';
        console.log(`Invalid officer ID format: ${userId}, using: ${validUserId}`);
      } else if (userType === 'victim' && !userId.startsWith('victim-')) {
        validUserId = 'victim-michael';
        console.log(`Invalid victim ID format: ${userId}, using: ${validUserId}`);
      } else if (userType === 'admin' && !userId.startsWith('admin-')) {
        validUserId = 'admin-user';
        console.log(`Invalid admin ID format: ${userId}, using: ${validUserId}`);
      }
      
      // Store client information
      clients[validUserId] = {
        socket: socket.id,
        userType,
        timestamp: new Date().toISOString()
      };
      
      console.log(`Client registered: ${validUserId} (${userType})`);
      
      // If this is a victim connecting, send any pending messages
      if (userType === 'victim' && pendingMessages[validUserId]) {
        const messages = pendingMessages[validUserId];
        if (messages.length > 0) {
          console.log(`Sending ${messages.length} pending messages to victim`);
          messages.forEach(message => {
            socket.emit('message', message);
          });
          // Clear pending messages
          pendingMessages[validUserId] = [];
        }
      }
      
      // Broadcast connection to all clients
      io.emit('userStatus', {
        userId: validUserId,
        userType,
        status: 'online',
        timestamp: new Date().toISOString()
      });
      
      // Set socket's user data
      socket.userId = validUserId;
      socket.userType = userType;
    } catch (error) {
      console.error('Error in client registration:', error);
      failedConnections++;
    }
  });

  // Handle messages
  socket.on('message', (message) => {
    try {
      messagesCount++;
      console.log('Received message from ' + socket.id + ':', message);
      
      // Process different message types
      switch (message.type) {
        case 'ADMIN_MESSAGE':
          const recipientOfficer = Object.entries(clients).find(
            ([userId, client]) => userId === message.payload.recipientId
          );
          
          if (recipientOfficer) {
            io.to(recipientOfficer[1].socket).emit('message', message);
          } else {
            console.log('Recipient officer not found');
          }
          break;
          
        case 'OFFICER_MESSAGE':
          // Send to all admin clients
          Object.entries(clients).forEach(([userId, client]) => {
            if (client.userType === 'admin') {
              io.to(client.socket).emit('message', message);
            }
          });
          break;
          
        case 'POLICE_TO_VICTIM_MESSAGE':
          const victimId = message.payload.recipientId;
          console.log('Sending police message to victim:', message);
          
          const victimClient = Object.entries(clients).find(
            ([userId, client]) => userId === victimId
          );
          
          if (victimClient) {
            io.to(victimClient[1].socket).emit('message', message);
          } else {
            console.log('Victim offline, storing message for later delivery');
            if (!pendingMessages[victimId]) {
              pendingMessages[victimId] = [];
            }
            pendingMessages[victimId].push(message);
          }
          break;
          
        case 'VICTIM_MESSAGE':
          // Send to all officer and admin clients
          Object.entries(clients).forEach(([userId, client]) => {
            if (client.userType === 'officer' || client.userType === 'admin') {
              io.to(client.socket).emit('message', message);
            }
          });
          break;
          
        case 'MESSAGE_READ':
          const { messageIds, recipientId } = message.payload;
          
          if (recipientId) {
            const recipientSocket = Object.entries(clients).find(
              ([userId, client]) => userId === recipientId
            );
            
            if (recipientSocket) {
              io.to(recipientSocket[1].socket).emit('message', message);
            } else {
              console.log('Recipient socket not found');
            }
          } else {
            // Broadcast to all users
            socket.broadcast.emit('message', message);
          }
          break;
          
        case 'NEW_CASE_ADDED':
          // Send to the specific victim
          const targetVictim = Object.entries(clients).find(
            ([userId, client]) => 
              client.userType === 'victim' && 
              userId.includes(message.payload.victimName.toLowerCase())
          );
          
          if (targetVictim) {
            io.to(targetVictim[1].socket).emit('message', message);
          } else {
            const victimIdForCase = 'victim-' + message.payload.victimName.toLowerCase().replace(' ', '-');
            console.log('Victim offline, storing message for later delivery');
            if (!pendingMessages[victimIdForCase]) {
              pendingMessages[victimIdForCase] = [];
            }
            pendingMessages[victimIdForCase].push(message);
          }
          
          // Also notify admins
          Object.entries(clients).forEach(([userId, client]) => {
            if (client.userType === 'admin') {
              io.to(client.socket).emit('message', message);
            }
          });
          break;
          
        default:
          // Broadcast other message types to all clients
          socket.broadcast.emit('message', message);
      }
    } catch (error) {
      console.error('Error processing message:', error);
    }
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
    
    // Remove client from clients object
    if (socket.userId) {
      delete clients[socket.userId];
      
      // Broadcast disconnection to all clients
      io.emit('userStatus', {
        userId: socket.userId,
        userType: socket.userType,
        status: 'offline',
        timestamp: new Date().toISOString()
      });
    }
  });
});

// Add a catch-all route to serve index.html for client-side routing
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

// Start the server with error handling
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';  // Listen on all network interfaces

server.on('error', (error) => {
  console.error('Server error:', error);
  
  if (error.code === 'EADDRINUSE') {
    console.log(`Port ${PORT} is in use, trying to close existing connection...`);
    
    setTimeout(() => {
      server.close();
      console.log(`Port ${PORT} freed, restarting server...`);
      
      server.listen(PORT, HOST, () => {
        console.log(`WebSocket server running on ${HOST}:${PORT}`);
      });
    }, 1000);
  }
});

server.listen(PORT, HOST, () => {
  console.log(`WebSocket server running on ${HOST}:${PORT}`);
}); 