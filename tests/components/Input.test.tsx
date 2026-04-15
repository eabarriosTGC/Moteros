import { render } from '@testing-library/react-native';
import Input from '../../src/components/ui/Input';

describe('Input', () => {
  it('renders correctly', () => {
    const { getByPlaceholderText } = render(<Input placeholder="Test input" />);
    expect(getByPlaceholderText('Test input')).toBeTruthy();
  });
});
