# Architecture

## Overview
Mi App Motos is a mobile application built with Expo (React Native) for motorcycle enthusiasts. The app connects members with places, events, and community features.

## Tech Stack
- **Framework**: Expo SDK 50 with React Native
- **Navigation**: Expo Router (file-based routing)
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Realtime)
- **State Management**: Zustand
- **Maps**: react-native-maps with Google Maps API
- **QR Scanning**: expo-camera
- **TypeScript**: Strict mode enabled

## Project Structure
```
src/
├── app/          # Expo Router screens
├── components/   # Reusable UI components
├── services/     # External service integrations
├── store/        # Zustand global state
├── hooks/        # Custom React hooks
├── types/        # TypeScript type definitions
├── utils/        # Helper functions
├── assets/       # Static resources
├── styles/       # Theme and styling
└── config/       # App configuration
```

## Key Architectural Decisions

### 1. File-Based Routing
Using Expo Router for navigation with route groups:
- `(auth)` - Authentication flow
- `(tabs)` - Main app with bottom tabs
- `(member)` - Member-exclusive content
- `(aspirant)` - Aspirant onboarding flow
- `(admin)` - Admin panel (role-based access)

### 2. State Management
Zustand stores are used for global state:
- `authStore` - User authentication state
- `membershipStore` - Membership status
- `userStore` - User profile data
- `uiStore` - UI state (theme, modals, loading)

### 3. Database Schema
Main tables in Supabase:
- `users` - User profiles with membership status
- `places` - Motorcycle-friendly locations
- `visits` - QR-based visit tracking
- `recommendations` - User reviews of places
- `posadas` - Community events/gatherings
- `aspirants` - Membership applications
- `challenges` - Aspirant requirements
- `memberships` - Subscription records
- `suggestions` - Place suggestions for approval

### 4. Authentication Flow
1. User registers/logs in via Supabase Auth
2. Membership status determines accessible features
3. Active members get full access to places and features
4. Aspirants go through challenge-based onboarding

### 5. Visit Verification
- Places have unique QR codes
- Members scan QR code to log visits
- Visit history tracks member activity
- Evidence photos can be attached

## Data Flow
```
User Action → Hook → Service → Supabase → State Update → UI Re-render
```

## Security
- Row Level Security (RLS) policies in Supabase
- Role-based access control (user, admin, moderator)
- Secure environment variable handling
- Protected API routes
