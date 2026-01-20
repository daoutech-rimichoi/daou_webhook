# frozen_string_literal: true

module DaouWebhook
  module IssuesHelperPatch
    def issue_history_tabs
      tabs = super
      if @issue.respond_to?(:git_histories) && @issue.git_histories.any?
        tabs << {
          :name => 'git_history',
          :label => :label_git_history,
          :partial => 'issues/tabs/git_history',
          :locals => { :git_histories => @issue.git_histories }
        }
      end
      tabs
    end
  end
end
