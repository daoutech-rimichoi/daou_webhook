# frozen_string_literal: true

module DaouWebhook
  class GitWebhookService
    def initialize(payload, controller)
      @payload = payload
      @controller = controller
    end

    def process_push
      changes = @payload['changes'] || []
      actor = @payload['actor']
      actor_email = actor&.dig('emailAddress')
      actor_name = actor&.dig('displayName') || actor&.dig('name')
      user = find_user_by_email(actor_email)
      
      project_name = @payload.dig('repository', 'project', 'name')
      repo_name = @payload.dig('repository', 'name')
      
      changes.each do |change|
        ref_id = change.dig('ref', 'displayId') || change['refId']
        from_hash = change['fromHash']
        to_hash = change['toHash']
        change_type = change['type']
        
        # Build commit URLs
        from_commit_url = build_commit_url(from_hash)
        to_commit_url = build_commit_url(to_hash)
        
        # Build notes using ERB
        notes = @controller.render_to_string(
          partial: 'git_webhooks/push_note',
          locals: {
            actor_name: actor_name,
            project_name: project_name,
            repo_name: repo_name,
            branch: ref_id,
            from_hash: from_hash,
            to_hash: to_hash,
            from_url: from_commit_url,
            to_url: to_commit_url
          }
        )
        
        # Try to extract issue_id from branch name or commit message
        issue_id = extract_issue_id(ref_id)
        
        git_history = GitHistory.create(
          issue_id: issue_id,
          user_id: user&.id,
          notes: notes,
          created_on: Time.current
        )
        
        if git_history.persisted?
          Rails.logger.info "Created git_history for push: #{change_type} on #{ref_id}" + (issue_id ? " (issue ##{issue_id})" : " (no issue linked)")
        else
          Rails.logger.error "Failed to create git_history for push: #{change_type} on #{ref_id}. Errors: #{git_history.errors.full_messages.join(', ')}"
        end
      end
    end

    def process_pr(status)
      pr = @payload['pullRequest']
      return unless pr

      actor = @payload['actor']
      actor_email = actor&.dig('emailAddress')
      actor_name = actor&.dig('displayName') || actor&.dig('name')
      user = find_user_by_email(actor_email)

      pr_number = pr['id']
      title = pr['title']
      
      source_branch = pr.dig('fromRef', 'displayId')
      target_branch = pr.dig('toRef', 'displayId')
      project_name = pr.dig('fromRef', 'repository', 'project', 'name')
      repo_name = pr.dig('fromRef', 'repository', 'name')
      pr_url = build_pr_url(pr_number)
      
      # Extract issue_id
      issue_id = extract_issue_id(source_branch) || extract_issue_id(title)
      
      # Build notes using ERB
      notes = @controller.render_to_string(
        partial: 'git_webhooks/pr_note',
        locals: {
          status: status,
          actor_name: actor_name,
          project_name: project_name,
          repo_name: repo_name,
          from_branch: source_branch,
          to_branch: target_branch,
          title: title,
          pr_url: pr_url,
          pr_number: pr_number
        }
      )
      
      git_history = GitHistory.create(
        issue_id: issue_id,
        user_id: user&.id,
        notes: notes,
        created_on: Time.current
      )
      
      if git_history.persisted?
        Rails.logger.info "Created git_history for PR: ##{pr_number} (#{status})" + (issue_id ? " linked to issue ##{issue_id}" : " (no issue linked)")
      else
        Rails.logger.error "Failed to create git_history for PR: ##{pr_number} (#{status}). Errors: #{git_history.errors.full_messages.join(', ')}"
      end
    end

    private

    def find_user_by_email(email)
      return nil unless email
      User.find_by_mail(email)
    end

    def extract_issue_id(text)
      return nil unless text
      
      # Pattern 1: issue(s)/task(s) followed by - or -# and number
      # Examples: issue-123, issues-123, task-456, tasks-456, issue-#123, issues-#123, task-#456, tasks-#456
      pattern1 = text.match(/(?:issue|task)s?-#?(\d+)/i)
      return pattern1[1].to_i if pattern1
      
      # Pattern 2: Standalone # followed by number (at word boundary)
      # Examples: #123, #456
      pattern2 = text.match(/(?:^|[^\w#])#(\d+)(?:[^\d]|$)/i)
      return pattern2[1].to_i if pattern2
      
      nil
    end

    def build_commit_url(revision)
      return nil unless revision

      # Try to infer from payload links
      if (repo_url = @payload.dig('repository', 'links', 'self', 0, 'href'))
        base_url = repo_url.sub(/\/browse\/?$/, '')
        return "#{base_url}/commits/#{revision}"
      end

      # Fallback to repo.daou.co.kr
      repo_slug = @payload.dig('repository', 'slug')
      project_key = @payload.dig('repository', 'project', 'key')

      return nil unless project_key && repo_slug

      "https://repo.daou.co.kr/projects/#{project_key}/repos/#{repo_slug}/commits/#{revision}"
    end

    def build_pr_url(pr_number)
      return nil unless pr_number

      # Try to use self link directly
      if (pr_url = @payload.dig('pullRequest', 'links', 'self', 0, 'href'))
        return pr_url
      end

      # Fallback to repo.daou.co.kr
      repo_slug = @payload.dig('pullRequest', 'fromRef', 'repository', 'slug')
      project_key = @payload.dig('pullRequest', 'fromRef', 'repository', 'project', 'key')

      return nil unless project_key && repo_slug

      "https://repo.daou.co.kr/projects/#{project_key}/repos/#{repo_slug}/pull-requests/#{pr_number}/overview"
    end
  end
end
