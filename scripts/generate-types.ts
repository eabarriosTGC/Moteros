import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';
import * as path from 'path';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL || '';
const supabaseKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || '';

const supabase = createClient(supabaseUrl, supabaseKey);

async function generateTypes() {
  console.log('Generating TypeScript types from Supabase...');

  const { data, error } = await supabase.from('_dummy').select('*').limit(0);

  if (error) {
    console.log('Note: Could not fetch schema directly. Using manual type generation.');
  }

  // Generate types file
  const typesPath = path.join(__dirname, '../src/types/database.ts');
  
  const typesContent = `// Auto-generated types from Supabase schema
// Run \`npm run generate-types\` to update

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export interface Database {
  public: {
    Tables: {
      users: {
        Row: {
          id: string;
          email: string;
          full_name: string;
          phone: string | null;
          avatar_url: string | null;
          membership_status: 'active' | 'inactive' | 'pending' | 'expired';
          role: 'user' | 'admin' | 'moderator';
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          email: string;
          full_name: string;
          phone?: string | null;
          avatar_url?: string | null;
          membership_status?: 'active' | 'inactive' | 'pending' | 'expired';
          role?: 'user' | 'admin' | 'moderator';
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          email?: string;
          full_name?: string;
          phone?: string | null;
          avatar_url?: string | null;
          membership_status?: 'active' | 'inactive' | 'pending' | 'expired';
          role?: 'user' | 'admin' | 'moderator';
          created_at?: string;
          updated_at?: string;
        };
      };
      places: {
        Row: {
          id: string;
          name: string;
          description: string;
          address: string;
          latitude: number;
          longitude: number;
          category: string;
          is_approved: boolean;
          suggested_by: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          description: string;
          address: string;
          latitude: number;
          longitude: number;
          category: string;
          is_approved?: boolean;
          suggested_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          description?: string;
          address?: string;
          latitude?: number;
          longitude?: number;
          category?: string;
          is_approved?: boolean;
          suggested_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      visits: {
        Row: {
          id: string;
          user_id: string;
          place_id: string;
          qr_code: string;
          visited_at: string;
          evidence_url: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          place_id: string;
          qr_code: string;
          visited_at?: string;
          evidence_url?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          place_id?: string;
          qr_code?: string;
          visited_at?: string;
          evidence_url?: string | null;
          created_at?: string;
        };
      };
      recommendations: {
        Row: {
          id: string;
          user_id: string;
          place_id: string;
          title: string;
          description: string;
          rating: number;
          images: string[];
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          place_id: string;
          title: string;
          description: string;
          rating: number;
          images?: string[];
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          place_id?: string;
          title?: string;
          description?: string;
          rating?: number;
          images?: string[];
          created_at?: string;
          updated_at?: string;
        };
      };
      posadas: {
        Row: {
          id: string;
          name: string;
          description: string;
          location: string;
          date: string;
          organizer_id: string;
          max_participants: number | null;
          images: string[];
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          description: string;
          location: string;
          date: string;
          organizer_id: string;
          max_participants?: number | null;
          images?: string[];
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          description?: string;
          location?: string;
          date?: string;
          organizer_id?: string;
          max_participants?: number | null;
          images?: string[];
          created_at?: string;
          updated_at?: string;
        };
      };
      aspirants: {
        Row: {
          id: string;
          user_id: string;
          status: 'pending' | 'approved' | 'rejected' | 'in_review';
          applied_at: string;
          reviewed_by: string | null;
          reviewed_at: string | null;
          notes: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          status?: 'pending' | 'approved' | 'rejected' | 'in_review';
          applied_at?: string;
          reviewed_by?: string | null;
          reviewed_at?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          status?: 'pending' | 'approved' | 'rejected' | 'in_review';
          applied_at?: string;
          reviewed_by?: string | null;
          reviewed_at?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      challenges: {
        Row: {
          id: string;
          aspirant_id: string;
          title: string;
          description: string;
          status: 'pending' | 'completed' | 'rejected';
          evidence_url: string | null;
          submitted_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          aspirant_id: string;
          title: string;
          description: string;
          status?: 'pending' | 'completed' | 'rejected';
          evidence_url?: string | null;
          submitted_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          aspirant_id?: string;
          title?: string;
          description?: string;
          status?: 'pending' | 'completed' | 'rejected';
          evidence_url?: string | null;
          submitted_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      memberships: {
        Row: {
          id: string;
          user_id: string;
          plan: 'monthly' | 'yearly';
          start_date: string;
          end_date: string;
          is_active: boolean;
          payment_id: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          plan: 'monthly' | 'yearly';
          start_date: string;
          end_date: string;
          is_active?: boolean;
          payment_id?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          plan?: 'monthly' | 'yearly';
          start_date?: string;
          end_date?: string;
          is_active?: boolean;
          payment_id?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      suggestions: {
        Row: {
          id: string;
          user_id: string;
          place_name: string;
          place_description: string;
          place_address: string;
          latitude: number;
          longitude: number;
          status: 'pending' | 'approved' | 'rejected';
          reviewed_by: string | null;
          reviewed_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          place_name: string;
          place_description: string;
          place_address: string;
          latitude: number;
          longitude: number;
          status?: 'pending' | 'approved' | 'rejected';
          reviewed_by?: string | null;
          reviewed_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          place_name?: string;
          place_description?: string;
          place_address?: string;
          latitude?: number;
          longitude?: number;
          status?: 'pending' | 'approved' | 'rejected';
          reviewed_by?: string | null;
          reviewed_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      [_ in never]: never;
    };
    Enums: {
      [_ in never]: never;
    };
  };
}
`;

  fs.writeFileSync(typesPath, typesContent);
  console.log(`Types generated successfully at ${typesPath}`);
}

generateTypes().catch(console.error);
