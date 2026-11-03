import { useCallback, useEffect, useState } from 'react';
import { listNotices } from '../api';
import EligibilityStatus from '../components/EligibilityStatus';
import RegistrationButton from '../components/RegistrationButton';
import type { Notice, RegistrationInfo } from '../types';

function formatDate(value: string | null): string {
  if (!value) return 'Not specified';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}

export default function DashboardPage() {
  const [notices, setNotices] = useState<Notice[]>([]);
  const [eligibleOnly, setEligibleOnly] = useState(false);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const data = await listNotices({
        eligible_only: eligibleOnly,
        page,
        per_page: 20,
      });
      // Sort by registration deadline, ascending; notices without a
      // deadline go last. This holds even if the server order changes.
      const sorted = [...data.notices].sort((a, b) => {
        if (!a.registration_deadline) return 1;
        if (!b.registration_deadline) return -1;
        return (
          new Date(a.registration_deadline).getTime() -
          new Date(b.registration_deadline).getTime()
        );
      });
      setNotices(sorted);
      setTotalPages(data.meta?.total_pages ?? 1);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load notices.');
    } finally {
      setLoading(false);
    }
  }, [eligibleOnly, page]);

  useEffect(() => {
    load();
  }, [load]);

  function updateRegistration(noticeId: number, next: RegistrationInfo) {
    setNotices((current) =>
      current.map((notice) =>
        notice.id === noticeId
          ? { ...notice, registration: next }
          : notice,
      ),
    );
  }

  return (
    <main className="mx-auto max-w-4xl px-4 py-8">
      <h1 className="text-2xl font-bold">Published opportunities</h1>

      <label className="mt-4 inline-flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          checked={eligibleOnly}
          onChange={(e) => {
            setEligibleOnly(e.target.checked);
            setPage(1);
          }}
        />
        Eligible only
      </label>

      {loading && (
        <p role="status" className="mt-6 text-gray-600">
          Loading…
        </p>
      )}

      {error && (
        <p role="alert" className="mt-6 text-red-700">
          {error}
        </p>
      )}

      {!loading && !error && notices.length === 0 && (
        <p className="mt-6 text-gray-600">
          No published opportunities match this filter yet.
        </p>
      )}

      <ul className="mt-6 space-y-4">
        {notices.map((notice) => (
          <li key={notice.id} className="rounded border p-4 shadow-sm">
            <h2 className="text-lg font-semibold">
              {notice.company ?? 'Company not specified'}
            </h2>
            <p className="text-sm text-gray-600">
              {[notice.category, notice.location, notice.drive_date ? `Drive: ${notice.drive_date}` : null]
                .filter(Boolean)
                .join(' · ')}
            </p>
            <p className="mt-2 text-sm">
              Registration deadline:{' '}
              <strong>{formatDate(notice.registration_deadline)}</strong>
            </p>
            {(notice.ctc || notice.stipend) && (
              <p className="text-sm text-gray-700">
                {[notice.ctc ? `CTC: ${notice.ctc}` : null, notice.stipend ? `Stipend: ${notice.stipend}` : null]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
            )}
            {notice.eligible_branches && (
              <p className="text-sm text-gray-700">
                Eligible branches: {notice.eligible_branches.join(', ')}
              </p>
            )}
            <div className="mt-3">
              <EligibilityStatus eligibility={notice.eligibility} />
            </div>
            <div className="mt-3">
              <RegistrationButton
                noticeId={notice.id}
                registration={notice.registration}
                onUpdate={(next) => updateRegistration(notice.id, next)}
              />
            </div>
            {notice.registration_url && (
              <p className="mt-3">
                <a
                  href={notice.registration_url}
                  target="_blank"
                  rel="noreferrer"
                  className="text-sm font-medium text-blue-700 underline"
                >
                  Open registration page
                </a>
              </p>
            )}
          </li>
        ))}
      </ul>

      {totalPages > 1 && (
        <nav aria-label="Pagination" className="mt-6 flex items-center gap-3">
          <button
            type="button"
            disabled={page <= 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            className="rounded border px-3 py-1 text-sm disabled:opacity-50"
          >
            Previous
          </button>
          <span className="text-sm">
            Page {page} of {totalPages}
          </span>
          <button
            type="button"
            disabled={page >= totalPages}
            onClick={() => setPage((p) => p + 1)}
            className="rounded border px-3 py-1 text-sm disabled:opacity-50"
          >
            Next
          </button>
        </nav>
      )}
    </main>
  );
}
