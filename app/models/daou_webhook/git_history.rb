# frozen_string_literal: true

module DaouWebhook
  class GitHistory < ApplicationRecord
    belongs_to :issue, optional: true
    belongs_to :user, optional: true

    validates :notes, presence: true

    scope :recent, -> { order(created_on: :desc) }
  end
end
