require "rails_helper"

RSpec.describe "Api::Profiles", type: :request do
  let(:student) { create(:user) }
  let(:other_student) { create(:user) }
  let(:coordinator) { create(:user, :coordinator) }

  it "lets a student update their own profile" do
    patch "/api/profile",
          params: { user: { branch: "ECE", cgpa: 8.5, standing_arrears: true } },
          headers: auth_headers(student), as: :json

    expect(response).to have_http_status(:ok)
    body = response.parsed_body["user"]
    expect(body["branch"]).to eq("ECE")
    expect(body["cgpa"]).to eq(8.5)
    expect(body["standing_arrears"]).to be(true)
    expect(student.reload.branch).to eq("ECE")
  end

  it "does not let a profile update change role or email (strong params)" do
    patch "/api/profile",
          params: { user: { role: "coordinator", email: "hacker@example.com" } },
          headers: auth_headers(student), as: :json

    expect(response).to have_http_status(:ok)
    expect(student.reload.role).to eq("student")
    expect(student.reload.email).not_to eq("hacker@example.com")
  end

  it "rejects invalid profile values" do
    patch "/api/profile",
          params: { user: { cgpa: 11 } },
          headers: auth_headers(student), as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "forbids coordinators from using the student profile endpoint" do
    patch "/api/profile",
          params: { user: { branch: "CSE" } },
          headers: auth_headers(coordinator), as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "requires authentication" do
    patch "/api/profile", params: { user: { branch: "CSE" } }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
