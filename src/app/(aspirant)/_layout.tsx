import { Stack } from 'expo-router';

export default function AspirantLayout() {
  return (
    <Stack>
      <Stack.Screen name="apply" options={{ title: 'Application Form' }} />
      <Stack.Screen name="challenges" options={{ title: 'Challenges' }} />
      <Stack.Screen name="status" options={{ title: 'Application Status' }} />
    </Stack>
  );
}
