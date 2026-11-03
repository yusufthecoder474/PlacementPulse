import { useEffect, useState } from 'react';
import { getMe, getToken, logout, setToken } from './api';
import type { User } from './types';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import ProfilePage from './pages/ProfilePage';
import CoordinatorPage from './pages/CoordinatorPage';

type View = 'dashboard' | 'profile' | 'coordinator';

export default function App() {
  const [user, setUser] = useState<User | null>(null);
  const [view, setView] = useState<View>('dashboard');
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    // Restore a previous session only if a token is stored; the server
    // is the authority on whether that token is still valid.
    if (!getToken()) {
      setChecking(false);
      return;
    }
    getMe()
      .then((data) => setUser(data.user))
      .catch(() => setToken(null))
      .finally(() => setChecking(false));
  }, []);

  async function handleLogout() {
    await logout();
    setUser(null);
    setView('dashboard');
  }

  if (checking) {
    return (
      <main className="mx-auto max-w-4xl px-4 py-8">
        <p role="status" className="text-gray-600">
          Loading…
        </p>
      </main>
    );
  }

  if (!user) {
    return <LoginPage onLoggedIn={setUser} />;
  }

  return (
    <div className="min-h-screen bg-white text-gray-900">
      <header className="border-b">
        <nav
          aria-label="Main navigation"
          className="mx-auto flex max-w-4xl flex-wrap items-center gap-2 px-4 py-3"
        >
          <span className="mr-2 font-bold">PlacementPulse</span>
          <button
            type="button"
            onClick={() => setView('dashboard')}
            aria-current={view === 'dashboard' ? 'page' : undefined}
            className="rounded px-3 py-1 text-sm hover:bg-gray-100"
          >
            Dashboard
          </button>
          <button
            type="button"
            onClick={() => setView('profile')}
            aria-current={view === 'profile' ? 'page' : undefined}
            className="rounded px-3 py-1 text-sm hover:bg-gray-100"
          >
            Profile
          </button>
          {user.role === 'coordinator' && (
            <button
              type="button"
              onClick={() => setView('coordinator')}
              aria-current={view === 'coordinator' ? 'page' : undefined}
              className="rounded px-3 py-1 text-sm hover:bg-gray-100"
            >
              Coordinator
            </button>
          )}
          <span className="ml-auto text-sm text-gray-600">
            {user.email} ({user.role})
          </span>
          <button
            type="button"
            onClick={handleLogout}
            className="rounded border px-3 py-1 text-sm"
          >
            Log out
          </button>
        </nav>
      </header>

      {view === 'dashboard' && <DashboardPage />}
      {view === 'profile' && <ProfilePage user={user} onUpdated={setUser} />}
      {view === 'coordinator' && user.role === 'coordinator' && (
        <CoordinatorPage />
      )}
      {view === 'coordinator' && user.role !== 'coordinator' && (
        <main className="mx-auto max-w-4xl px-4 py-8">
          <p role="alert">Only coordinators can use this screen.</p>
        </main>
      )}
    </div>
  );
}
