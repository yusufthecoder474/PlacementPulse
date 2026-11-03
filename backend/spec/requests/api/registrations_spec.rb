require "rails_helper"

RSpec.describe "Api::Registrations", type: :request do
  let(:student) { create(:user) }
  let(:coordinator) { create(:user, :coordinator) }
  let(:notice) { create(:notice, :published) }
  let(:draft) { create(:notice) }

  it "marks a student registered, idempotently" do
    post "/api/notices/#{notice.id}/registration", headers: auth_headers(student)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["registration"]["status"]).to eq("registered")
    expect(response.parsed_body["registration"]["registered_at"]).to be_present

    expect do
      post "/api/notices/#{notice.id}/registration", headers: auth_headers(student)
    end.not_to change(Registration, :count)
    expect(response).to have_http_status(:ok)
  end

  it "unregisters and reports not_registered, idempotently" do
    create(:registration, user: student, notice: notice)
    delete "/api/notices/#{notice.id}/registration", headers: auth_headers(student)
    expect(response.parsed_body["registration"]["status"]).to eq("not_registered")
    expect(Registration.where(user: student, notice: notice)).to be_empty

    delete "/api/notices/#{notice.id}/registration", headers: auth_headers(student)
    expect(response).to have_http_status(:ok)
  end

  it "hides draft notices from registration (404)" do
    post "/api/notices/#{draft.id}/registration", headers: auth_headers(student)
    expect(response).to have_http_status(:not_found)
  end

  it "forbids coordinators from registering" do
    post "/api/notices/#{notice.id}/registration", headers: auth_headers(coordinator)
    expect(response).to have_http_status(:forbidden)
  end
end
