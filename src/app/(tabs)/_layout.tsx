import { Tabs } from 'expo-router';
import { Platform } from 'react-native';

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: '#f59e0b',
        tabBarInactiveTintColor: '#9ca3af',
        tabBarStyle: {
          backgroundColor: '#1f2937',
          borderTopColor: '#374151',
          borderTopWidth: 1,
          paddingBottom: Platform.OS === 'ios' ? 20 : 8,
          paddingTop: 8,
          height: Platform.OS === 'ios' ? 88 : 68,
        },
        tabBarLabelStyle: {
          fontSize: 10,
          fontWeight: '500',
        },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Inicio',
          tabBarIcon: ({ color, size }) => {
            const { Ionicons } = require('@expo/vector-icons');
            return <Ionicons name="home" size={size} color={color} />;
          },
        }}
      />
      <Tabs.Screen
        name="lugares"
        options={{
          title: 'Lugares',
          tabBarIcon: ({ color, size }) => {
            const { Ionicons } = require('@expo/vector-icons');
            return <Ionicons name="location" size={size} color={color} />;
          },
        }}
      />
      <Tabs.Screen
        name="recomendaciones"
        options={{
          title: 'Recomen.',
          tabBarIcon: ({ color, size }) => {
            const { Ionicons } = require('@expo/vector-icons');
            return <Ionicons name="star" size={size} color={color} />;
          },
        }}
      />
      <Tabs.Screen
        name="comunidad"
        options={{
          title: 'Comunidad',
          tabBarIcon: ({ color, size }) => {
            const { Ionicons } = require('@expo/vector-icons');
            return <Ionicons name="people" size={size} color={color} />;
          },
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Perfil',
          tabBarIcon: ({ color, size }) => {
            const { Ionicons } = require('@expo/vector-icons');
            return <Ionicons name="person" size={size} color={color} />;
          },
        }}
      />
    </Tabs>
  );
}
