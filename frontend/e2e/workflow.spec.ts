import { expect, test } from '@playwright/test';

// SYNTHETIC notice, invented for this test only. "Acme Robotics" is not a
// real company and this is not a real placement notice. Do not use this
// test for any real-world parser-accuracy claim.
const SYNTHETIC_NOTICE = `Acme Robotics is hiring for Software Development Engineer.
Category: Software Development Engineer
Eligible branches: CSE, ECE
Minimum CGPA: 7.5
Minimum Class X percentage: 75%
Minimum Class XII percentage: 70%
No standing arrears.
CTC: 12 LPA
Stipend: 30000/month
Drive date: 2027-03-15
Registration deadline: 2027-02-20 23:59
Registration URL: https://example.com/register
Location: Bengaluru`;

async function signIn(page: import('@playwright/test').Page, email: string) {
  await page.goto('/');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Password').fill('password1234');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByRole('heading', { name: 'Published opportunities' })).toBeVisible();
}

test('coordinator publishes a notice, student checks eligibility and registers', async ({
  browser,
}) => {
  // --- Coordinator flow (first browser context) ---
  const coordinatorContext = await browser.newContext();
  const coordinatorPage = await coordinatorContext.newPage();
  await signIn(coordinatorPage, 'coordinator@example.com');

  await coordinatorPage.getByRole('button', { name: 'Coordinator' }).click();
  await expect(
    coordinatorPage.getByRole('heading', { name: 'Coordinator: review a notice' }),
  ).toBeVisible();

  await coordinatorPage.getByLabel('Notice text').fill(SYNTHETIC_NOTICE);
  await coordinatorPage.getByRole('button', { name: 'Parse' }).click();
  // The deterministic parser must surface the invented company name.
  await expect(coordinatorPage.getByLabel('Company')).toHaveValue('Acme Robotics');
  await expect(coordinatorPage.getByLabel('Minimum CGPA')).toHaveValue('7.5');

  await coordinatorPage.getByRole('button', { name: 'Save as draft' }).click();
  await expect(coordinatorPage.getByText('Draft saved.')).toBeVisible();

  await coordinatorPage.getByRole('button', { name: 'Publish' }).click();
  await expect(coordinatorPage.getByText('Notice published.')).toBeVisible();
  await coordinatorContext.close();

  // --- Student flow (fresh browser context, so no coordinator token leaks) ---
  const studentContext = await browser.newContext();
  const studentPage = await studentContext.newPage();
  await signIn(studentPage, 'student@example.com');

  // Set the profile through the UI so eligibility is computed from it.
  await studentPage.getByRole('button', { name: 'Profile' }).click();
  await studentPage.getByLabel('Branch').fill('CSE');
  await studentPage.getByLabel('CGPA (0–10)').fill('8.2');
  await studentPage.getByLabel('Class X percentage (0–100)').fill('88');
  await studentPage.getByLabel('Class XII percentage (0–100)').fill('85');
  await studentPage.getByLabel('Standing arrears').selectOption('false');
  await studentPage.getByRole('button', { name: 'Save profile' }).click();
  await expect(studentPage.getByText('Profile saved.')).toBeVisible();

  await studentPage.getByRole('button', { name: 'Dashboard' }).click();
  const notice = studentPage.locator('li', { hasText: 'Acme Robotics' }).first();
  await expect(notice).toBeVisible();
  // Seeded student profile (CSE, 8.2, 88/85, no arrears) clears the
  // synthetic thresholds (CSE, 7.5, 75/70, no standing arrears).
  await expect(notice.getByText('Eligible', { exact: true })).toBeVisible();

  // Check the registration link target without navigating to the external URL.
  const registrationLink = notice.getByRole('link', { name: 'Open registration page' });
  await expect(registrationLink).toHaveAttribute('href', 'https://example.com/register');

  await notice.getByRole('button', { name: 'I Registered' }).click();
  await expect(notice.getByText('Registration status: Registered')).toBeVisible();
  await studentContext.close();
});
