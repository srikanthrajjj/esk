# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react/README.md) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type aware lint rules:

- Configure the top-level `parserOptions` property like this:

```js
export default tseslint.config({
  languageOptions: {
    // other options...
    parserOptions: {
      project: ['./tsconfig.node.json', './tsconfig.app.json'],
      tsconfigRootDir: import.meta.dirname,
    },
  },
})
```

- Replace `tseslint.configs.recommended` to `tseslint.configs.recommendedTypeChecked` or `tseslint.configs.strictTypeChecked`
- Optionally add `...tseslint.configs.stylisticTypeChecked`
- Install [eslint-plugin-react](https://github.com/jsx-eslint/eslint-plugin-react) and update the config:

```js
// eslint.config.js
import react from 'eslint-plugin-react'

export default tseslint.config({
  // Set the react version
  settings: { react: { version: '18.3' } },
  plugins: {
    // Add the react plugin
    react,
  },
  rules: {
    // other rules...
    // Enable its recommended rules
    ...react.configs.recommended.rules,
    ...react.configs['jsx-runtime'].rules,
  },
})
```

# Police & Victim Communication App

A real-time communication application for police officers and victims.

## Features

- Real-time messaging between police officers, victims, and admin
- Case management system
- Appointment scheduling
- VCOP updates and document management
- Interactive dashboard for police and victims

## How to run on Glitch

This application is pre-configured for Glitch deployment. Once you import the repository into Glitch:

1. Glitch will automatically install dependencies and build the project
2. The app will automatically start when all dependencies are installed
3. You can see your app running at your-project-name.glitch.me

## Developing locally

To run this project locally:

```bash
# Install dependencies
npm install

# Run the server and client concurrently
npm run dev
```

This will start the server on port 3002 and the frontend on port 5173 (or another available port).

## User roles

- **Officer**: Login with ID "off1"
- **Victim**: Login with ID "victim-michael"
- **Admin**: Login with ID "admin-user" 

## Tech stack

- React with TypeScript
- Tailwind CSS
- Socket.io for real-time communication
- Vite for frontend build
