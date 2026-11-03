module Api
  class ProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_student!

    # PATCH /api/profile — students only, and only their own profile, since
    # the profile being updated is always the authenticated user's.
    def update
      if current_user.update(profile_params)
        render json: { user: UserSerializer.call(current_user) }, status: :ok
      else
        render_error(current_user.errors.full_messages.join(", "), :unprocessable_entity)
      end
    end

    private

    def profile_params
      params.require(:user).permit(:branch, :cgpa, :class_x_percentage,
                                   :class_xii_percentage, :standing_arrears)
    end
  end
end
