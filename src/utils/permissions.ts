import { Platform, PermissionsAndroid } from 'react-native';
import { Camera } from 'expo-camera';
import * as Location from 'expo-location';
import * as ImagePicker from 'expo-image-picker';
import * as Notifications from 'expo-notifications';

export type PermissionType =
  | 'camera'
  | 'location'
  | 'notifications'
  | 'photos'
  | 'storage';

export interface PermissionResult {
  granted: boolean;
  canAskAgain: boolean;
  status: 'granted' | 'denied' | 'undetermined';
}

/**
 * Request camera permission.
 */
export async function requestCameraPermission(): Promise<PermissionResult> {
  if (Platform.OS === 'android') {
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.CAMERA,
      {
        title: 'Camera Permission',
        message: 'This app needs access to your camera to scan QR codes.',
        buttonPositive: 'OK',
        buttonNegative: 'Cancel',
      }
    );
    return {
      granted: granted === PermissionsAndroid.RESULTS.GRANTED,
      canAskAgain: granted !== PermissionsAndroid.RESULTS.NEVER_ASK_AGAIN,
      status:
        granted === PermissionsAndroid.RESULTS.GRANTED ? 'granted' : 'denied',
    };
  }

  const { status } = await Camera.requestCameraPermissionsAsync();
  return {
    granted: status === 'granted',
    canAskAgain: true,
    status: status as 'granted' | 'denied',
  };
}

/**
 * Request location permission.
 */
export async function requestLocationPermission(): Promise<PermissionResult> {
  if (Platform.OS === 'android') {
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
      {
        title: 'Location Permission',
        message: 'This app needs access to your location to show nearby places.',
        buttonPositive: 'OK',
        buttonNegative: 'Cancel',
      }
    );
    return {
      granted: granted === PermissionsAndroid.RESULTS.GRANTED,
      canAskAgain: granted !== PermissionsAndroid.RESULTS.NEVER_ASK_AGAIN,
      status:
        granted === PermissionsAndroid.RESULTS.GRANTED ? 'granted' : 'denied',
    };
  }

  const { status } = await Location.requestForegroundPermissionsAsync();
  return {
    granted: status === 'granted',
    canAskAgain: true,
    status: status as 'granted' | 'denied',
  };
}

/**
 * Request push notification permission.
 */
export async function requestNotificationPermission(): Promise<PermissionResult> {
  const { status } = await Notifications.requestPermissionsAsync();
  return {
    granted: status === 'granted',
    canAskAgain: true,
    status: status as 'granted' | 'denied',
  };
}

/**
 * Request photo library permission.
 */
export async function requestPhotosPermission(): Promise<PermissionResult> {
  if (Platform.OS === 'android') {
    const permission =
      Platform.Version >= 33
        ? PermissionsAndroid.PERMISSIONS.READ_MEDIA_IMAGES
        : PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE;

    const granted = await PermissionsAndroid.request(permission, {
      title: 'Photo Library Permission',
      message: 'This app needs access to your photos to upload images.',
      buttonPositive: 'OK',
      buttonNegative: 'Cancel',
    });
    return {
      granted: granted === PermissionsAndroid.RESULTS.GRANTED,
      canAskAgain: granted !== PermissionsAndroid.RESULTS.NEVER_ASK_AGAIN,
      status:
        granted === PermissionsAndroid.RESULTS.GRANTED ? 'granted' : 'denied',
    };
  }

  const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
  return {
    granted: status === 'granted',
    canAskAgain: true,
    status: status as 'granted' | 'denied',
  };
}

/**
 * Request a permission by type.
 */
export async function requestPermission(
  type: PermissionType
): Promise<PermissionResult> {
  switch (type) {
    case 'camera':
      return requestCameraPermission();
    case 'location':
      return requestLocationPermission();
    case 'notifications':
      return requestNotificationPermission();
    case 'photos':
      return requestPhotosPermission();
    default:
      return { granted: false, canAskAgain: true, status: 'undetermined' };
  }
}

/**
 * Request multiple permissions at once.
 */
export async function requestPermissions(
  types: PermissionType[]
): Promise<Record<PermissionType, PermissionResult>> {
  const results = {} as Record<PermissionType, PermissionResult>;

  for (const type of types) {
    results[type] = await requestPermission(type);
  }

  return results;
}
