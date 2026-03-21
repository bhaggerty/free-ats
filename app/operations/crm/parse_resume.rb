# frozen_string_literal: true

class Crm::ParseResume < ApplicationOperation
  include Dry::Monads[:result]

  option :actor_account, Types::Instance(Account).optional
  option :file

  EMAIL_REGEX = /\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b/i
  LINKEDIN_REGEX = %r{https?://(?:www\.)?linkedin\.com/in/[\w\-]+/?}i

  def call
    return Failure[:missing_file, "No file provided"] if file.blank?

    text = extract_text(file)
    return Failure[:extraction_failed, "Could not extract text from file"] if text.blank?

    params = build_params(text)
    return Failure[:no_name, "Could not identify a name in the resume"] if params[:full_name].blank?

    result = Candidates::Add.new(actor_account:, method: "manual", params:).call

    case result
    in Success(candidate)
      candidate.update_columns(in_crm: true, resume_text: text)
      candidate.files.attach(file)
      Success(candidate)
    in Failure[_, candidate]
      Failure[:candidate_invalid, candidate]
    end
  end

  private

  def extract_text(uploaded_file)
    ext = File.extname(uploaded_file.original_filename).downcase

    case ext
    when ".pdf"
      extract_pdf_text(uploaded_file)
    when ".docx"
      extract_docx_text(uploaded_file)
    else
      uploaded_file.read.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    end
  rescue StandardError => e
    Rails.logger.warn("Crm::ParseResume: text extraction failed — #{e.message}")
    nil
  end

  def extract_pdf_text(uploaded_file)
    reader = PDF::Reader.new(uploaded_file.path || StringIO.new(uploaded_file.read))
    reader.pages.map(&:text).join("\n")
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
    Rails.logger.warn("Crm::ParseResume: PDF read error — #{e.message}")
    nil
  end

  def extract_docx_text(uploaded_file)
    unless defined?(Docx)
      Rails.logger.warn("Crm::ParseResume: docx gem not installed, skipping DOCX extraction")
      return nil
    end

    doc = Docx::Document.open(uploaded_file.path)
    doc.paragraphs.map(&:to_s).join("\n")
  rescue StandardError => e
    Rails.logger.warn("Crm::ParseResume: DOCX read error — #{e.message}")
    nil
  end

  def build_params(text)
    lines = text.split("\n").map(&:strip).reject(&:blank?)
    params = {}

    # Name heuristic: first short line with 2-5 words, all alpha/spaces, no digits
    name_line = lines.find do |line|
      words = line.split
      words.size.between?(2, 5) &&
        line.length <= 60 &&
        line !~ EMAIL_REGEX &&
        line !~ /\A\+?\d/ &&
        line =~ /\A[[:alpha:]]/
    end
    params[:full_name] = name_line if name_line.present?

    email_match = text.match(EMAIL_REGEX)
    if email_match
      params[:emails] = [{
        address: email_match[0].downcase,
        status: "current",
        source: "manual",
        type: "personal"
      }]
    end

    linkedin_match = text.match(LINKEDIN_REGEX)
    if linkedin_match
      params[:links] = [{ url: linkedin_match[0].chomp("/"), status: "current" }]
    end

    params
  end
end
