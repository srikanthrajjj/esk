FROM node:20-slim

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy all source files
COPY . .

# Build the frontend
RUN npm run build

# Expose the WebSocket port
EXPOSE 3001

# Start both the frontend and WebSocket server
CMD ["npm", "run", "start"] 