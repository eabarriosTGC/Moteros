import { signIn, signUp, signOut } from '../../src/services/auth';

describe('Auth Service', () => {
  it('signIn is defined', () => {
    expect(signIn).toBeDefined();
  });

  it('signUp is defined', () => {
    expect(signUp).toBeDefined();
  });

  it('signOut is defined', () => {
    expect(signOut).toBeDefined();
  });
});
