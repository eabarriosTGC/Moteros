import { useState, useCallback } from 'react';
import { Camera } from 'expo-camera';
import type { CameraView } from 'expo-camera';
import type { BarcodeScanningResult } from 'expo-camera';

interface UseCameraReturn {
  hasPermission: boolean | null;
  cameraRef: React.RefObject<CameraView | null>;
  isScanning: boolean;
  flashMode: boolean;
  facing: 'front' | 'back';
  requestPermission: () => Promise<boolean>;
  scanQRCode: (result: BarcodeScanningResult) => void;
  toggleFlash: () => void;
  toggleFacing: () => void;
  setIsScanning: (scanning: boolean) => void;
}

/**
 * Hook for camera and QR code scanning functionality.
 * Uses expo-camera for camera access and barcode scanning.
 */
export function useCamera(): UseCameraReturn {
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [isScanning, setIsScanning] = useState(true);
  const [flashMode, setFlashMode] = useState(false);
  const [facing, setFacing] = useState<'front' | 'back'>('back');
  const cameraRef = {} as React.RefObject<CameraView | null>;

  const requestPermission = useCallback(async () => {
    try {
      const { status } = await Camera.requestCameraPermissionsAsync();
      const granted = status === 'granted';
      setHasPermission(granted);
      return granted;
    } catch (error) {
      console.error('Camera permission error:', error);
      setHasPermission(false);
      return false;
    }
  }, []);

  const scanQRCode = useCallback((result: BarcodeScanningResult) => {
    if (!isScanning) return;

    const data = result.data;
    if (data) {
      setIsScanning(false);
      // Handle QR code data - typically a URL or place ID
      console.log('QR Code scanned:', data);
    }
  }, [isScanning]);

  const toggleFlash = useCallback(() => {
    setFlashMode((prev) => !prev);
  }, []);

  const toggleFacing = useCallback(() => {
    setFacing((prev) => (prev === 'back' ? 'front' : 'back'));
  }, []);

  return {
    hasPermission,
    cameraRef,
    isScanning,
    flashMode,
    facing,
    requestPermission,
    scanQRCode,
    toggleFlash,
    toggleFacing,
    setIsScanning,
  };
}
