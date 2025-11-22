#!/usr/bin/env ruby

require_relative 'bugsnag_helper'

class BugsnagCLI
  def initialize
    @helper = BugsnagHelper.new
  rescue StandardError => e
    puts "❌ Ошибка инициализации: #{e.message}"
    puts ""
    puts "Убедитесь что установлены переменные окружения:"
    puts "export BUGSNAG_DATA_API_KEY='your_api_key'"
    puts "export BUGSNAG_PROJECT_ID='your_project_id'"
    exit 1
  end

  def run(args = [])
    if args.empty?
      puts show_help
      return
    end

    command = args[0].downcase
    case command
    when 'list', 'errors', 'show', 'показать', 'список'
      list_errors(args[1..-1])
    when 'open', 'открыть', 'opened', 'открытые'
      show_open_errors(args[1..-1])
    when 'details', 'error', 'детали'
      show_error_details(args[1])
    when 'resolve', 'close', 'resolve-error', 'отметить', 'решить'
      resolve_error(args[1])
    when 'events', 'события'
      show_events(args[1], args[2])
    when 'analyze', 'analysis', 'анализ', 'проанализировать'
      analyze_errors
    when 'help', 'помощь', 'h'
      puts show_help
    else
      puts "❌ Неизвестная команда: #{command}"
      puts show_help
    end
  rescue StandardError => e
    puts "❌ Ошибка выполнения: #{e.message}"
  end

  private

  def list_errors(options = [])
    limit = extract_option('--limit', options) || 20
    status = extract_option('--status', options)
    severity = extract_option('--severity', options)

    puts "📋 Получение списка ошибок..."
    puts ""
    result = @helper.list_errors(limit: limit.to_i, status: status, severity: severity)
    puts result
  end

  def show_open_errors(options = [])
    limit = extract_option('--limit', options) || 20
    severity = extract_option('--severity', options)

    puts "📋 Получение списка **открытых** ошибок..."
    puts ""
    result = @helper.list_errors(limit: limit.to_i, status: 'open', severity: severity)
    puts result
  end

  def show_error_details(error_id)
    unless error_id
      puts "❌ Укажите ID ошибки"
      puts "Пример: bugsnag-lookuper details 5f8a9b2c"
      return
    end

    puts "🔍 Получение деталей ошибки #{error_id}..."
    puts ""
    result = @helper.get_error_details(error_id)
    puts result

    # Также покажем последние события
    puts ""
    puts "📊 **Последние события:**"
    events_result = @helper.get_error_events(error_id, 3)
    puts events_result
  end

  def resolve_error(error_id)
    unless error_id
      puts "❌ Укажите ID ошибки для пометки как выполненной"
      puts "Пример: bugsnag-lookuper resolve 5f8a9b2c"
      return
    end

    puts "🔄 Пометка ошибки #{error_id} как выполненной..."
    result = @helper.resolve_error(error_id)
    puts result
  end

  def show_events(error_id, limit = nil)
    unless error_id
      puts "❌ Укажите ID ошибки"
      puts "Пример: bugsnag-lookuper events 5f8a9b2c 5"
      return
    end

    event_limit = limit&.to_i || 10
    puts "📊 Получение событий ошибки #{error_id} (лимит: #{event_limit})..."
    puts ""
    result = @helper.get_error_events(error_id, event_limit)
    puts result
  end

  def analyze_errors
    puts "📈 Анализ ошибок в проекте..."
    puts ""
    result = @helper.analyze_errors
    puts result
  end

  def show_help
    <<~HELP
      🚀 **Bugsnag** - Инструмент для работы с Bugsnag API

      **Использование:**
      `skill: "bugsnag" "<команда> [аргументы]"`

      **Команды:**

      📋 **Просмотр ошибок:**
      • `list` / `show` / `показать` - Список всех ошибок
      • `open` / `открыть` / `открытые` - Только **открытые** ошибки
      • `list --limit 50` - Показать до 50 ошибок
      • `list --status open` - Только открытые ошибки
      • `list --severity error` - Только ошибки (не предупреждения)

      🔍 **Детали ошибки:**
      • `details <error_id>` / `детали <id>` - Полная информация об ошибке
      • Пример: `details 5f8a9b2c`

      ✅ **Управление статусами:**
      • `resolve <error_id>` / `resolve-error <id>` / `отметить <id>` - Отметить как выполненную
      • Пример: `resolve 5f8a9b2c`

      📊 **События ошибки:**
      • `events <error_id> [limit]` / `события <id> [лимит]` - Показать события
      • Пример: `events 5f8a9b2c 5`

      📈 **Анализ:**
      • `analyze` / `analysis` / `анализ` - Анализ паттернов ошибок

      ❓ **Справка:**
      • `help` / `помощь` / `h` - Показать эту справку

      **Настройка:**
      Экспортируйте переменные окружения:
      ```bash
      export BUGSNAG_DATA_API_KEY="your_api_key"
      export BUGSNAG_PROJECT_ID="your_project_id"
      ```

    HELP
  end

  def extract_option(option_name, options)
    index = options.find_index { |opt| opt.start_with?(option_name) }
    return nil unless index

    option = options[index]
    value = nil

    if option.include?('=')
      value = option.split('=', 2)[1]
      options.delete_at(index)
    elsif options[index + 1] && !options[index + 1].start_with?('--')
      value = options.delete_at(index + 1)
      options.delete_at(index)
    else
      options.delete_at(index)
    end

    value
  end
end

# Handle execution through MCP or direct CLI
cli = BugsnagCLI.new
cli.run(ARGV)