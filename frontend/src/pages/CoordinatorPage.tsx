import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import {
  createNotice,
  getNotice,
  listNotices,
  parseNotice,
  publishNotice,
  updateNotice,
} from '../api';
import type { Notice, NoticeForm, Uncertainty } from '../types';

const EMPTY_FORM: NoticeForm = {
  company: null,
  category: null,
  drive_date: null,
  eligible_branches: null,
  minimum_cgpa: null,
  minimum_class_x_percentage: null,
  minimum_class_xii_percentage: null,
  arrears_rule: null,
  ctc: null,
  stipend: null,
  registration_deadline: null,
  registration_url: null,
  location: null,
  source_text: '',
  status: 'draft',
};

const TEXT_FIELDS: { key: keyof NoticeForm; label: string }[] = [
  { key: 'company', label: 'Company' },
  { key: 'category', label: 'Category' },
  { key: 'arrears_rule', label: 'Arrears rule' },
  { key: 'ctc', label: 'CTC' },
  { key: 'stipend', label: 'Stipend' },
  { key: 'location', label: 'Location' },
];

const NUMBER_FIELDS: { key: keyof NoticeForm; label: string }[] = [
  { key: 'minimum_cgpa', label: 'Minimum CGPA' },
  { key: 'minimum_class_x_percentage', label: 'Minimum Class X percentage' },
  { key: 'minimum_class_xii_percentage', label: 'Minimum Class XII percentage' },
];

function toPayload(form: NoticeForm): Record<string, unknown> {
  return {
    company: form.company,
    category: form.category,
    drive_date: form.drive_date,
    eligible_branches: form.eligible_branches,
    minimum_cgpa: form.minimum_cgpa,
    minimum_class_x_percentage: form.minimum_class_x_percentage,
    minimum_class_xii_percentage: form.minimum_class_xii_percentage,
    arrears_rule: form.arrears_rule,
    ctc: form.ctc,
    stipend: form.stipend,
    registration_deadline: form.registration_deadline,
    registration_url: form.registration_url,
    location: form.location,
    source_text: form.source_text,
    status: form.status,
  };
}

export default function CoordinatorPage() {
  const [form, setForm] = useState<NoticeForm>(EMPTY_FORM);
  const [uncertainties, setUncertainties] = useState<Uncertainty[]>([]);
  const [savedId, setSavedId] = useState<number | null>(null);
  const [drafts, setDrafts] = useState<Notice[]>([]);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    listNotices({ status: 'draft', per_page: 20 })
      .then((data) => setDrafts(data.notices))
      .catch(() => {
        // Draft list is a convenience; a failure here must not block parsing.
      });
  }, []);

  function uncertaintyFor(field: string): string | undefined {
    return uncertainties.find((u) => u.field === field)?.message;
  }

  function setField(key: keyof NoticeForm, value: unknown) {
    setForm((current) => ({ ...current, [key]: value }));
  }

  function textValue(value: unknown): string {
    return typeof value === 'string' ? value : '';
  }

  function numberValue(value: unknown): string {
    return typeof value === 'number' ? String(value) : '';
  }

  async function handleParse(event: FormEvent) {
    event.preventDefault();
    setError('');
    setMessage('');
    if (!form.source_text.trim()) {
      setError('Paste a notice before parsing.');
      return;
    }
    setBusy(true);
    try {
      const data = await parseNotice(form.source_text);
      setForm((current) => ({ ...current, ...data.parsed }));
      setUncertainties(data.uncertainties);
      setMessage(
        data.uncertainties.length > 0
          ? 'Parsed with uncertainties — review the flagged fields before publishing.'
          : 'Parsed. Review the fields before publishing.',
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Parsing failed.');
    } finally {
      setBusy(false);
    }
  }

  async function handleSaveDraft() {
    setError('');
    setMessage('');
    setBusy(true);
    try {
      const payload = toPayload({ ...form, status: 'draft' });
      const data = savedId
        ? await updateNotice(savedId, payload)
        : await createNotice(payload);
      setSavedId(data.notice.id);
      setMessage('Draft saved.');
      const draftList = await listNotices({ status: 'draft', per_page: 20 });
      setDrafts(draftList.notices);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save draft.');
    } finally {
      setBusy(false);
    }
  }

  async function handlePublish() {
    setError('');
    setMessage('');
    if (!savedId) {
      setError('Save a draft first, then publish it.');
      return;
    }
    setBusy(true);
    try {
      await publishNotice(savedId);
      setMessage('Notice published.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not publish.');
    } finally {
      setBusy(false);
    }
  }

  async function loadDraft(id: number) {
    setError('');
    try {
      const data = await getNotice(id);
      const notice = data.notice;
      setForm({
        company: notice.company,
        category: notice.category,
        drive_date: notice.drive_date,
        eligible_branches: notice.eligible_branches,
        minimum_cgpa: notice.minimum_cgpa,
        minimum_class_x_percentage: notice.minimum_class_x_percentage,
        minimum_class_xii_percentage: notice.minimum_class_xii_percentage,
        arrears_rule: notice.arrears_rule,
        ctc: notice.ctc,
        stipend: notice.stipend,
        registration_deadline: notice.registration_deadline,
        registration_url: notice.registration_url,
        location: notice.location,
        source_text: notice.source_text ?? '',
        status: notice.status,
      });
      setSavedId(notice.id);
      setUncertainties([]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load draft.');
    }
  }

  const inputClass = 'mt-1 w-full rounded border px-3 py-2';

  return (
    <main className="mx-auto max-w-3xl px-4 py-8">
      <h1 className="text-2xl font-bold">Coordinator: review a notice</h1>
      <p className="mt-2 text-sm text-gray-600">
        Paste the notice, parse it, correct any flagged field, save a draft,
        then publish. Missing requirements are never treated as unrestricted.
      </p>

      <form onSubmit={handleParse} className="mt-6 space-y-4">
        <div>
          <label htmlFor="source-text" className="block text-sm font-medium">
            Notice text
          </label>
          <textarea
            id="source-text"
            rows={10}
            value={form.source_text}
            onChange={(e) => setField('source_text', e.target.value)}
            className={inputClass}
          />
        </div>
        <button
          type="submit"
          disabled={busy}
          className="rounded bg-blue-600 px-4 py-2 font-medium text-white disabled:opacity-50"
        >
          {busy ? 'Parsing…' : 'Parse'}
        </button>
      </form>

      <section aria-label="Extracted fields" className="mt-8 space-y-4">
        <h2 className="text-lg font-semibold">Extracted fields</h2>

        {TEXT_FIELDS.map(({ key, label }) => (
          <div key={key}>
            <label htmlFor={`field-${key}`} className="block text-sm font-medium">
              {label}
            </label>
            <input
              id={`field-${key}`}
              value={textValue(form[key])}
              onChange={(e) => setField(key, e.target.value || null)}
              className={inputClass}
            />
            {uncertaintyFor(key) && (
              <p role="alert" className="mt-1 text-sm text-amber-800">
                ⚠ {uncertaintyFor(key)}
              </p>
            )}
          </div>
        ))}

        <div>
          <label htmlFor="field-eligible-branches" className="block text-sm font-medium">
            Eligible branches (comma-separated)
          </label>
          <input
            id="field-eligible-branches"
            value={(form.eligible_branches ?? []).join(', ')}
            onChange={(e) =>
              setField(
                'eligible_branches',
                e.target.value
                  .split(',')
                  .map((part) => part.trim())
                  .filter(Boolean),
              )
            }
            className={inputClass}
          />
          {uncertaintyFor('eligible_branches') && (
            <p role="alert" className="mt-1 text-sm text-amber-800">
              ⚠ {uncertaintyFor('eligible_branches')}
            </p>
          )}
        </div>

        {NUMBER_FIELDS.map(({ key, label }) => (
          <div key={key}>
            <label htmlFor={`field-${key}`} className="block text-sm font-medium">
              {label}
            </label>
            <input
              id={`field-${key}`}
              type="number"
              step="0.01"
              value={numberValue(form[key])}
              onChange={(e) =>
                setField(key, e.target.value === '' ? null : Number(e.target.value))
              }
              className={inputClass}
            />
            {uncertaintyFor(key) && (
              <p role="alert" className="mt-1 text-sm text-amber-800">
                ⚠ {uncertaintyFor(key)}
              </p>
            )}
          </div>
        ))}

        <div>
          <label htmlFor="field-drive-date" className="block text-sm font-medium">
            Drive date
          </label>
          <input
            id="field-drive-date"
            type="date"
            value={textValue(form.drive_date)}
            onChange={(e) => setField('drive_date', e.target.value || null)}
            className={inputClass}
          />
          {uncertaintyFor('drive_date') && (
            <p role="alert" className="mt-1 text-sm text-amber-800">
              ⚠ {uncertaintyFor('drive_date')}
            </p>
          )}
        </div>

        <div>
          <label htmlFor="field-deadline" className="block text-sm font-medium">
            Registration deadline
          </label>
          <input
            id="field-deadline"
            type="datetime-local"
            value={textValue(form.registration_deadline).slice(0, 16)}
            onChange={(e) => setField('registration_deadline', e.target.value || null)}
            className={inputClass}
          />
          {uncertaintyFor('registration_deadline') && (
            <p role="alert" className="mt-1 text-sm text-amber-800">
              ⚠ {uncertaintyFor('registration_deadline')}
            </p>
          )}
        </div>

        <div>
          <label htmlFor="field-url" className="block text-sm font-medium">
            Registration URL
          </label>
          <input
            id="field-url"
            type="url"
            value={textValue(form.registration_url)}
            onChange={(e) => setField('registration_url', e.target.value || null)}
            className={inputClass}
          />
          {uncertaintyFor('registration_url') && (
            <p role="alert" className="mt-1 text-sm text-amber-800">
              ⚠ {uncertaintyFor('registration_url')}
            </p>
          )}
        </div>

        <div className="flex flex-wrap gap-3">
          <button
            type="button"
            onClick={handleSaveDraft}
            disabled={busy}
            className="rounded border px-4 py-2 font-medium disabled:opacity-50"
          >
            Save as draft
          </button>
          <button
            type="button"
            onClick={handlePublish}
            disabled={busy || !savedId}
            className="rounded bg-green-700 px-4 py-2 font-medium text-white disabled:opacity-50"
          >
            Publish
          </button>
        </div>

        {message && (
          <p role="status" className="text-sm text-green-700">
            {message}
          </p>
        )}
        {error && (
          <p role="alert" className="text-sm text-red-700">
            {error}
          </p>
        )}
      </section>

      <section aria-label="Draft notices" className="mt-10">
        <h2 className="text-lg font-semibold">Drafts</h2>
        {drafts.length === 0 ? (
          <p className="mt-2 text-sm text-gray-600">No drafts yet.</p>
        ) : (
          <ul className="mt-2 space-y-2">
            {drafts.map((draft) => (
              <li key={draft.id}>
                <button
                  type="button"
                  onClick={() => loadDraft(draft.id)}
                  className="text-sm font-medium text-blue-700 underline"
                >
                  {draft.company ?? `Draft #${draft.id}`}
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </main>
  );
}
