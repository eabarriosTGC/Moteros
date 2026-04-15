import type { NavigatorScreenParams } from '@react-navigation/native';

/**
 * Navigation types for React Navigation.
 * Defines all screen parameters for each navigator stack.
 */

export type RootStackParamList = {
  App: NavigatorScreenParams<TabsStackParamList>;
  Auth: NavigatorScreenParams<AuthStackParamList>;
  PlaceDetail: { placeId: string };
  QRScanner: undefined;
  FullScreenImage: { imageUrl: string };
  Notifications: undefined;
};

export type AuthStackParamList = {
  SignIn: undefined;
  SignUp: undefined;
  ForgotPassword: undefined;
  AspirantForm: undefined;
};

export type TabsStackParamList = {
  Home: NavigatorScreenParams<HomeStackParamList>;
  Places: NavigatorScreenParams<PlaceStackParamList>;
  Visits: undefined;
  Profile: NavigatorScreenParams<SettingsStackParamList>;
  Map: undefined;
};

export type HomeStackParamList = {
  HomeMain: undefined;
  Recommendations: undefined;
  Posadas: undefined;
};

export type PlaceStackParamList = {
  PlacesList: undefined;
  PlaceDetail: { placeId: string };
  PlaceEdit: { placeId: string };
  AddPlace: undefined;
};

export type SettingsStackParamList = {
  Profile: undefined;
  EditProfile: undefined;
  Membership: undefined;
  Settings: undefined;
  Suggestions: undefined;
  HelpAndSupport: undefined;
};

export interface AppNavigatorProps {
  initialRouteName?: keyof RootStackParamList;
  isAuthenticated: boolean;
}

export interface NavigationRoute {
  name: string;
  params?: Record<string, unknown>;
}
