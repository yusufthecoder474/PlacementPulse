require "rails_helper"

RSpec.describe "Api::Notices", type: :request do
  let(:coordinator) { create(:user, :coordinator) }
  let(:student) { create(:user) }
  let!(:published) { create(:notice, :published) }
  let!(:draft) { create(:notice) }

  let(:valid_notice_params) do
    {
      company: "Beta Systems",
      category: "Backend Engineer",
      drive_date: "2027-03-01",
      eligible_branches: %w[CSE IT],
      minimum_cgpa: 7.0,
      minimum_class_x_percentage: 70,
      minimum_class_xii_percentage: 65,
      arrears_rule: "no_standing_arrears",
      ctc: "10 LPA",
      stipend: "₹25,000/month",
      registration_deadline: "2027-02-15T23:59:00+05:30",
      registration_url: "https://example.com/beta-register",
      location: "Hyderabad",
      source_text: "SYNTHETIC test notice."
    }
  end

  describe "GET /api/notices" do
    it "shows students published notices only, even when they ask for drafts" do
      get "/api/notices", params: { status: "draft" }, headers: auth_headers(student)

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["notices"].map { |n| n["id"] }
      expect(ids).to include(published.id)
      expect(ids).not_to include(draft.id)
      expect(response.parsed_body["meta"]["total_count"]).to eq(1)
    end

    it "lets coordinators filter by status" do
      get "/api/notices", params: { status: "draft" }, headers: auth_headers(coordinator)

      ids = response.parsed_body["notices"].map { |n| n["id"] }
      expect(ids).to include(draft.id)
      expect(ids).not_to include(published.id)
    end

    it "filters to eligible-only notices for students" do
      ineligible_student = create(:user, branch: "MECH")
      get "/api/notices", params: { eligible_only: "true" }, headers: auth_headers(ineligible_student)
      expect(response.parsed_body["notices"]).to be_empty

      get "/api/notices", params: { eligible_only: "true" }, headers: auth_headers(student)
      expect(response.parsed_body["notices"].map { |n| n["id"] }).to include(published.id)
    end

    it "caps per_page at 50" do
      get "/api/notices", params: { per_page: 500 }, headers: auth_headers(student)
      expect(response.parsed_body["meta"]["per_page"]).to eq(50)
    end

    it "embeds eligibility and registration for students" do
      get "/api/notices", headers: auth_headers(student)
      notice = response.parsed_body["notices"].find { |n| n["id"] == published.id }
      expect(notice["eligibility"]["status"]).to eq("eligible")
      expect(notice["registration"]["status"]).to eq("not_registered")
    end
  end

  describe "GET /api/notices/:id" do
    it "hides drafts from students (404, not a leak)" do
      get "/api/notices/#{draft.id}", headers: auth_headers(student)
      expect(response).to have_http_status(:not_found)
    end

    it "includes source_text only for coordinators" do
      get "/api/notices/#{published.id}", headers: auth_headers(student)
      expect(response.parsed_body["notice"]).not_to have_key("source_text")

      get "/api/notices/#{published.id}", headers: auth_headers(coordinator)
      expect(response.parsed_body["notice"]["source_text"]).to eq("SYNTHETIC test notice.")
    end
  end

  describe "POST /api/notices/parse" do
    it "parses a well-formatted notice for coordinators" do
      post "/api/notices/parse",
           params: { notice: { source_text: "Company: Acme Technologies\nCategory: SDE\nDrive Date: 10 Feb 2027\nEligible Branches: CSE, ECE\nMinimum CGPA: 7.5\nClass X: 75%\nClass XII: 70%\nNo standing arrears.\nCTC: 12 LPA\nStipend: ₹30,000/month\nRegistration deadline: 20 Jan 2027, 11:59 PM\nRegister at: https://example.com/acme-register\nLocation: Bengaluru" } },
           headers: auth_headers(coordinator), as: :json

      expect(response).to have_http_status(:ok)
      parsed = response.parsed_body["parsed"]
      expect(parsed["company"]).to eq("Acme Technologies")
      expect(parsed["minimum_cgpa"]).to eq(7.5)
      expect(response.parsed_body["uncertainties"]).to be_empty
    end

    it "forbids students from parsing" do
      post "/api/notices/parse", params: { notice: { source_text: "x" } }, headers: auth_headers(student), as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "requires source_text" do
      post "/api/notices/parse", params: { notice: { source_text: "" } }, headers: auth_headers(coordinator), as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/notices and publish" do
    it "creates a draft for coordinators and forbids students" do
      post "/api/notices", params: { notice: valid_notice_params }, headers: auth_headers(coordinator), as: :json
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["notice"]["status"]).to eq("draft")

      post "/api/notices", params: { notice: valid_notice_params }, headers: auth_headers(student), as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "does not let creation smuggle a published status past the checks" do
      post "/api/notices", params: { notice: valid_notice_params.merge(status: "published") },
           headers: auth_headers(coordinator), as: :json
      expect(response.parsed_body["notice"]["status"]).to eq("draft")
    end

    it "fails publication with uncertainties when a required field is missing" do
      notice = create(:notice, minimum_cgpa: nil)
      post "/api/notices/#{notice.id}/publish", headers: auth_headers(coordinator)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["uncertainties"].map { |u| u["field"] }).to include("minimum_cgpa")
      expect(notice.reload.status).to eq("draft")
    end

    it "publishes when the missing field is coordinator-confirmed, and enqueues notifications" do
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      notice = create(:notice, minimum_cgpa: nil, unrestricted_fields: ["minimum_cgpa"])

      post "/api/notices/#{notice.id}/publish", headers: auth_headers(coordinator)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["notice"]["status"]).to eq("published")
      enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.map { |job| job[:job] }
      expect(enqueued).to include(PublishNotificationsJob)
    end

    it "reschedules reminders when a published notice deadline changes" do
      create(:user) # an eligible student, so reminders are actually created
      future = create(:notice, :published, registration_deadline: 5.days.from_now)
      PublishNotificationsJob.perform_now(future.id)
      old_24h = Reminder.find_by!(notice: future, kind: "reminder_24h")

      patch "/api/notices/#{future.id}",
            params: { notice: { registration_deadline: 10.days.from_now.iso8601 } },
            headers: auth_headers(coordinator), as: :json

      expect(response).to have_http_status(:ok)
      expect(Reminder.find_by(id: old_24h.id)).to be_nil
      expect(Reminder.find_by(notice: future, kind: "reminder_24h").scheduled_at)
        .to be_within(1.minute).of(10.days.from_now - 24.hours)
    end
  end

  describe "GET /api/notices/:id/eligibility" do
    it "returns the eligibility decision for a student" do
      get "/api/notices/#{published.id}/eligibility", headers: auth_headers(student)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["eligibility"]["status"]).to eq("eligible")
    end

    it "forbids coordinators" do
      get "/api/notices/#{published.id}/eligibility", headers: auth_headers(coordinator)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
