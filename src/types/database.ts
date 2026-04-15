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
      profiles: {
        Row: {
          id: string;
          email: string | null;
          full_name: string | null;
          role: "admin" | "member" | "aspirant" | "traveler";
          avatar_url: string | null;
          created_at: string;
        };
      };
      places: {
        Row: {
          id: number;
          name: string;
          description: string | null;
          location_lat: number | null;
          location_lng: number | null;
          qr_secret: string;
          is_premium: boolean;
          created_at: string;
        };
      };
      subscriptions: {
        Row: {
          id: number;
          user_id: string;
          status: string;
          start_date: string | null;
          end_date: string | null;
        };
      };
    };
  };
}
