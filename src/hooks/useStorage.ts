import { useState, useCallback } from 'react';
import { MAX_FILE_SIZE } from '../utils/constants';

interface UploadProgress {
  progress: number;
  uploadedBytes: number;
  totalBytes: number;
}

interface UseStorageReturn {
  isUploading: boolean;
  uploadProgress: UploadProgress | null;
  error: string | null;
  uploadImage: (uri: string, folder?: string) => Promise<string | null>;
  uploadMultipleImages: (uris: string[], folder?: string) => Promise<string[]>;
  deleteImage: (url: string) => Promise<void>;
}

/**
 * Hook for image upload and storage management.
 * Handles uploading to Supabase storage or other storage provider.
 */
export function useStorage(): UseStorageReturn {
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<UploadProgress | null>(null);
  const [error, setError] = useState<string | null>(null);

  const uploadImage = useCallback(
    async (uri: string, folder: string = 'images'): Promise<string | null> => {
      setIsUploading(true);
      setError(null);
      setUploadProgress({ progress: 0, uploadedBytes: 0, totalBytes: 0 });

      try {
        // Validate file
        const fileInfo = await getFileSize(uri);
        if (fileInfo.size > MAX_FILE_SIZE) {
          throw new Error(
            `File size exceeds maximum allowed size of ${MAX_FILE_SIZE / (1024 * 1024)}MB`
          );
        }

        // Create unique filename
        const filename = `${Date.now()}-${Math.random().toString(36).substring(7)}.jpg`;
        const path = `${folder}/${filename}`;

        // TODO: Implement actual upload to Supabase Storage
        // Example:
        // const { data, error } = await supabase.storage
        //   .from('images')
        //   .upload(path, file, {
        //     cacheControl: '3600',
        //     upsert: false,
        //     onUploadProgress: (progress) => {
        //       setUploadProgress({
        //         progress: (progress.loaded / progress.total) * 100,
        //         uploadedBytes: progress.loaded,
        //         totalBytes: progress.total,
        //       });
        //     },
        //   });

        // if (error) throw error;

        // const { data: { publicUrl } } = supabase.storage
        //   .from('images')
        //   .getPublicUrl(data.path);

        setUploadProgress({ progress: 100, uploadedBytes: 0, totalBytes: 0 });
        return `https://placeholder-url.com/${path}`;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to upload image';
        setError(message);
        return null;
      } finally {
        setIsUploading(false);
      }
    },
    []
  );

  const uploadMultipleImages = useCallback(
    async (uris: string[], folder: string = 'images'): Promise<string[]> => {
      const urls: string[] = [];
      for (const uri of uris) {
        const url = await uploadImage(uri, folder);
        if (url) {
          urls.push(url);
        }
      }
      return urls;
    },
    [uploadImage]
  );

  const deleteImage = useCallback(async (url: string): Promise<void> => {
    setIsUploading(true);
    setError(null);
    try {
      // TODO: Implement actual delete from Supabase Storage
      // const path = extractPathFromUrl(url);
      // const { error } = await supabase.storage.from('images').remove([path]);
      // if (error) throw error;
      console.log('Delete image:', url);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to delete image';
      setError(message);
    } finally {
      setIsUploading(false);
    }
  }, []);

  return {
    isUploading,
    uploadProgress,
    error,
    uploadImage,
    uploadMultipleImages,
    deleteImage,
  };
}

async function getFileSize(uri: string): Promise<{ size: number }> {
  // TODO: Use expo-file-system to get actual file size
  // const fileInfo = await FileSystem.getInfoAsync(uri);
  // return { size: fileInfo.size || 0 };
  return { size: 0 };
}
