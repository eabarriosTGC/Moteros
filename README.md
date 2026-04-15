# Mi App Motos

A mobile application for motorcycle enthusiasts built with Expo and React Native.

## Getting Started

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Environment Variables
```bash
cp .env.example .env
```
Edit `.env` and add your Supabase and Google Maps credentials.

### 3. Start Development Server
```bash
npm start
```

## Project Structure

```
├── src/
│   ├── app/              # Expo Router screens
│   ├── components/       # Reusable UI components
│   ├── services/         # External service integrations
│   ├── store/           # Zustand global state
│   ├── hooks/           # Custom React hooks
│   ├── types/           # TypeScript type definitions
│   ├── utils/           # Helper functions
│   ├── assets/          # Static resources
│   ├── styles/          # Theme and styling
│   └── config/          # App configuration
├── tests/               # Unit and integration tests
├── scripts/             # Automation scripts
├── docs/                # Documentation
└── configuration files
```

## Available Scripts

- `npm start` - Start Expo development server
- `npm run ios` - Run on iOS simulator
- `npm run android` - Run on Android emulator
- `npm test` - Run tests
- `npm run lint` - Run linter
- `npm run type-check` - TypeScript type checking
- `npm run generate-types` - Generate types from Supabase
- `npm run seed` - Seed database with test data

## Tech Stack

- **Framework**: Expo SDK 50 + React Native
- **Navigation**: Expo Router
- **Backend**: Supabase (PostgreSQL, Auth, Storage)
- **State Management**: Zustand
- **Maps**: react-native-maps
- **TypeScript**: Strict mode

## Documentation

- [Architecture](docs/architecture.md)
- [API Documentation](docs/api.md)
- [Deployment Guide](docs/deployment.md)
