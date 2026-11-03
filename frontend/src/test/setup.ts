import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

// Vitest does not enable globals by default here, so Testing Library's
// automatic cleanup does not run on its own. Without this, a component
// rendered in one test stays mounted and can match queries in the next.
afterEach(() => {
  cleanup();
});
