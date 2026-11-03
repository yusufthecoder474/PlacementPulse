import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import RegistrationButton from './RegistrationButton';

describe('RegistrationButton', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    globalThis.fetch = vi.fn();
  });

  it('calls POST on "I Registered" and then shows Registered', async () => {
    const user = userEvent.setup();
    (globalThis.fetch as ReturnType<typeof vi.fn>).mockResolvedValue({
      ok: true,
      json: async () => ({
        registration: { status: 'registered', registered_at: '2026-11-03T10:00:00Z' },
      }),
    } as Response);

    render(
      <RegistrationButton
        noticeId={7}
        registration={{ status: 'not_registered', registered_at: null }}
      />,
    );

    await user.click(screen.getByRole('button', { name: 'I Registered' }));

    expect(globalThis.fetch).toHaveBeenCalledWith(
      expect.stringContaining('/api/notices/7/registration'),
      expect.objectContaining({ method: 'POST' }),
    );
    expect(screen.getByText(/Registered/)).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: 'Undo registration' }),
    ).toBeInTheDocument();
  });

  it('calls DELETE on undo and then shows Not registered', async () => {
    const user = userEvent.setup();
    (globalThis.fetch as ReturnType<typeof vi.fn>).mockResolvedValue({
      ok: true,
      json: async () => ({
        registration: { status: 'not_registered', registered_at: null },
      }),
    } as Response);

    render(
      <RegistrationButton
        noticeId={7}
        registration={{ status: 'registered', registered_at: '2026-11-03T10:00:00Z' }}
      />,
    );

    await user.click(screen.getByRole('button', { name: 'Undo registration' }));

    expect(globalThis.fetch).toHaveBeenCalledWith(
      expect.stringContaining('/api/notices/7/registration'),
      expect.objectContaining({ method: 'DELETE' }),
    );
    expect(screen.getByText(/Not registered/)).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: 'I Registered' }),
    ).toBeInTheDocument();
  });
});
