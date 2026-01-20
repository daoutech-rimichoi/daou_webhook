# frozen_string_literal: true

Redmine::Plugin.register :daou_webhook do
  name 'Daoutech Webhook Plugin'
  author 'rimichoi'
  description 'Git webhook integration for Daoutech Redmine'
  version '0.0.1'
  requires_redmine :version_or_higher => '6.0.0'
  url 'https://github.com/daoutech-rimichoi/daou_webhook'
  author_url 'mailto:rimichoi@daou.co.kr'

  settings default: {
    'git_base_url' => 'https://repo.daou.co.kr'
  }, partial: 'settings/daou_webhook'
end

# Rails 초기화 및 리로드(개발 모드) 시 실행
Rails.configuration.to_prepare do
  # IssuesHelper 패치 (Git History 탭 추가)
  unless IssuesHelper.ancestors.include?(DaouWebhook::IssuesHelperPatch)
    IssuesHelper.prepend(DaouWebhook::IssuesHelperPatch)
  end

  # Issue 모델 패치 (git_histories 관계 추가)
  unless Issue.ancestors.include?(DaouWebhook::IssuePatch)
    Issue.prepend(DaouWebhook::IssuePatch)
  end
end
