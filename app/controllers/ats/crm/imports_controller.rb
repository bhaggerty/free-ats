# frozen_string_literal: true

class ATS::Crm::ImportsController < AuthorizedController
  include Dry::Monads[:result]

  layout "ats/application"

  before_action { @nav_item = :crm }
  before_action -> { authorize! with: ATS::CandidatePolicy }

  def new; end

  def create
    case params[:import_type]
    when "csv"
      handle_csv_import
    when "linkedin"
      handle_linkedin_import
    when "file"
      handle_file_import
    else
      redirect_to new_ats_crm_import_path, alert: "Unknown import type."
    end
  end

  private

  def handle_csv_import
    file = params[:file]

    unless file.present? && file.respond_to?(:original_filename)
      return redirect_to new_ats_crm_import_path, alert: "Please select a CSV file."
    end

    result = Crm::ImportFromCsv.new(actor_account: current_account, file:).call

    case result
    in Success({ created:, failed:, errors: })
      msg = "Imported #{created} #{"profile".pluralize(created)}."
      msg += " #{failed} rows failed." if failed.positive?
      redirect_to ats_crm_profiles_path, notice: msg
    in Failure[_, message]
      redirect_to new_ats_crm_import_path, alert: message.to_s
    end
  end

  def handle_linkedin_import
    raw_urls = params[:linkedin_urls].to_s.split("\n").map(&:strip).reject(&:blank?)

    if raw_urls.empty?
      return redirect_to new_ats_crm_import_path, alert: "Please enter at least one LinkedIn URL."
    end

    created = 0
    failed = 0
    error_messages = []

    raw_urls.each do |url|
      result = Crm::ImportFromLinkedinUrl.new(actor_account: current_account, url:).call
      case result
      in Success
        created += 1
      in Failure[_, message]
        failed += 1
        error_messages << "#{url}: #{message}"
      end
    end

    msg = "Imported #{created} #{"profile".pluralize(created)} from LinkedIn."
    msg += " #{failed} failed." if failed.positive?
    redirect_to ats_crm_profiles_path, notice: msg
  end

  def handle_file_import
    file = params[:file]

    unless file.present? && file.respond_to?(:original_filename)
      return redirect_to new_ats_crm_import_path, alert: "Please select a resume file."
    end

    result = Crm::ParseResume.new(actor_account: current_account, file:).call

    case result
    in Success(candidate)
      redirect_to tab_ats_candidate_path(candidate, :info),
                  notice: "Resume imported as #{candidate.full_name}. Please review and update the profile."
    in Failure[_, message]
      msg = message.is_a?(Candidate) ? "Could not parse resume — name not found. Please add manually." : message.to_s
      redirect_to new_ats_crm_import_path, alert: msg
    end
  end
end
