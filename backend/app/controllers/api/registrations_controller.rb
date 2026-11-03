module Api
  class RegistrationsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_student!

    # POST /api/notices/:id/registration — idempotent. An existing
    # registration returns 200 with the same row; the unique
    # (user_id, notice_id) index makes a duplicate impossible even under
    # concurrent requests (the race is rescued to a find below).
    def create
      notice = Notice.published.find_by(id: params[:notice_id] || params[:id])
      return render_not_found if notice.nil?

      registration = find_or_create_registration(notice)
      render json: { registration: NoticeSerializer.registration_json(registration) }, status: :ok
    end

    # DELETE /api/notices/:id/registration — idempotent: deleting a
    # registration that does not exist still returns not_registered.
    def destroy
      notice = Notice.published.find_by(id: params[:notice_id] || params[:id])
      return render_not_found if notice.nil?

      Registration.find_by(user: current_user, notice: notice)&.destroy
      render json: { registration: { status: "not_registered", registered_at: nil } }, status: :ok
    end

    private

    def find_or_create_registration(notice)
      Registration.where(user: current_user, notice: notice).first_or_create do |registration|
        registration.status = "registered"
        registration.registered_at = Time.current
      end
    rescue ActiveRecord::RecordNotUnique
      Registration.find_by!(user: current_user, notice: notice)
    end
  end
end
