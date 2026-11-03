import type { Notice, NoticesResponse, ParsedNotice, Uncertainty, User } from './types';

export const API_BASE =
  import.meta.env.VITE_API_URL || 'http://localhost:3000';

const TOKEN_KEY = 'placementpulse_token';

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string | null): void {
  if (token) {
    localStorage.setItem(TOKEN_KEY, token);
  } else {
    localStorage.removeItem(TOKEN_KEY);
  }
}

export class ApiError extends Error {
  status: number;
  details?: unknown;

  constructor(status: number, message: string, details?: unknown) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = getToken();
  const response = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init.headers || {}),
    },
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message =
      body?.error?.message || `Request failed with status ${response.status}`;
    throw new ApiError(response.status, message, body?.error?.details);
  }
  return body as T;
}

export async function login(
  email: string,
  password: string,
): Promise<{ user: User; token: string; expires_at: string }> {
  const data = await request<{ user: User; token: string; expires_at: string }>(
    '/api/sessions',
    {
      method: 'POST',
      body: JSON.stringify({ user: { email, password } }),
    },
  );
  setToken(data.token);
  return data;
}

export async function logout(): Promise<void> {
  try {
    await request('/api/sessions', { method: 'DELETE' });
  } finally {
    setToken(null);
  }
}

export async function getMe(): Promise<{ user: User }> {
  return request<{ user: User }>('/api/me');
}

export async function updateProfile(
  values: Partial<User>,
): Promise<{ user: User }> {
  return request<{ user: User }>('/api/profile', {
    method: 'PATCH',
    body: JSON.stringify({ user: values }),
  });
}

export async function listNotices(params: {
  eligible_only?: boolean;
  status?: string;
  page?: number;
  per_page?: number;
}): Promise<NoticesResponse> {
  const query = new URLSearchParams();
  if (params.eligible_only !== undefined) {
    query.set('eligible_only', String(params.eligible_only));
  }
  if (params.status) query.set('status', params.status);
  if (params.page) query.set('page', String(params.page));
  if (params.per_page) query.set('per_page', String(params.per_page));
  const suffix = query.toString();
  return request<NoticesResponse>(`/api/notices${suffix ? `?${suffix}` : ''}`);
}

export async function getNotice(id: number): Promise<{ notice: Notice }> {
  return request<{ notice: Notice }>(`/api/notices/${id}`);
}

export async function parseNotice(
  source_text: string,
): Promise<{ parsed: ParsedNotice; uncertainties: Uncertainty[] }> {
  return request<{ parsed: ParsedNotice; uncertainties: Uncertainty[] }>(
    '/api/notices/parse',
    {
      method: 'POST',
      body: JSON.stringify({ notice: { source_text } }),
    },
  );
}

export async function createNotice(
  notice: Record<string, unknown>,
): Promise<{ notice: Notice }> {
  return request<{ notice: Notice }>('/api/notices', {
    method: 'POST',
    body: JSON.stringify({ notice }),
  });
}

export async function updateNotice(
  id: number,
  notice: Record<string, unknown>,
): Promise<{ notice: Notice }> {
  return request<{ notice: Notice }>(`/api/notices/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ notice }),
  });
}

export async function publishNotice(id: number): Promise<{ notice: Notice }> {
  return request<{ notice: Notice }>(`/api/notices/${id}/publish`, {
    method: 'POST',
  });
}

export async function createRegistration(
  noticeId: number,
): Promise<{ registration: { status: string; registered_at: string | null } }> {
  return request(`/api/notices/${noticeId}/registration`, { method: 'POST' });
}

export async function deleteRegistration(
  noticeId: number,
): Promise<{ registration: { status: string; registered_at: string | null } }> {
  return request(`/api/notices/${noticeId}/registration`, { method: 'DELETE' });
}
