import { Component, type ReactNode } from 'react';
import { View, Text } from 'react-native';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
}

export default class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  render() {
    if (this.state.hasError) {
      return (
        <View>
          <Text>ErrorBoundary</Text>
        </View>
      );
    }

    return this.props.children;
  }
}
