import { Stack } from 'expo-router';

export default function MemberLayout() {
  return (
    <Stack>
      <Stack.Screen name="places/[id]" options={{ title: 'Place Detail' }} />
      <Stack.Screen name="places/suggest" options={{ title: 'Suggest Place' }} />
      <Stack.Screen name="recommendations/index" options={{ title: 'Recommendations' }} />
      <Stack.Screen name="recommendations/[id]" options={{ title: 'Recommendation Detail' }} />
      <Stack.Screen name="visits/index" options={{ title: 'Visits History' }} />
      <Stack.Screen name="visits/[id]" options={{ title: 'Visit Detail' }} />
    </Stack>
  );
}
