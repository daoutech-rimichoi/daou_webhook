# frozen_string_literal: true

class GitWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :check_if_login_required
  before_action :parse_payload

  def receive
    event_key = request.headers['X-Event-Key']
    
    logger.info "Git webhook received: #{event_key}"
    
    service = DaouWebhook::GitWebhookService.new(@payload, self)

    case event_key
    when 'repo:refs_changed'
      service.process_push
    when 'pr:opened'
      service.process_pr('open')
    when 'pr:merged'
      service.process_pr('merged')
    when 'pr:declined'
      service.process_pr('declined')
    when 'pr:deleted'
      service.process_pr('deleted')
    else
      logger.warn "Unsupported event: #{event_key}"
    end

    head :ok
  rescue => e
    logger.error "Webhook error: #{e.message}\n#{e.backtrace.join("\n")}"
    head :unprocessable_entity
  end

  private

  def parse_payload
    @payload = JSON.parse(request.body.read)
  rescue JSON::ParserError => e
    logger.error "Invalid JSON payload: #{e.message}"
    head :bad_request
  end
end
