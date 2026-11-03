export type Role = 'student' | 'coordinator';

export interface User {
  id: number;
  email: string;
  role: Role;
  branch: string | null;
  cgpa: number | null;
  class_x_percentage: number | null;
  class_xii_percentage: number | null;
  standing_arrears: boolean | null;
}

export interface EligibilityReason {
  field: string;
  code: string;
  message: string;
}

export type EligibilityStatus = 'eligible' | 'not_eligible' | 'needs_clarification';

export interface Eligibility {
  status: EligibilityStatus;
  reasons: EligibilityReason[];
}

export interface RegistrationInfo {
  status: 'not_registered' | 'registered';
  registered_at: string | null;
}

export interface Notice {
  id: number;
  company: string | null;
  category: string | null;
  drive_date: string | null;
  eligible_branches: string[] | null;
  minimum_cgpa: number | null;
  minimum_class_x_percentage: number | null;
  minimum_class_xii_percentage: number | null;
  arrears_rule: string | null;
  ctc: string | null;
  stipend: string | null;
  registration_deadline: string | null;
  registration_url: string | null;
  location: string | null;
  status: string;
  source_text?: string | null;
  eligibility?: Eligibility;
  registration?: RegistrationInfo;
}

export interface ParsedNotice {
  company: string | null;
  category: string | null;
  drive_date: string | null;
  eligible_branches: string[] | null;
  minimum_cgpa: number | null;
  minimum_class_x_percentage: number | null;
  minimum_class_xii_percentage: number | null;
  arrears_rule: string | null;
  ctc: string | null;
  stipend: string | null;
  registration_deadline: string | null;
  registration_url: string | null;
  location: string | null;
}

export interface Uncertainty {
  field: string;
  message: string;
}

export interface NoticesResponse {
  notices: Notice[];
  meta: {
    page: number;
    per_page: number;
    total_pages: number;
    total_count: number;
  };
}

export type NoticeForm = ParsedNotice & { source_text: string; status: string };
