class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable

  attr_reader :current_user, :current_session

  private

  # Bearer-token authentication against the hashed Session table.
  # Every failure returns the same generic message so a caller cannot tell
  # whether an email exists, a token exists, or a token merely expired.
  def authenticate_user!
    token = request.headers["Authorization"]&.sub(/\ABearer /i, "")
    session = Session.authenticate(token)
    return render_error("Authentication required", :unauthorized) if session.nil?

    @current_session = session
    @current_user = session.user
  end

  def require_coordinator!
    render_error("Forbidden", :forbidden) unless current_user&.coordinator?
  end

  def require_student!
    render_error("Forbidden", :forbidden) unless current_user&.student?
  end

  # Pagination: per_page is capped at 50 by contract.
  def pagination_params
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = params[:per_page].to_i
    per_page = 20 if per_page < 1
    per_page = 50 if per_page > 50
    [page, per_page]
  end

  def paginate_relation(relation)
    page, per_page = pagination_params
    total_count = relation.count
    records = relation.offset((page - 1) * per_page).limit(per_page)
    [records, { page: page, per_page: per_page,
                total_pages: (total_count.to_f / per_page).ceil,
                total_count: total_count }]
  end

  def render_error(message, status)
    render json: { error: { message: message } }, status: status
  end

  def render_not_found
    render_error("Not found", :not_found)
  end

  def render_unprocessable(exception)
    render_error(exception.record.errors.full_messages.join(", "), :unprocessable_entity)
  end
end
