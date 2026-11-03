import type { Eligibility } from '../types';

const LABELS: Record<Eligibility['status'], string> = {
  eligible: 'Eligible',
  not_eligible: 'Not eligible',
  needs_clarification: 'Needs clarification',
};

const STYLES: Record<Eligibility['status'], string> = {
  eligible: 'bg-green-100 text-green-800',
  not_eligible: 'bg-red-100 text-red-800',
  needs_clarification: 'bg-amber-100 text-amber-800',
};

export default function EligibilityStatus({
  eligibility,
}: {
  eligibility: Eligibility | undefined;
}) {
  if (!eligibility) {
    return <p className="text-sm text-gray-500">Eligibility not available.</p>;
  }

  return (
    <div>
      <span
        className={`inline-block rounded-full px-3 py-1 text-sm font-medium ${STYLES[eligibility.status]}`}
      >
        {LABELS[eligibility.status]}
      </span>
      {eligibility.reasons.length > 0 && (
        <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-gray-700">
          {eligibility.reasons.map((reason) => (
            <li key={`${reason.field}-${reason.code}`}>{reason.message}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
