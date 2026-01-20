# frozen_string_literal: true

module DaouWebhook
  module IssuePatch
    def self.prepended(base)
      base.class_eval do
        has_many :git_histories, class_name: 'DaouWebhook::GitHistory', dependent: :destroy
      end
    end
  end
end
