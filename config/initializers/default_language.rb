# Set default language from REDMINE_LANG env var if present
if ENV['REDMINE_LANG'].present?
  Rails.application.config.after_initialize do
    Setting['default_language'] = ENV['REDMINE_LANG']
  rescue ActiveRecord::StatementInvalid
    # Table may not exist during initial migration
  end
end
