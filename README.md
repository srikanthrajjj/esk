# ESKO - Police Case Management System

A modern case management system for police officers, victims, and administrators. This application facilitates real-time communication, case tracking, appointment scheduling, and document management between police departments and crime victims.

## Features

- **Real-time Communication**: WebSocket-based messaging between police officers, victims, and administrators
- **Case Management**: Create, view, and manage criminal cases with full details
- **User Roles**: Separate interfaces for police officers, victims, and administrators
- **Appointment Scheduling**: Schedule and manage meetings and appointments with victims
- **Document Handling**: Upload and share documents related to cases
- **Responsive Design**: Works on both desktop and mobile devices

## Tech Stack

- **Frontend**: React, TypeScript, Tailwind CSS, Vite
- **Backend**: Node.js, Socket.io for real-time communication
- **Deployment**: Docker-ready, deployable to Render, Railway, or any other platform

## Getting Started

### Prerequisites

- Node.js (v20 or later)
- npm or yarn

### Local Development

1. Clone the repository
```bash
git clone https://github.com/srikanthrajjj/esk.git
cd esk
```

2. Install dependencies
```bash
npm install
```

3. Start the development server
```bash
# In one terminal window, start the WebSocket server
npm run websocket

# In another terminal window, start the frontend
npm run dev
```

4. Access the application
- Frontend: http://localhost:5173
- WebSocket server: http://localhost:3002

## Deployment to Render

This application is configured for easy deployment to [Render](https://render.com) using the `render.yaml` blueprint.

### Automatic Deployment

1. Fork this repository to your GitHub account
2. In Render, create a new "Blueprint" deployment
3. Connect your GitHub account and select the forked repository
4. Render will automatically detect the `render.yaml` file and create both services:
   - esko-frontend: The static frontend site
   - esko-backend: The WebSocket server

### Manual Deployment

#### Backend Service

1. In Render, create a new "Web Service"
2. Connect your GitHub repository
3. Use these settings:
   - Name: esko-backend
   - Runtime: Node
   - Build Command: `npm install`
   - Start Command: `npm run start:prod`
   - Add environment variables:
     - NODE_ENV: production
     - PORT: 3001

#### Frontend Service

1. In Render, create a new "Static Site"
2. Connect your GitHub repository
3. Use these settings:
   - Name: esko-frontend
   - Build Command: `npm run build`
   - Publish Directory: `dist`
   - Add environment variables:
     - VITE_WS_URL: (Use the URL of your backend service)

## Environment Variables

- `NODE_ENV`: Set to "production" for production deployments
- `PORT`: The port for the WebSocket server (default: 3001)
- `VITE_WS_URL`: WebSocket server URL for the frontend to connect to

## License

This project is licensed under the MIT License - see the LICENSE file for details.
