import { supabase } from './supabase';

export async function uploadImage(
  file: File | Blob,
  fileName: string,
  bucket: string = 'images',
): Promise<{ path: string | null; error: string | null }> {
  const fileExt = fileName.split('.').pop();
  const filePath = `${Date.now()}-${Math.random().toString(36).substring(2)}.${fileExt}`;

  const { data, error } = await supabase.storage.from(bucket).upload(filePath, file);

  if (error) {
    return { path: null, error: error.message };
  }

  return { path: data.path, error: null };
}

export async function deleteImage(
  filePath: string,
  bucket: string = 'images',
): Promise<{ success: boolean; error: string | null }> {
  const { error } = await supabase.storage.from(bucket).remove([filePath]);

  if (error) {
    return { success: false, error: error.message };
  }

  return { success: true, error: null };
}

export function getImageUrl(
  filePath: string,
  bucket: string = 'images',
): string {
  const { data } = supabase.storage.from(bucket).getPublicUrl(filePath);
  return data.publicUrl;
}
