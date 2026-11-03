import { useState } from 'react';
import { createRegistration, deleteRegistration } from '../api';
import type { RegistrationInfo } from '../types';

export default function RegistrationButton({
  noticeId,
  registration,
  onUpdate,
}: {
  noticeId: number;
  registration: RegistrationInfo | undefined;
  onUpdate?: (registration: RegistrationInfo) => void;
}) {
  const [status, setStatus] = useState<RegistrationInfo['status']>(
    registration?.status ?? 'not_registered',
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const registered = status === 'registered';

  async function handleClick() {
    setBusy(true);
    setError('');
    try {
      const result = registered
        ? await deleteRegistration(noticeId)
        : await createRegistration(noticeId);
      const next: RegistrationInfo = {
        status:
          result.registration.status === 'registered'
            ? 'registered'
            : 'not_registered',
        registered_at: result.registration.registered_at,
      };
      setStatus(next.status);
      onUpdate?.(next);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Registration failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <p className="mb-2 text-sm text-gray-700">
        Registration status: <strong>{registered ? 'Registered' : 'Not registered'}</strong>
      </p>
      <button
        type="button"
        onClick={handleClick}
        disabled={busy}
        className="rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
      >
        {registered ? 'Undo registration' : 'I Registered'}
      </button>
      {error && (
        <p role="alert" className="mt-2 text-sm text-red-700">
          {error}
        </p>
      )}
    </div>
  );
}
