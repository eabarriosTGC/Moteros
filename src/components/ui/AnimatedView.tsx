/**
 * AnimatedView - A reusable animated component using React Native's built-in Animated API.
 * No external dependencies required.
 */
import React, { useEffect, useRef } from 'react';
import { ViewStyle, Animated, StyleProp } from 'react-native';

type AnimationType = 'fade' | 'slideRight' | 'slideLeft' | 'slideUp' | 'slideDown' | 'scale';

interface AnimatedViewProps {
  children: React.ReactNode;
  type?: AnimationType;
  delay?: number;
  duration?: number;
  style?: StyleProp<ViewStyle>;
}

export const AnimatedView: React.FC<AnimatedViewProps> = ({
  children,
  type = 'fade',
  delay = 0,
  duration = 300,
  style,
}) => {
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const translateXAnim = useRef(
    new Animated.Value(type === 'slideRight' ? 20 : type === 'slideLeft' ? -20 : 0)
  ).current;
  const translateYAnim = useRef(
    new Animated.Value(type === 'slideUp' ? 20 : type === 'slideDown' ? -20 : 0)
  ).current;
  const scaleAnim = useRef(new Animated.Value(type === 'scale' ? 0 : 1)).current;

  useEffect(() => {
    Animated.sequence([
      Animated.delay(delay),
      Animated.parallel([
        Animated.timing(fadeAnim, {
          toValue: 1,
          duration,
          useNativeDriver: true,
        }),
        Animated.timing(translateXAnim, {
          toValue: 0,
          duration,
          useNativeDriver: true,
        }),
        Animated.timing(translateYAnim, {
          toValue: 0,
          duration,
          useNativeDriver: true,
        }),
        Animated.timing(scaleAnim, {
          toValue: 1,
          duration,
          useNativeDriver: true,
        }),
      ]),
    ]).start();
  }, [delay, duration]);

  const animatedStyle: ViewStyle = {
    opacity: fadeAnim,
    transform: [
      { translateX: translateXAnim },
      { translateY: translateYAnim },
      { scale: scaleAnim },
    ],
  };

  return (
    <Animated.View style={[animatedStyle, style]}>
      {children}
    </Animated.View>
  );
};

export default AnimatedView;
