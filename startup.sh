#!/bin/bash

# Start the WebSocket server and the web application
echo "Starting WebSocket server and web application..."

# Run the WebSocket server
node server.cjs &
WS_PID=$!

# Run the web application
npm run dev &
WEB_PID=$!

# Function to kill processes on exit
cleanup() {
  echo "Shutting down..."
  kill $WS_PID
  kill $WEB_PID
  exit 0
}

# Set up trap to handle exit
trap cleanup SIGINT SIGTERM

# Wait for either process to exit
wait $WS_PID $WEB_PID

# Clean up
cleanup 