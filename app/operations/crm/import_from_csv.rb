# frozen_string_literal: true

class Crm::ImportFromCsv < ApplicationOperation
  include Dry::Monads[:result]

  option :actor_account, Types::Instance(Account).optional
  option :file

  COLUMN_ALIASES = {
    full_name: %w[name full_name],
    first_name: %w[first_name first],
    last_name: %w[last_name last surname],
    email: %w[email email_address],
    company: %w[company organization],
    headline: %w[headline title job_title position],
    linkedin: %w[linkedin linkedin_url]
  }.freeze

  def call
    return Failure[:missing_file, "No file provided"] if file.blank?

    content = file.read.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    csv = CSV.parse(
      content,
      headers: true,
      header_converters: ->(h) { h&.strip&.downcase&.gsub(/[\s\-]+/, "_") }
    )

    created = 0
    failed = 0
    errors = []

    csv.each_with_index do |row, index|
      result = import_row(row, index + 2)
      if result.success?
        created += 1
      else
        failed += 1
        errors << result.failure.last.to_s
      end
    end

    Success({ created:, failed:, errors: })
  rescue CSV::MalformedCSVError => e
    Failure[:csv_parse_error, "CSV format error: #{e.message}"]
  end

  private

  def import_row(row, line_number)
    full_name = find_column(row, :full_name)

    if full_name.blank?
      first = find_column(row, :first_name)
      last  = find_column(row, :last_name)
      full_name = [first, last].compact_blank.join(" ").presence
    end

    return Failure[:missing_name, "Row #{line_number}: name is required"] if full_name.blank?

    params = { full_name: }

    email = find_column(row, :email)
    if email.present?
      params[:emails] = [{ address: email, status: "current", source: "manual", type: "personal" }]
    end

    company = find_column(row, :company)
    params[:company] = company if company.present?

    headline = find_column(row, :headline)
    params[:headline] = headline if headline.present?

    linkedin = find_column(row, :linkedin)
    if linkedin.present?
      linkedin = "https://#{linkedin}" unless linkedin.start_with?("http")
      params[:links] = [{ url: linkedin, status: "current" }]
    end

    result = Candidates::Add.new(actor_account:, method: "manual", params:).call

    case result
    in Success(candidate)
      candidate.update_column(:in_crm, true)
      Success(candidate)
    in Failure[_, candidate]
      msg = candidate.is_a?(Candidate) ? candidate.errors.full_messages.join(", ") : candidate.to_s
      Failure[:import_failed, "Row #{line_number}: #{msg}"]
    end
  end

  def find_column(row, key)
    (COLUMN_ALIASES[key] || [key.to_s]).each do |alias_name|
      value = row[alias_name]
      return value.strip if value.present?
    end
    nil
  end
end
