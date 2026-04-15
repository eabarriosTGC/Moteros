import { supabase } from '../../src/services/supabase';

describe('Supabase Client', () => {
  it('initializes with environment variables', () => {
    expect(supabase).toBeDefined();
  });
});
