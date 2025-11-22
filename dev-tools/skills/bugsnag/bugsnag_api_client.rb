#!/usr/bin/env ruby

require 'bugsnag/api'

class BugsnagApiClient
  def initialize
    @api_key = ENV.fetch('BUGSNAG_DATA_API_KEY')
    @project_id = ENV.fetch('BUGSNAG_PROJECT_ID')

    validate_credentials
    configure_api
  end

  def list_errors(limit: 20, status: nil, severity: nil)
    options = {}
    options[:limit] = limit if limit
    options[:status] = status if status
    options[:severity] = severity if severity

    response = Bugsnag::Api.client.errors(@project_id, nil, options)
    format_errors_list(response)
  rescue Bugsnag::Api::Error => e
    handle_api_error(e, "получении списка ошибок")
  end

  def get_error_details(error_id)
    response = Bugsnag::Api.client.error(@project_id, error_id)
    format_error_details(response)
  rescue Bugsnag::Api::Error => e
    handle_api_error(e, "получении деталей ошибки")
  end

  def resolve_error(error_id)
    # Try to resolve via API first
    begin
      Bugsnag::Api.client.update_errors(@project_id, [error_id], "resolve")
      "✅ Ошибка `#{error_id}` успешно отмечена как выполненная!"
    rescue Bugsnag::Api::Error => e
      # Fallback to adding a resolution comment
      begin
        comment_text = "🔧 **MARKED AS RESOLVED** - Эта ошибка была помечена как выполненная через Bugsnag skill."
        Bugsnag::Api.client.create_comment(@project_id, error_id, comment_text)
        "✅ Ошибка `#{error_id}` помечена как выполненная через комментарий. Пожалуйста, закройте ошибку вручную в Bugsnag dashboard."
      rescue Bugsnag::Api::Error => comment_error
        handle_api_error(comment_error, "пометки ошибки как выполненной")
      end
    end
  end

  def add_comment(error_id, message)
    Bugsnag::Api.client.create_comment(@project_id, error_id, message)
    "✅ Комментарий успешно добавлен к ошибке `#{error_id}`"
  rescue Bugsnag::Api::Error => e
    handle_api_error(e, "добавлении комментария")
  end

  def get_error_events(error_id, limit: 10)
    options = {}
    options[:limit] = limit if limit

    response = Bugsnag::Api.client.error_events(@project_id, error_id, options)
    format_events_list(response)
  rescue Bugsnag::Api::Error => e
    handle_api_error(e, "получении событий ошибки")
  end

  def analyze_errors
    errors = list_errors(limit: 50)
    analyze_error_patterns(errors)
  end

  def list_organizations
    response = Bugsnag::Api.client.organizations
    format_organizations_list(response)
  rescue Bugsnag::Api::Error => e
    handle_api_error(e, "получении списка организаций")
  end

  def list_projects
    response = Bugsnag::Api.client.projects
    format_projects_list(response)
  rescue Bugsnag::Api::Error => e
    handle_api_error(e, "получении списка проектов")
  end

  def list_comments(error_id)
    response = Bugsnag::Api.client.comments(@project_id, error_id)
    format_comments_list(response)
  rescue Bugsnag::Api::Error => e
    handle_api_error(e, "получении комментариев")
  end

  private

  def validate_credentials
    unless @api_key && @project_id
      raise "Missing required environment variables: BUGSNAG_DATA_API_KEY and BUGSNAG_PROJECT_ID"
    end
  end

  def configure_api
    Bugsnag::Api.configure do |config|
      config.auth_token = @api_key
    end
  end

  def handle_api_error(error, operation)
    case error
    when Bugsnag::Api::ClientError
      "❌ Ошибка при #{operation}: ошибка клиента API - #{error.message}"
    when Bugsnag::Api::ServerError
      "❌ Ошибка при #{operation}: ошибка сервера Bugsnag - #{error.message}"
    when Bugsnag::Api::InternalServerError
      "❌ Ошибка при #{operation}: внутренняя ошибка сервера Bugsnag - #{error.message}"
    else
      "❌ Ошибка при #{operation}: #{error.message}"
    end
  end

  def format_errors_list(errors_data)
    errors = errors_data.is_a?(Array) ? errors_data : errors_data['errors'] || []

    output = ["📋 Найдено ошибок: #{errors.length}\n"]

    errors.each do |error|
      status_emoji = case error['status']
                     when 'open' then '❌'
                     when 'resolved' then '✅'
                     when 'ignored' then '🚫'
                     else '❓'
                     end

      output << "#{status_emoji} **#{error['error_class']}** (#{error['events']} событий)"
      output << "   ID: `#{error['id']}`"
      output << "   Severity: #{error['severity']}"
      output << "   Первое появление: #{error['first_seen']}"
      output << "   Последнее: #{error['last_seen']}"
      output << "   URL: #{error['url']}" if error['url']
      output << ""
    end

    output.join("\n")
  end

  def format_error_details(error_data)
    error = error_data['error'] || error_data

    output = []
    output << "🔍 **Детали ошибки:** #{error['error_class']}"
    output << ""
    output << "**Основная информация:**"
    output << "• ID: `#{error['id']}`"
    output << "• Статус: #{error['status']}"
    output << "• Критичность: #{error['severity']}"
    output << "• Событий: #{error['events']}"
    output << "• Пользователи затронуто: #{error['users']}"
    output << ""

    if error['first_seen'] && error['last_seen']
      output << "**Временные рамки:**"
      output << "• Первое появление: #{error['first_seen']}"
      output << "• Последнее: #{error['last_seen']}"
      output << ""
    end

    output << "**Контекст:**"
    output << "• App Version: #{error.dig('app', 'version') || 'N/A'}"
    output << "• Release Stage: #{error.dig('app', 'releaseStage') || 'N/A'}"
    output << "• Language: #{error['language'] || 'N/A'}"
    output << "• Framework: #{error['framework'] || 'N/A'}"
    output << ""

    if error['url']
      output << "**URL:** #{error['url']}"
      output << ""
    end

    if error['message']
      output << "**Сообщение:**"
      output << "```"
      output << error['message']
      output << "```"
      output << ""
    end

    output
  end

  def format_events_list(events_data)
    events = events_data['events'] || []

    output = ["📊 События ошибки (#{events.length}):\n"]

    events.each_with_index do |event, index|
      output << "**Событие #{index + 1}:**"
      output << "• ID: `#{event['id']}`"
      output << "• Время: #{event['receivedAt']}"
      output << "• App Version: #{event['app']['releaseStage'] || 'N/A'}"
      output << "• OS: #{event['device']['osName'] || 'N/A'} #{event['device']['osVersion'] || ''}"

      if event['user']
        output << "• Пользователь: #{event['user']['name'] || event['user']['id'] || 'N/A'}"
      end

      if event['message']
        output << "• Сообщение: #{event['message']}"
      end

      output << ""
    end

    output.join("\n")
  end

  def analyze_error_patterns(errors)
    critical_errors = errors.select { |e| e['severity'] == 'error' && e['status'] == 'open' }
    warnings = errors.select { |e| e['severity'] == 'warning' && e['status'] == 'open' }

    output = ["📈 **Анализ ошибок в проекте:**\n"]

    output << "🔴 **Критичные ошибки (#{critical_errors.length}):**"
    if critical_errors.any?
      critical_errors.first(5).each do |error|
        output << "• #{error['errorClass']} - #{error['eventsCount']} событий (ID: #{error['id']})"
      end
    else
      output << "• Нет критичных ошибок!"
    end
    output << ""

    output << "🟡 **Предупреждения (#{warnings.length}):**"
    if warnings.any?
      warnings.first(5).each do |error|
        output << "• #{error['errorClass']} - #{error['eventsCount']} событий (ID: #{error['id']})"
      end
    else
      output << "• Нет предупреждений!"
    end
    output << ""

    # Частые паттерны ошибок
    error_classes = errors.group_by { |e| e['errorClass'] }
    frequent_errors = error_classes.select { |klass, errs| errs.length > 1 }

    if frequent_errors.any?
      output << "🔄 **Повторяющиеся паттерны:**"
      frequent_errors.each do |error_class, errors|
        total_events = errors.sum { |e| e['eventsCount'] }
        output << "• #{error_class}: #{errors.length} экземпляров, #{total_events} событий"
      end
    end

    output.join("\n")
  end

  def format_organizations_list(orgs_data)
    orgs = orgs_data.is_a?(Array) ? orgs_data : orgs_data['organizations'] || []

    output = ["🏢 Доступные организации: #{orgs.length}\n"]

    orgs.each_with_index do |org, index|
      output << "#{index + 1}. **#{org['name']}** (ID: `#{org['id']}`)"
      output << "   Создана: #{org['created_at']}" if org['created_at']
      output << "   Коллабораторов: #{org['collaborators_count']}" if org['collaborators_count']
      output << "   Проектов: #{org['projects_count']}" if org['projects_count']
      output << "   URL: #{org['url']}" if org['url']
      output << ""
    end

    output.join("\n")
  end

  def format_projects_list(projects_data)
    projects = projects_data.is_a?(Array) ? projects_data : projects_data['projects'] || []

    output = ["📦 Доступные проекты: #{projects.length}\n"]

    projects.each_with_index do |project, index|
      output << "#{index + 1}. **#{project['name']}** (ID: `#{project['id']}`)"
      output << "   Тип: #{project['type']}" if project['type']
      output << "   Открытых ошибок: #{project['open_error_count']}" if project['open_error_count']
      output << "   Коллабораторов: #{project['collaborators_count']}" if project['collaborators_count']

      if project['release_stages'] && project['release_stages'].any?
        output << "   Стадии: #{project['release_stages'].join(', ')}"
      end

      output << "   URL: #{project['url']}" if project['url']
      output << ""
    end

    output.join("\n")
  end

  def format_comments_list(comments_data)
    comments = comments_data.is_a?(Array) ? comments_data : comments_data['comments'] || []

    output = ["💬 Комментарии (#{comments.length}):\n"]

    if comments.empty?
      output << "Нет комментариев для этой ошибки."
      return output.join("\n")
    end

    comments.each_with_index do |comment, index|
      output << "**Комментарий #{index + 1}:**"
      output << "• ID: `#{comment['id']}`"

      # Author info
      author = if comment['user'] && comment['user']['name']
                 comment['user']['name']
               elsif comment['user'] && comment['user']['email']
                 comment['user']['email']
               else
                 'Unknown'
               end
      output << "• Автор: #{author}"

      output << "• Время: #{comment['created_at']}" if comment['created_at']
      output << "• Текст: #{comment['message']}" if comment['message']
      output << ""
    end

    output.join("\n")
  end
end