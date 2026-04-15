# Deployment Guide

## Prerequisites
- Node.js 18+
- npm or yarn
- Expo CLI (`npm install -g expo-cli`)
- EAS CLI (`npm install -g eas-cli`)
- Apple Developer Account (for iOS)
- Google Play Developer Account (for Android)

## Environment Setup

### 1. Clone Repository
```bash
git clone <repository-url>
cd mi-app-motos
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Configure Environment Variables
Copy `.env.example` to `.env` and fill in your credentials:
```bash
cp .env.example .env
```

Required variables:
- `EXPO_PUBLIC_SUPABASE_URL` - Your Supabase project URL
- `EXPO_PUBLIC_SUPABASE_ANON_KEY` - Your Supabase anonymous key
- `EXPO_PUBLIC_GOOGLE_MAPS_API_KEY` - Google Maps API key

### 4. Login to Expo
```bash
eas login
```

## Development Build

### iOS Simulator
```bash
npm run ios
```

### Android Emulator
```bash
npm run android
```

### Physical Device (Expo Go)
```bash
npm start
```
Then scan the QR code with Expo Go app.

## EAS Build

### Development Build
```bash
eas build --profile development --platform ios
eas build --profile development --platform android
```

### Preview Build (for internal testing)
```bash
eas build --profile preview --platform all
```

### Production Build
```bash
eas build --profile production --platform all
```

## Submission

### iOS App Store
```bash
eas submit --platform ios
```

### Google Play Store
```bash
eas submit --platform android
```

## CI/CD Pipeline

### GitHub Actions Example
```yaml
name: Build and Deploy
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm ci
      - run: npm run type-check
      - run: npm test
      - run: eas build --profile production --platform all --non-interactive
        env:
          EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}
```

## Supabase Setup

### 1. Create Project
1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Note your project URL and anon key

### 2. Run Migrations
Apply SQL migrations to create tables:
- users
- places
- visits
- recommendations
- posadas
- aspirants
- challenges
- memberships
- suggestions

### 3. Configure Auth
- Enable email/password authentication
- Configure email templates
- Set up password reset

### 4. Set Up Storage Buckets
Create buckets:
- `avatars` - Public read, authenticated write
- `places` - Public read, authenticated write
- `evidence` - Restricted access
- `challenges` - Restricted access

### 5. Configure Row Level Security
Enable RLS on all tables with appropriate policies.

## App Store Requirements

### iOS
- App Store Connect account
- App icons (1024x1024)
- Screenshots for all supported devices
- Privacy policy URL
- App description

### Android
- Google Play Console account
- App icon (512x512)
- Feature graphic (1024x500)
- Screenshots (phone, 7", 10")
- Privacy policy URL
- App description

## Version Management

### Bump Version
Update version in `app.json`:
```json
{
  "expo": {
    "version": "1.0.0",
    "ios": {
      "buildNumber": "1"
    },
    "android": {
      "versionCode": 1
    }
  }
}
```

### Release Notes
Maintain a CHANGELOG.md with version changes.

## Monitoring

### Crash Reporting
- Set up Sentry or similar crash reporting
- Monitor crash-free sessions

### Analytics
- Track user engagement
- Monitor membership conversions
- Track place visits

## Rollback Strategy
- Keep previous build versions
- Test thoroughly before production release
- Have hotfix process ready
