require "rails_helper"

RSpec.describe "Api::Sessions", type: :request do
  let(:student) { create(:user) }

  it "logs in with valid credentials and returns a token" do
    post "/api/sessions", params: { user: { email: student.email, password: "password1234" } }, as: :json

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["user"]["email"]).to eq(student.email)
    expect(body["user"]["role"]).to eq("student")
    expect(body["token"]).to be_present
    expect(body["expires_at"]).to be_present
  end

  it "returns the same generic 401 for a wrong password and an unknown email" do
    post "/api/sessions", params: { user: { email: student.email, password: "wrong" } }, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["error"]["message"]).to eq("Invalid email or password")

    post "/api/sessions", params: { user: { email: "nobody@example.com", password: "wrong" } }, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["error"]["message"]).to eq("Invalid email or password")
  end

  it "serves /api/me with a valid token and 401 without one" do
    get "/api/me"
    expect(response).to have_http_status(:unauthorized)

    get "/api/me", headers: auth_headers(student)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["user"]["id"]).to eq(student.id)
  end

  it "rejects an expired token" do
    session, token = Session.create_for(student)
    session.update!(expires_at: 1.hour.ago)

    get "/api/me", headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "revokes the session on logout" do
    headers = auth_headers(student)
    delete "/api/sessions", headers: headers
    expect(response).to have_http_status(:ok)

    get "/api/me", headers: headers
    expect(response).to have_http_status(:unauthorized)
  end
end
