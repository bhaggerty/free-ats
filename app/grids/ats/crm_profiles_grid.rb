# frozen_string_literal: true

class ATS::CrmProfilesGrid
  include Datagrid

  SELECTED_FIELDS =
    <<~SQL.squish
      candidates.blacklisted,
      candidates.company,
      candidates.created_at,
      candidates.headline,
      candidates.id,
      candidates.in_crm,
      candidates.last_activity_at,
      candidates.full_name,
      candidates.resume_text
    SQL

  #
  # Scope
  #

  scope do
    Candidate
      .not_merged
      .crm
      .with_attached_avatar
      .select(SELECTED_FIELDS)
  end

  self.batch_size = 500

  attr_accessor :page

  #
  # Filters
  #

  filter(
    :query,
    :string,
    header: "Search",
    placeholder: "Name, email, company, or resume content"
  ) do |query|
    search_crm(query).select(SELECTED_FIELDS)
  end

  #
  # Columns
  #

  column(:avatar_image, html: true, order: false, header: "") do |model|
    link_to(tab_ats_candidate_path(model.id, :info)) do
      picture_avatar_icon model.avatar
    end
  end

  column(:name, html: true) do |model|
    link_to(model.full_name, tab_ats_candidate_path(model.id, :info))
  end

  column(:company, order: false)

  column(:headline, order: false) do |model|
    model.headline.presence
  end

  column(
    :resume,
    header: "Resume",
    html: true,
    order: false
  ) do |model|
    if model.resume_text.present?
      tag.span("✓", class: "badge bg-success", title: "Has parsed resume")
    end
  end

  column(
    :added,
    order: "candidates.id DESC",
    order_desc: "candidates.id"
  ) do |model|
    added_date = model.created_at
    format(added_date.to_fs(:datetime_full)) do |value|
      tag.span(data: { bs_toggle: "tooltip", placement: "top" }, title: value) do
        I18n.t("core.created_time", time: short_time_ago_in_words(added_date))
      end
    end
  end

  column(
    :last_activity,
    html: true,
    order: "candidates.last_activity_at DESC",
    order_desc: "candidates.last_activity_at"
  ) do |model|
    tag.span(data: { bs_toggle: "tooltip", placement: "top" },
             title: model.last_activity_at.to_fs(:datetime_full)) do
      I18n.t("core.last_activity", time: short_time_ago_in_words(model.last_activity_at))
    end
  end
end
