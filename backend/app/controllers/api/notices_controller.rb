module Api
  class NoticesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_coordinator!, only: %i[parse create update publish]

    # GET /api/notices?eligible_only=&status=&page=&per_page=
    # Students see published notices only; a status param from a student is
    # ignored rather than honoured, so drafts can never leak to students.
    def index
      scope = current_user.student? ? Notice.published : Notice.all
      scope = scope.where(status: params[:status]) if current_user.coordinator? && %w[draft published].include?(params[:status])
      scope = scope.order(Arel.sql("registration_deadline ASC NULLS LAST, id ASC"))

      if current_user.student? && params[:eligible_only] == "true"
        # Eligibility is computed in Ruby (it is a service, not a SQL
        # predicate), so filtering happens before pagination to keep the
        # meta counts honest.
        eligible = scope.select do |notice|
          EligibilityChecker.call(user: current_user, notice: notice)[:status] == "eligible"
        end
        page, per_page = pagination_params
        total_count = eligible.size
        paged = eligible.slice((page - 1) * per_page, per_page) || []
        meta = { page: page, per_page: per_page,
                 total_pages: (total_count.to_f / per_page).ceil,
                 total_count: total_count }
        render json: { notices: paged.map { |n| NoticeSerializer.call(n, current_user: current_user) }, meta: meta }
      else
        records, meta = paginate_relation(scope)
        render json: {
          notices: records.map { |n| NoticeSerializer.call(n, current_user: current_user) },
          meta: meta
        }
      end
    end

    # GET /api/notices/:id — source_text only for coordinators.
    def show
      notice = find_visible_notice
      return if notice.nil?

      render json: { notice: NoticeSerializer.call(notice, current_user: current_user,
                                                   include_source: current_user.coordinator?) }
    end

    # POST /api/notices/parse { notice: { source_text } } — coordinators only.
    def parse
      source_text = params.dig(:notice, :source_text).to_s
      return render_error("source_text is required", :unprocessable_entity) if source_text.blank?

      result = NoticeParser.call(source_text)
      render json: { parsed: serialize_parsed(result[:parsed]), uncertainties: result[:uncertainties] }
    end

    # POST /api/notices — always created as a draft. Publication is a
    # separate, checked step (see #publish), so a client cannot smuggle
    # status: "published" past the uncertainty rules.
    def create
      notice = Notice.new(notice_params)
      notice.publisher = current_user
      notice.status = "draft"
      notice.uncertainties = notice.publish_blocking_uncertainties
      if notice.save
        render json: { notice: NoticeSerializer.call(notice, current_user: current_user, include_source: true) },
               status: :created
      else
        render_error(notice.errors.full_messages.join(", "), :unprocessable_entity)
      end
    end

    # PATCH /api/notices/:id — coordinators only.
    def update
      notice = Notice.find(params[:id])
      deadline_changed = begin
        notice_params[:registration_deadline].present? &&
          Time.zone.parse(notice_params[:registration_deadline].to_s) != notice.registration_deadline
      rescue ArgumentError, TypeError
        false
      end
      if notice.update(notice_params)
        notice.update_column(:uncertainties, notice.publish_blocking_uncertainties) if notice.draft?
        # A published notice whose deadline moved must not keep reminding
        # students about the old deadline.
        ReminderScheduler.reschedule_for_notice(notice) if notice.published? && deadline_changed
        render json: { notice: NoticeSerializer.call(notice, current_user: current_user, include_source: true) }
      else
        render_error(notice.errors.full_messages.join(", "), :unprocessable_entity)
      end
    end

    # POST /api/notices/:id/publish — coordinators only.
    # Fails with 422 + the blocking uncertainties when any required field
    # is missing and not coordinator-confirmed as unrestricted.
    def publish
      notice = Notice.find(params[:id])
      blocking = notice.publish_blocking_uncertainties
      unless blocking.empty?
        return render json: { error: { message: "Notice has unconfirmed fields and cannot be published." },
                              uncertainties: blocking }, status: :unprocessable_entity
      end

      notice.update!(status: "published", uncertainties: [])
      PublishNotificationsJob.perform_later(notice.id)
      render json: { notice: NoticeSerializer.call(notice, current_user: current_user, include_source: true) }
    end

    # GET /api/notices/:id/eligibility — students only (coordinators: 403).
    def eligibility
      return render_error("Forbidden", :forbidden) unless current_user.student?

      notice = Notice.published.find_by(id: params[:id])
      return render_not_found if notice.nil?

      render json: { eligibility: EligibilityChecker.call(user: current_user, notice: notice) }
    end

    private

    def find_visible_notice
      notice = if current_user.student?
                 Notice.published.find_by(id: params[:id])
               else
                 Notice.find_by(id: params[:id])
               end
      render_not_found if notice.nil?
      notice
    end

    def notice_params
      params.require(:notice).permit(
        :company, :category, :drive_date, :minimum_cgpa,
        :minimum_class_x_percentage, :minimum_class_xii_percentage,
        :arrears_rule, :ctc, :stipend, :registration_deadline,
        :registration_url, :location, :source_text,
        eligible_branches: [], unrestricted_fields: []
      )
    end

    def serialize_parsed(parsed)
      parsed.merge(
        drive_date: parsed[:drive_date]&.to_s,
        registration_deadline: parsed[:registration_deadline]&.iso8601
      )
    end
  end
end
