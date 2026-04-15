# API Documentation

## Supabase Integration

### Client Configuration
```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.EXPO_PUBLIC_SUPABASE_URL,
  process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY
);
```

## Authentication

### Sign In
```typescript
const { data, error } = await supabase.auth.signInWithPassword({
  email,
  password,
});
```

### Sign Up
```typescript
const { data, error } = await supabase.auth.signUp({
  email,
  password,
  options: {
    data: {
      full_name,
      phone,
    },
  },
});
```

### Sign Out
```typescript
const { error } = await supabase.auth.signOut();
```

### Reset Password
```typescript
const { data, error } = await supabase.auth.resetPasswordForEmail(email);
```

## Database Tables

### Users
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| email | text | User email |
| full_name | text | Display name |
| phone | text | Contact phone |
| avatar_url | text | Profile picture URL |
| membership_status | enum | active/inactive/pending/expired |
| role | enum | user/admin/moderator |

### Places
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| name | text | Place name |
| description | text | Place description |
| address | text | Physical address |
| latitude | float | GPS latitude |
| longitude | float | GPS longitude |
| category | text | Place category |
| is_approved | boolean | Approval status |

### Visits
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | Reference to users |
| place_id | uuid | Reference to places |
| qr_code | text | Scanned QR code |
| visited_at | timestamp | Visit timestamp |
| evidence_url | text | Photo evidence URL |

### Recommendations
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | Reference to users |
| place_id | uuid | Reference to places |
| title | text | Review title |
| description | text | Review content |
| rating | int | 1-5 rating |
| images | text[] | Photo URLs |

### Posadas
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| name | text | Event name |
| description | text | Event description |
| location | text | Event location |
| date | timestamp | Event date |
| organizer_id | uuid | Reference to users |
| max_participants | int | Capacity limit |

### Aspirants
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | Reference to users |
| status | enum | pending/approved/rejected/in_review |
| applied_at | timestamp | Application date |
| reviewed_by | uuid | Reviewer user ID |
| notes | text | Admin notes |

### Challenges
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| aspirant_id | uuid | Reference to aspirants |
| title | text | Challenge title |
| description | text | Challenge description |
| status | enum | pending/completed/rejected |
| evidence_url | text | Proof URL |

### Memberships
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | Reference to users |
| plan | enum | monthly/yearly |
| start_date | timestamp | Start date |
| end_date | timestamp | Expiry date |
| is_active | boolean | Active status |

### Suggestions
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| user_id | uuid | Reference to users |
| place_name | text | Suggested place name |
| place_description | text | Description |
| place_address | text | Address |
| latitude | float | GPS latitude |
| longitude | float | GPS longitude |
| status | enum | pending/approved/rejected |

## Storage Buckets

### avatars
- User profile pictures
- Public read access
- Authenticated write access

### places
- Place photos
- Public read access
- Authenticated write access

### evidence
- Visit evidence photos
- Restricted access (user + admin)

### challenges
- Challenge submission photos
- Restricted access (aspirant + admin)

## Realtime Channels

### places
```typescript
supabase
  .channel('places')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'places' }, callback)
  .subscribe();
```

### posadas
```typescript
supabase
  .channel('posadas')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'posadas' }, callback)
  .subscribe();
```

## RPC Functions

### get_nearby_places
```sql
CREATE OR REPLACE FUNCTION get_nearby_places(lat FLOAT, lng FLOAT, radius FLOAT)
RETURNS TABLE (...)
```

### check_membership_active
```sql
CREATE OR REPLACE FUNCTION check_membership_active(user_id UUID)
RETURNS BOOLEAN
```

## Error Handling
All API calls should handle potential errors:
```typescript
const { data, error } = await supabase.from('table').select();
if (error) {
  console.error('API Error:', error);
  // Handle error appropriately
}
```
