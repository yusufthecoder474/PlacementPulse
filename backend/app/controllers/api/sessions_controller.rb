module Api
  class SessionsController < ApplicationController
    before_action :authenticate_user!, only: [:destroy]

    # POST /api/sessions { user: { email, password } }
    # Returns the plaintext token exactly once; later requests send it as
    # `Authorization: Bearer <token>` and the server compares digests.
    def create
      email = params.dig(:user, :email).to_s.strip.downcase
      password = params.dig(:user, :password).to_s
      user = User.find_by("LOWER(email) = ?", email)

      # One generic message for unknown email and wrong password alike:
      # distinguishing them would let anyone enumerate registered emails.
      return render_error("Invalid email or password", :unauthorized) unless user&.authenticate(password)

      session, token = Session.create_for(user)
      render json: {
        user: UserSerializer.call(user),
        token: token,
        expires_at: session.expires_at.iso8601
      }, status: :ok
    end

    # DELETE /api/sessions — revokes the caller's current session.
    def destroy
      current_session&.destroy
      render json: { message: "Signed out" }, status: :ok
    end
  end
end
