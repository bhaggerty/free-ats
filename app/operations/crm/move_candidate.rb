# frozen_string_literal: true

class Crm::MoveCandidate < ApplicationOperation
  include Dry::Monads[:result]

  option :candidate, Types::Instance(Candidate)
  option :actor_account, Types::Instance(Account).optional
  option :direction, Types::String.enum("add", "remove")

  def call
    in_crm = direction == "add"
    candidate.update!(in_crm:)

    event_type = in_crm ? :candidate_added_to_crm : :candidate_removed_from_crm
    Event.create!(
      type: event_type,
      eventable: candidate,
      actor_account:
    )

    Success(candidate)
  rescue ActiveRecord::RecordInvalid => e
    Failure[:update_failed, e.message]
  end
end
