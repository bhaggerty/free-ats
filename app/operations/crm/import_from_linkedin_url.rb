# frozen_string_literal: true

class Crm::ImportFromLinkedinUrl < ApplicationOperation
  include Dry::Monads[:result]

  option :actor_account, Types::Instance(Account).optional
  option :url, Types::Strict::String

  def call
    normalized = normalize_url(url.strip)
    return Failure[:invalid_url, "Not a valid LinkedIn profile URL"] unless linkedin_url?(normalized)

    username = extract_username(normalized)
    full_name = format_name(username)
    return Failure[:invalid_url, "Could not extract a name from the LinkedIn URL"] if full_name.blank?

    params = {
      full_name:,
      links: [{ url: normalized, status: "current" }]
    }

    result = Candidates::Add.new(actor_account:, method: "manual", params:).call

    case result
    in Success(candidate)
      candidate.update_column(:in_crm, true)
      Success(candidate)
    in Failure[_, candidate]
      Failure[:candidate_invalid, candidate]
    end
  end

  private

  def normalize_url(raw)
    raw = "https://#{raw}" unless raw.start_with?("http")
    raw.chomp("/")
  end

  def linkedin_url?(url)
    url.match?(%r{linkedin\.com/in/[\w\-]+}i)
  end

  def extract_username(url)
    url.match(%r{linkedin\.com/in/([\w\-]+)}i)&.captures&.first
  end

  def format_name(username)
    return nil if username.blank?

    # "john-smith-a1b2c3" → drop trailing hex-looking segments → "John Smith"
    parts = username.split("-").reject { |p| p.match?(/\A[0-9a-f]{4,}\z/i) && p.length >= 4 }
    parts.map(&:capitalize).join(" ").presence
  end
end
