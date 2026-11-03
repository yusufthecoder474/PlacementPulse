import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import EligibilityStatus from './EligibilityStatus';
import type { Eligibility } from '../types';

describe('EligibilityStatus', () => {
  it('renders eligible without reasons', () => {
    const eligibility: Eligibility = { status: 'eligible', reasons: [] };
    render(<EligibilityStatus eligibility={eligibility} />);
    expect(screen.getByText('Eligible')).toBeInTheDocument();
  });

  it('renders not_eligible with the exact reason messages', () => {
    const eligibility: Eligibility = {
      status: 'not_eligible',
      reasons: [
        { field: 'cgpa', code: 'cgpa_below_minimum', message: 'CGPA below requirement' },
        { field: 'branch', code: 'branch_not_included', message: 'Branch not included' },
      ],
    };
    render(<EligibilityStatus eligibility={eligibility} />);
    expect(screen.getByText('Not eligible')).toBeInTheDocument();
    expect(screen.getByText('CGPA below requirement')).toBeInTheDocument();
    expect(screen.getByText('Branch not included')).toBeInTheDocument();
  });

  it('renders needs_clarification with the exact reason message', () => {
    const eligibility: Eligibility = {
      status: 'needs_clarification',
      reasons: [
        {
          field: 'minimum_cgpa',
          code: 'unconfirmed_requirement',
          message: 'Unconfirmed eligibility rule',
        },
      ],
    };
    render(<EligibilityStatus eligibility={eligibility} />);
    expect(screen.getByText('Needs clarification')).toBeInTheDocument();
    expect(screen.getByText('Unconfirmed eligibility rule')).toBeInTheDocument();
  });

  it('renders a fallback when eligibility is missing', () => {
    render(<EligibilityStatus eligibility={undefined} />);
    expect(screen.getByText('Eligibility not available.')).toBeInTheDocument();
  });
});
