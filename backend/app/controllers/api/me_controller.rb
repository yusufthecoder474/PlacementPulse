module Api
  class MeController < ApplicationController
    before_action :authenticate_user!

    # GET /api/me
    def show
      render json: { user: UserSerializer.call(current_user) }, status: :ok
    end
  end
end
