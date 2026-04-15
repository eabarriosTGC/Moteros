import { useState, useCallback, useEffect, useRef } from 'react';
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';

export interface AppNotification {
  id: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  date: Date;
}

interface UseNotificationsReturn {
  notification: AppNotification | null;
  expoPushToken: string | null;
  isLoading: boolean;
  error: string | null;
  registerForPushNotifications: () => Promise<string | null>;
  scheduleLocalNotification: (
    title: string,
    body: string,
    trigger?: Date | number
  ) => Promise<string | null>;
  cancelAllNotifications: () => Promise<void>;
}

/**
 * Hook for push notifications management using expo-notifications.
 */
export function useNotifications(): UseNotificationsReturn {
  const [notification, setNotification] = useState<AppNotification | null>(null);
  const [expoPushToken, setExpoPushToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const notificationListener = useRef<Notifications.EventSubscription>();
  const responseListener = useRef<Notifications.EventSubscription>();

  const registerForPushNotifications = useCallback(async (): Promise<string | null> => {
    setIsLoading(true);
    setError(null);

    try {
      // Request permission
      const { status: existingStatus } = await Notifications.getPermissionsAsync();
      let finalStatus = existingStatus;

      if (existingStatus !== 'granted') {
        const { status } = await Notifications.requestPermissionsAsync();
        finalStatus = status;
      }

      if (finalStatus !== 'granted') {
        setError('Push notification permission denied');
        return null;
      }

      // Get Expo push token
      const tokenData = await Notifications.getExpoPushTokenAsync({
        projectId: process.env.EXPO_PUBLIC_EAS_PROJECT_ID,
      });

      setExpoPushToken(tokenData.data);
      return tokenData.data;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to register for notifications';
      setError(message);
      return null;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const scheduleLocalNotification = useCallback(
    async (
      title: string,
      body: string,
      trigger?: Date | number
    ): Promise<string | null> => {
      setIsLoading(true);
      setError(null);

      try {
        let triggerConfig: Notifications.NotificationTriggerInput;

        if (typeof trigger === 'number') {
          // Seconds from now
          triggerConfig = {
            seconds: trigger,
            type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
          };
        } else if (trigger instanceof Date) {
          // Specific date
          triggerConfig = {
            type: Notifications.SchedulableTriggerInputTypes.DATE,
            date: trigger,
          };
        } else {
          // Immediate
          triggerConfig = {
            type: Notifications.SchedulableTriggerInputTypes.DATE,
            date: new Date(),
          };
        }

        const identifier = await Notifications.scheduleNotificationAsync({
          content: {
            title,
            body,
            sound: true,
          },
          trigger: triggerConfig,
        });

        return identifier;
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to schedule notification';
        setError(message);
        return null;
      } finally {
        setIsLoading(false);
      }
    },
    []
  );

  const cancelAllNotifications = useCallback(async (): Promise<void> => {
    setIsLoading(true);
    setError(null);
    try {
      await Notifications.cancelAllScheduledNotificationsAsync();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to cancel notifications';
      setError(message);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    // Listener for received notifications while app is foregrounded
    notificationListener.current = Notifications.addNotificationReceivedListener(
      (receivedNotification) => {
        setNotification({
          id: receivedNotification.request.identifier,
          title: receivedNotification.request.content.title || '',
          body: receivedNotification.request.content.body || '',
          data: receivedNotification.request.content.data as Record<string, unknown> | undefined,
          date: new Date(),
        });
      }
    );

    // Listener for notification response (user tapped notification)
    responseListener.current = Notifications.addNotificationResponseReceivedListener(
      (response) => {
        console.log('Notification response:', response);
        // Handle navigation or action based on notification data
      }
    );

    // Configure notification behavior for Android
    if (Platform.OS === 'android') {
      Notifications.setNotificationChannelAsync('default', {
        name: 'default',
        importance: Notifications.AndroidImportance.MAX,
        vibrationPattern: [0, 250, 250, 250],
        lightColor: '#FF231F7C',
      });
    }

    return () => {
      if (notificationListener.current) {
        Notifications.removeNotificationSubscription(notificationListener.current);
      }
      if (responseListener.current) {
        Notifications.removeNotificationSubscription(responseListener.current);
      }
    };
  }, []);

  return {
    notification,
    expoPushToken,
    isLoading,
    error,
    registerForPushNotifications,
    scheduleLocalNotification,
    cancelAllNotifications,
  };
}
