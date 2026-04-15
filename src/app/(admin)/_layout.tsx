import { Stack } from 'expo-router';

export default function AdminLayout() {
  return (
    <Stack>
      <Stack.Screen name="dashboard" options={{ title: 'Admin Dashboard' }} />
      <Stack.Screen name="suggestions" options={{ title: 'Review Suggestions' }} />
      <Stack.Screen name="aspirants" options={{ title: 'Manage Aspirants' }} />
      <Stack.Screen name="users" options={{ title: 'Manage Users' }} />
    </Stack>
  );
}
