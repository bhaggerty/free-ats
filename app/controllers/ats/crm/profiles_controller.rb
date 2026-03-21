# frozen_string_literal: true

class ATS::Crm::ProfilesController < AuthorizedController
  include Dry::Monads[:result]

  layout "ats/application"

  before_action { @nav_item = :crm }
  before_action :set_candidate, only: %i[move_to_crm remove_from_crm]
  before_action -> { authorize! with: ATS::CandidatePolicy }, only: %i[index]
  before_action -> { authorize!(@candidate, with: ATS::CandidatePolicy) },
                only: %i[move_to_crm remove_from_crm]

  def index
    @profiles_grid = ATS::CrmProfilesGrid.new(
      helpers.add_default_sorting(
        params.fetch(:ats_crm_profiles_grid, {}).merge(page: params[:page]),
        :last_activity
      )
    ) do |scope|
      scope.page(params[:page])
    end

    @profiles_count = @profiles_grid.assets.unscope(:offset, :order, :limit).size
  end

  def move_to_crm
    result = Crm::MoveCandidate.new(
      candidate: @candidate,
      actor_account: current_account,
      direction: "add"
    ).call

    case result
    in Success(candidate)
      redirect_to tab_ats_candidate_path(candidate, :info),
                  notice: "#{candidate.full_name} has been added to CRM."
    in Failure
      redirect_back fallback_location: ats_candidates_path,
                    alert: "Could not add candidate to CRM."
    end
  end

  def remove_from_crm
    result = Crm::MoveCandidate.new(
      candidate: @candidate,
      actor_account: current_account,
      direction: "remove"
    ).call

    case result
    in Success(candidate)
      redirect_to ats_crm_profiles_path,
                  notice: "#{candidate.full_name} has been removed from CRM."
    in Failure
      redirect_back fallback_location: ats_crm_profiles_path,
                    alert: "Could not remove candidate from CRM."
    end
  end

  private

  def set_candidate
    id = params[:candidate_id] || params[:id]
    @candidate = Candidate.find(id)
  end
end
