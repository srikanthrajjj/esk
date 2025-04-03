const http = require('http');
const { Server } = require('socket.io');

// Create an HTTP server
const server = http.createServer();

// Create a Socket.io server
const io = new Server(server, {
  cors: {
    origin: '*', // Allow all origins for demo purposes
    methods: ['GET', 'POST']
  }
});

// Store connected clients
const clients = {};

// Handle Socket.io connections
io.on('connection', (socket) => {
  console.log(`New client connected: ${socket.id}`);
  
  // Handle user registration
  socket.on('register', (data) => {
    const { userId, userType } = data;
    
    console.log(`Client registered: ${userId} (${userType})`);
    
    // Store client info
    clients[socket.id] = { userId, userType, socket };
    
    // Notify all clients about new connection
    io.emit('message', {
      type: 'USER_CONNECTED',
      payload: { userId, userType },
      senderId: userId,
      timestamp: new Date().toISOString()
    });
  });
  
  // Handle message forwarding
  socket.on('message', (message) => {
    console.log('Message received:', message);
    
    // Broadcast message to all connected clients
    io.emit('message', message);
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

// Start the server
const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
  console.log(`WebSocket server running on port ${PORT}`);
}); 