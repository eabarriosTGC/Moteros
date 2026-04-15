/**
 * Icon component wrapping @expo/vector-icons to match Lucide icons used in design.
 */
import React from 'react';
import { Ionicons, MaterialCommunityIcons, FontAwesome5 } from '@expo/vector-icons';

type IconName =
  | 'Home'
  | 'MapPin'
  | 'Star'
  | 'Users'
  | 'User'
  | 'Bell'
  | 'Calendar'
  | 'TrendingUp'
  | 'ChevronRight'
  | 'Search'
  | 'Filter'
  | 'Lock'
  | 'CheckCircle'
  | 'QrCode'
  | 'ChevronDown'
  | 'Map'
  | 'Trophy'
  | 'Camera'
  | 'Settings'
  | 'LogOut'
  | 'Crown'
  | 'Clock'
  | 'XCircle'
  | 'Car'
  | 'Restaurant'
  | 'Hotel'
  | 'Wrench';

interface IconProps {
  name: IconName;
  size?: number;
  color?: string;
  style?: any;
}

const iconMap: Record<IconName, { family: string; iconName: string }> = {
  Home: { family: 'Ionicons', iconName: 'home' },
  MapPin: { family: 'Ionicons', iconName: 'location' },
  Star: { family: 'Ionicons', iconName: 'star' },
  Users: { family: 'Ionicons', iconName: 'people' },
  User: { family: 'Ionicons', iconName: 'person' },
  Bell: { family: 'Ionicons', iconName: 'notifications' },
  Calendar: { family: 'Ionicons', iconName: 'calendar' },
  TrendingUp: { family: 'Ionicons', iconName: 'trending-up' },
  ChevronRight: { family: 'Ionicons', iconName: 'chevron-forward' },
  Search: { family: 'Ionicons', iconName: 'search' },
  Filter: { family: 'Ionicons', iconName: 'options' },
  Lock: { family: 'Ionicons', iconName: 'lock-closed' },
  CheckCircle: { family: 'Ionicons', iconName: 'checkmark-circle' },
  QrCode: { family: 'MaterialCommunityIcons', iconName: 'qrcode' },
  ChevronDown: { family: 'Ionicons', iconName: 'chevron-down' },
  Map: { family: 'Ionicons', iconName: 'map' },
  Trophy: { family: 'Ionicons', iconName: 'trophy' },
  Camera: { family: 'Ionicons', iconName: 'camera' },
  Settings: { family: 'Ionicons', iconName: 'settings' },
  LogOut: { family: 'Ionicons', iconName: 'log-out' },
  Crown: { family: 'MaterialCommunityIcons', iconName: 'crown' },
  Clock: { family: 'Ionicons', iconName: 'time' },
  XCircle: { family: 'Ionicons', iconName: 'close-circle' },
  Car: { family: 'MaterialCommunityIcons', iconName: 'motorbike' },
  Restaurant: { family: 'MaterialCommunityIcons', iconName: 'restaurant' },
  Hotel: { family: 'MaterialCommunityIcons', iconName: 'hotel' },
  Wrench: { family: 'MaterialCommunityIcons', iconName: 'wrench' },
};

export const Icon: React.FC<IconProps> = ({ name, size = 24, color = '#FFFFFF', style }) => {
  const mapping = iconMap[name];
  if (!mapping) {
    return null;
  }

  const iconProps = { name: mapping.iconName, size, color, style };

  switch (mapping.family) {
    case 'Ionicons':
      return <Ionicons {...iconProps} />;
    case 'MaterialCommunityIcons':
      return <MaterialCommunityIcons {...iconProps} />;
    case 'FontAwesome5':
      return <FontAwesome5 {...iconProps} />;
    default:
      return null;
  }
};

export default Icon;
