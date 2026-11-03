import { useState } from 'react';
import type { FormEvent } from 'react';
import { login } from '../api';
import type { User } from '../types';

export default function LoginPage({
  onLoggedIn,
}: {
  onLoggedIn: (user: User) => void;
}) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [formError, setFormError] = useState('');
  const [apiError, setApiError] = useState('');
  const [busy, setBusy] = useState(false);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setFormError('');
    setApiError('');
    if (!email.trim() || !/^\S+@\S+\.\S+$/.test(email.trim())) {
      setFormError('Enter a valid email address.');
      return;
    }
    if (!password) {
      setFormError('Enter your password.');
      return;
    }
    setBusy(true);
    try {
      const data = await login(email.trim(), password);
      onLoggedIn(data.user);
    } catch (err) {
      setApiError(err instanceof Error ? err.message : 'Sign-in failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="mx-auto max-w-md px-4 py-10">
      <h1 className="text-2xl font-bold">Sign in to PlacementPulse</h1>
      <p className="mt-2 text-sm text-gray-600">
        Students and coordinators sign in with the same form.
      </p>
      <form onSubmit={handleSubmit} className="mt-6 space-y-4" noValidate>
        <div>
          <label htmlFor="email" className="block text-sm font-medium">
            Email
          </label>
          <input
            id="email"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-1 w-full rounded border px-3 py-2"
          />
        </div>
        <div>
          <label htmlFor="password" className="block text-sm font-medium">
            Password
          </label>
          <input
            id="password"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-1 w-full rounded border px-3 py-2"
          />
        </div>
        {formError && (
          <p role="alert" className="text-sm text-red-700">
            {formError}
          </p>
        )}
        {apiError && (
          <p role="alert" className="text-sm text-red-700">
            {apiError}
          </p>
        )}
        <button
          type="submit"
          disabled={busy}
          className="w-full rounded bg-blue-600 px-4 py-2 font-medium text-white disabled:opacity-50"
        >
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </main>
  );
}
