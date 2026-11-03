import { useState } from 'react';
import type { FormEvent } from 'react';
import { updateProfile } from '../api';
import type { User } from '../types';

function toNumber(value: string): number | null {
  if (value.trim() === '') return null;
  const parsed = Number(value);
  return Number.isNaN(parsed) ? null : parsed;
}

export default function ProfilePage({
  user,
  onUpdated,
}: {
  user: User;
  onUpdated: (user: User) => void;
}) {
  const [branch, setBranch] = useState(user.branch ?? '');
  const [cgpa, setCgpa] = useState(user.cgpa == null ? '' : String(user.cgpa));
  const [classX, setClassX] = useState(
    user.class_x_percentage == null ? '' : String(user.class_x_percentage),
  );
  const [classXII, setClassXII] = useState(
    user.class_xii_percentage == null ? '' : String(user.class_xii_percentage),
  );
  const [arrears, setArrears] = useState(
    user.standing_arrears == null ? '' : String(user.standing_arrears),
  );
  const [formError, setFormError] = useState('');
  const [apiError, setApiError] = useState('');
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setFormError('');
    setApiError('');
    setSaved(false);

    const cgpaValue = toNumber(cgpa);
    const xValue = toNumber(classX);
    const xiiValue = toNumber(classXII);
    if (cgpa !== '' && (cgpaValue == null || cgpaValue < 0 || cgpaValue > 10)) {
      setFormError('CGPA must be between 0 and 10.');
      return;
    }
    if (classX !== '' && (xValue == null || xValue < 0 || xValue > 100)) {
      setFormError('Class X percentage must be between 0 and 100.');
      return;
    }
    if (classXII !== '' && (xiiValue == null || xiiValue < 0 || xiiValue > 100)) {
      setFormError('Class XII percentage must be between 0 and 100.');
      return;
    }

    setBusy(true);
    try {
      const data = await updateProfile({
        branch: branch.trim() === '' ? null : branch.trim(),
        cgpa: cgpaValue,
        class_x_percentage: xValue,
        class_xii_percentage: xiiValue,
        standing_arrears: arrears === '' ? null : arrears === 'true',
      });
      onUpdated(data.user);
      setSaved(true);
    } catch (err) {
      setApiError(err instanceof Error ? err.message : 'Could not save profile.');
    } finally {
      setBusy(false);
    }
  }

  const inputClass = 'mt-1 w-full rounded border px-3 py-2';

  return (
    <main className="mx-auto max-w-xl px-4 py-8">
      <h1 className="text-2xl font-bold">Student profile</h1>
      <p className="mt-2 text-sm text-gray-600">
        Signed in as {user.email}. Only you can edit this profile.
      </p>
      <form onSubmit={handleSubmit} className="mt-6 space-y-4" noValidate>
        <div>
          <label htmlFor="branch" className="block text-sm font-medium">
            Branch
          </label>
          <input
            id="branch"
            value={branch}
            onChange={(e) => setBranch(e.target.value)}
            placeholder="e.g. CSE"
            className={inputClass}
          />
        </div>
        <div>
          <label htmlFor="cgpa" className="block text-sm font-medium">
            CGPA (0–10)
          </label>
          <input
            id="cgpa"
            type="number"
            min="0"
            max="10"
            step="0.01"
            value={cgpa}
            onChange={(e) => setCgpa(e.target.value)}
            className={inputClass}
          />
        </div>
        <div>
          <label htmlFor="class-x" className="block text-sm font-medium">
            Class X percentage (0–100)
          </label>
          <input
            id="class-x"
            type="number"
            min="0"
            max="100"
            step="0.01"
            value={classX}
            onChange={(e) => setClassX(e.target.value)}
            className={inputClass}
          />
        </div>
        <div>
          <label htmlFor="class-xii" className="block text-sm font-medium">
            Class XII percentage (0–100)
          </label>
          <input
            id="class-xii"
            type="number"
            min="0"
            max="100"
            step="0.01"
            value={classXII}
            onChange={(e) => setClassXII(e.target.value)}
            className={inputClass}
          />
        </div>
        <div>
          <label htmlFor="arrears" className="block text-sm font-medium">
            Standing arrears
          </label>
          <select
            id="arrears"
            value={arrears}
            onChange={(e) => setArrears(e.target.value)}
            className={inputClass}
          >
            <option value="">Not specified</option>
            <option value="true">Yes</option>
            <option value="false">No</option>
          </select>
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
        {saved && (
          <p role="status" className="text-sm text-green-700">
            Profile saved.
          </p>
        )}
        <button
          type="submit"
          disabled={busy}
          className="rounded bg-blue-600 px-4 py-2 font-medium text-white disabled:opacity-50"
        >
          {busy ? 'Saving…' : 'Save profile'}
        </button>
      </form>
    </main>
  );
}
