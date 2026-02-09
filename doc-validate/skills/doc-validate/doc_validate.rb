#!/usr/bin/env ruby
# frozen_string_literal: true

# doc_validate.rb — Утилита для валидации документации
# Часть doc-validate skill для Claude Code

require 'json'
require 'yaml'
require 'pathname'
require 'fileutils'
require 'time'

class DocValidator
  VERSION = '1.1.0'

  # Режимы работы
  MODE_INTERACTIVE = :interactive
  MODE_BATCH = :batch
  MODE_DEFAULT = :default

  # Цвета для консоли
  COLORS = {
    red: "\e[31m",
    green: "\e[32m",
    yellow: "\e[33m",
    blue: "\e[34m",
    magenta: "\e[35m",
    cyan: "\e[36m",
    bold: "\e[1m",
    reset: "\e[0m"
  }.freeze

  # Приоритеты проблем
  PRIORITY = {
    critical: { symbol: '🔴', label: 'CRITICAL' },
    warning: { symbol: '🟡', label: 'WARNING' },
    info: { symbol: '🟢', label: 'INFO' }
  }.freeze

  def initialize(project_root = Dir.pwd, mode: MODE_DEFAULT)
    @project_root = Pathname.new(project_root).expand_path
    @config = load_config
    @issues = []
    @stats = { critical: 0, warning: 0, info: 0 }
    @mode = mode
    @skipped = []
    @fixed = []
    @ignored = []
    @file_cache = {}  # Кэш содержимого файлов для производительности
  end

  # === LINT COMMAND ===

  def lint(options = {})
    puts "#{COLORS[:bold]}🔍 /doc:lint — Проверка форматирования#{COLORS[:reset]}\n\n"

    files = find_markdown_files
    puts "Сканирование #{files.size} файлов...\n\n"

    files.each do |file|
      check_broken_links(file)
      check_naming_conventions(file)
      check_empty_sections(file)
      check_todo_fixme(file)
      check_required_sections(file)
    end

    print_summary('lint')
    save_history('lint')

    @issues
  end

  # === TERMS COMMAND ===

  def terms(options = {})
    puts "#{COLORS[:bold]}📖 /doc:terms — Проверка терминологии#{COLORS[:reset]}\n\n"

    glossary = load_glossary
    if glossary.empty?
      puts "#{COLORS[:yellow]}⚠️ Глоссарий не найден или пуст#{COLORS[:reset]}\n"
      return { glossary: [], issues: [] }
    end

    puts "📚 Загружен глоссарий: #{glossary.size} терминов"
    puts "🚫 Запрещённых синонимов: #{forbidden_synonyms.size} групп\n\n"

    files = find_markdown_files
    glossary_file = @config.dig('glossary', 'file') || '02_GLOSSARY.md'
    files = files.reject { |f| f == glossary_file }

    puts "Сканирование #{files.size} файлов...\n\n"

    term_usage = Hash.new { |h, k| h[k] = [] }
    new_terms = []

    files.each do |file|
      content = read_file(file)
      next unless content

      # Проверить запрещённые синонимы
      check_forbidden_synonyms(file, content)

      # Собрать использование терминов
      glossary.each do |term|
        if content.downcase.include?(term.downcase)
          term_usage[term] << file
        end
      end

      # Найти потенциально новые термины (слова в **bold**)
      content.scan(/\*\*([^*]+)\*\*/).flatten.each do |bold_term|
        next if bold_term.length < 3
        next if glossary.any? { |t| t.downcase == bold_term.downcase }
        next if new_terms.any? { |t| t[:term].downcase == bold_term.downcase }

        new_terms << { term: bold_term, file: file }
      end
    end

    # Отчёт по покрытию глоссария
    used_terms = term_usage.keys
    unused_terms = glossary - used_terms
    coverage = ((used_terms.size.to_f / glossary.size) * 100).round

    puts "📊 Покрытие глоссария"
    puts "━" * 50
    puts "  Используется: #{used_terms.size}/#{glossary.size} терминов (#{coverage}%)"

    if unused_terms.any?
      puts "\n#{COLORS[:yellow]}⚠️ Неиспользуемые термины:#{COLORS[:reset]}"
      unused_terms.first(10).each { |t| puts "  - #{t}" }
      puts "  ... и ещё #{unused_terms.size - 10}" if unused_terms.size > 10
    end

    if new_terms.any?
      puts "\n#{COLORS[:cyan]}🆕 Потенциально новые термины (не в глоссарии):#{COLORS[:reset]}"
      new_terms.first(10).each do |nt|
        puts "  - \"#{nt[:term]}\" (#{nt[:file]})"
        add_issue('TERM', nt[:file], 0,
                 "Новый термин не в глоссарии: \"#{nt[:term]}\"",
                 :info,
                 { fix_type: 'new_term', term: nt[:term] })
      end
    end

    puts

    print_summary('terms')
    save_history('terms')

    {
      glossary_size: glossary.size,
      coverage: coverage,
      unused_terms: unused_terms,
      new_terms: new_terms,
      issues: @issues
    }
  end

  # === VIEWPOINTS COMMAND ===

  def viewpoints(options = {})
    puts "#{COLORS[:bold]}📐 /doc:viewpoints — Проверка артефактов по viewpoints#{COLORS[:reset]}\n\n"

    viewpoints_config = @config.dig('modeling_standards', 'viewpoints') || default_viewpoints
    results = {}

    puts "## Покрытие Viewpoints\n\n"
    puts "| Viewpoint | Артефакт | Статус | Файл |"
    puts "|-----------|----------|--------|------|"

    viewpoints_config.each do |viewpoint_name, viewpoint_config|
      results[viewpoint_name] = { artifacts: [], covered: 0, total: 0 }

      artifacts = viewpoint_config['artifacts'] || []
      artifacts.each do |artifact|
        file_path = artifact['file'] || artifact
        file_path = file_path.is_a?(Hash) ? file_path['file'] : file_path
        next unless file_path

        priority = artifact.is_a?(Hash) ? (artifact['priority'] || 'should') : 'should'
        exists = (@project_root / file_path).exist?

        results[viewpoint_name][:total] += 1
        results[viewpoint_name][:covered] += 1 if exists

        status = exists ? '✅' : '❌'
        vp_display = viewpoint_name.to_s.gsub('_viewpoint', '').capitalize

        puts "| #{vp_display} | #{File.basename(file_path, '.md')} | #{status} | `#{file_path}` |"

        unless exists
          priority_level = priority == 'must' ? :critical : :warning
          add_issue('VIEWPOINT', file_path, 0,
                   "Отсутствует обязательный артефакт: #{file_path}",
                   priority_level,
                   { fix_type: 'missing_artifact', viewpoint: viewpoint_name, priority: priority })
        else
          # Проверить содержимое артефакта
          check_artifact_content(file_path, viewpoint_name)
        end

        results[viewpoint_name][:artifacts] << {
          file: file_path,
          exists: exists,
          priority: priority
        }
      end
    end

    # Итоговая статистика
    total_artifacts = results.values.sum { |v| v[:total] }
    covered_artifacts = results.values.sum { |v| v[:covered] }
    overall_coverage = total_artifacts > 0 ? ((covered_artifacts.to_f / total_artifacts) * 100).round : 0

    puts "\n"
    puts "📊 Общее покрытие viewpoints: #{covered_artifacts}/#{total_artifacts} (#{overall_coverage}%)"

    # Предупреждения для критичных viewpoints
    security_vp = results['security_viewpoint']
    if security_vp && security_vp[:covered] < security_vp[:total]
      puts "\n#{COLORS[:red]}🔴 Security viewpoint не полностью покрыт — критично для крипто-системы!#{COLORS[:reset]}"
    end

    puts

    print_summary('viewpoints')
    save_history('viewpoints')

    {
      viewpoints: results,
      total: total_artifacts,
      covered: covered_artifacts,
      coverage: overall_coverage
    }
  end

  # === CONTRADICTIONS COMMAND ===

  def contradictions(options = {})
    puts "#{COLORS[:bold]}⚡ /doc:contradictions — Поиск противоречий#{COLORS[:reset]}\n\n"

    files = find_markdown_files
    puts "Сканирование #{files.size} файлов...\n\n"

    # Извлечь все числовые параметры с контекстом
    parameters = extract_parameters(files)

    puts "📊 Найдено параметров: #{parameters.size}\n\n"

    # Найти конфликты
    conflicts = find_parameter_conflicts(parameters)

    if conflicts.any?
      puts "#{COLORS[:red]}🔴 Обнаружены противоречия:#{COLORS[:reset]}\n\n"

      conflicts.each do |conflict|
        puts "━" * 50
        puts "#{COLORS[:red]}⚡ CONTRADICTION#{COLORS[:reset]}: #{conflict[:parameter]}"
        puts "━" * 50
        puts

        conflict[:occurrences].each do |occ|
          puts "📄 #{occ[:file]}:#{occ[:line]}"
          puts "   > #{occ[:context].strip[0..80]}"
          puts "   Значение: #{COLORS[:bold]}#{occ[:value]}#{COLORS[:reset]}"
          puts
        end

        add_issue('CONTRADICTION', conflict[:occurrences].first[:file],
                 conflict[:occurrences].first[:line],
                 "Противоречие: #{conflict[:parameter]} имеет разные значения: #{conflict[:values].join(' vs ')}",
                 :critical,
                 { fix_type: 'contradiction', parameter: conflict[:parameter], values: conflict[:values] })
      end
    else
      puts "#{COLORS[:green]}✅ Явных противоречий в числовых параметрах не обнаружено#{COLORS[:reset]}\n"
    end

    # Найти потенциальные логические противоречия
    logical_conflicts = find_logical_conflicts(files)

    if logical_conflicts.any?
      puts "\n#{COLORS[:yellow]}⚠️ Потенциальные логические противоречия:#{COLORS[:reset]}\n\n"

      logical_conflicts.each do |lc|
        puts "━" * 50
        puts "#{COLORS[:yellow]}⚠️ Возможное противоречие#{COLORS[:reset]}"
        puts "━" * 50
        puts "📄 #{lc[:file1]}:#{lc[:line1]}"
        puts "   > #{lc[:text1][0..80]}"
        puts "📄 #{lc[:file2]}:#{lc[:line2]}"
        puts "   > #{lc[:text2][0..80]}"
        puts

        add_issue('CONTRADICTION', lc[:file1], lc[:line1],
                 "Потенциальное противоречие с #{lc[:file2]}:#{lc[:line2]}",
                 :warning,
                 { fix_type: 'logical_conflict' })
      end
    end

    puts

    print_summary('contradictions')
    save_history('contradictions')

    {
      parameter_conflicts: conflicts,
      logical_conflicts: logical_conflicts,
      total_parameters: parameters.size
    }
  end

  # === REVIEW COMMAND (ORCHESTRATION) ===

  def review(options = {})
    start_time = Time.now
    puts "#{COLORS[:bold]}📋 /doc:review — Полный аудит документации#{COLORS[:reset]}\n\n"
    puts "Запуск всех проверок в оптимальном порядке...\n\n"

    # Сохранить начальное состояние для агрегации
    all_results = {}
    total_stats = { critical: 0, warning: 0, info: 0 }

    # Получить предыдущий запуск для сравнения
    previous_run = load_previous_review

    # === PHASE 1: Базовые проверки (lint + links) ===
    puts "#{COLORS[:cyan]}━━━ Phase 1: Базовые проверки ━━━#{COLORS[:reset]}\n\n"

    # Reset для новой команды
    reset_state
    all_results[:lint] = lint(options.merge(quiet: true))
    lint_stats = @stats.dup

    reset_state
    all_results[:links] = links(options.merge(quiet: true))
    links_stats = @stats.dup

    total_stats[:critical] += lint_stats[:critical] + links_stats[:critical]
    total_stats[:warning] += lint_stats[:warning] + links_stats[:warning]
    total_stats[:info] += lint_stats[:info] + links_stats[:info]

    # === PHASE 2: Семантические проверки (terms + viewpoints) ===
    puts "\n#{COLORS[:cyan]}━━━ Phase 2: Семантические проверки ━━━#{COLORS[:reset]}\n\n"

    reset_state
    all_results[:terms] = terms(options.merge(quiet: true))
    terms_stats = @stats.dup

    reset_state
    all_results[:viewpoints] = viewpoints(options.merge(quiet: true))
    viewpoints_stats = @stats.dup

    total_stats[:critical] += terms_stats[:critical] + viewpoints_stats[:critical]
    total_stats[:warning] += terms_stats[:warning] + viewpoints_stats[:warning]
    total_stats[:info] += terms_stats[:info] + viewpoints_stats[:info]

    # === PHASE 3: Глубокий анализ (contradictions + gaps) ===
    puts "\n#{COLORS[:cyan]}━━━ Phase 3: Глубокий анализ ━━━#{COLORS[:reset]}\n\n"

    reset_state
    all_results[:contradictions] = contradictions(options.merge(quiet: true))
    contradictions_stats = @stats.dup

    reset_state
    all_results[:gaps] = gaps(options.merge(quiet: true))
    gaps_stats = @stats.dup

    total_stats[:critical] += contradictions_stats[:critical] + gaps_stats[:critical]
    total_stats[:warning] += contradictions_stats[:warning] + gaps_stats[:warning]
    total_stats[:info] += gaps_stats[:info] + contradictions_stats[:info]

    # === ИТОГОВЫЙ ОТЧЁТ ===
    elapsed_time = (Time.now - start_time).round(1)

    puts "\n"
    puts "#{COLORS[:bold]}╔══════════════════════════════════════════════════════════════╗#{COLORS[:reset]}"
    puts "#{COLORS[:bold]}║               📋 ИТОГОВЫЙ ОТЧЁТ DOC:REVIEW                   ║#{COLORS[:reset]}"
    puts "#{COLORS[:bold]}╚══════════════════════════════════════════════════════════════╝#{COLORS[:reset]}"
    puts

    # Таблица результатов по командам
    puts "┌────────────────┬──────────┬──────────┬──────────┐"
    puts "│ Команда        │ 🔴 Крит. │ 🟡 Важн. │ 🟢 Инфо  │"
    puts "├────────────────┼──────────┼──────────┼──────────┤"
    puts "│ lint           │ #{lint_stats[:critical].to_s.rjust(8)} │ #{lint_stats[:warning].to_s.rjust(8)} │ #{lint_stats[:info].to_s.rjust(8)} │"
    puts "│ links          │ #{links_stats[:critical].to_s.rjust(8)} │ #{links_stats[:warning].to_s.rjust(8)} │ #{links_stats[:info].to_s.rjust(8)} │"
    puts "│ terms          │ #{terms_stats[:critical].to_s.rjust(8)} │ #{terms_stats[:warning].to_s.rjust(8)} │ #{terms_stats[:info].to_s.rjust(8)} │"
    puts "│ viewpoints     │ #{viewpoints_stats[:critical].to_s.rjust(8)} │ #{viewpoints_stats[:warning].to_s.rjust(8)} │ #{viewpoints_stats[:info].to_s.rjust(8)} │"
    puts "│ contradictions │ #{contradictions_stats[:critical].to_s.rjust(8)} │ #{contradictions_stats[:warning].to_s.rjust(8)} │ #{contradictions_stats[:info].to_s.rjust(8)} │"
    puts "│ gaps           │ #{gaps_stats[:critical].to_s.rjust(8)} │ #{gaps_stats[:warning].to_s.rjust(8)} │ #{gaps_stats[:info].to_s.rjust(8)} │"
    puts "├────────────────┼──────────┼──────────┼──────────┤"
    puts "│ #{COLORS[:bold]}ИТОГО#{COLORS[:reset]}          │ #{COLORS[:bold]}#{total_stats[:critical].to_s.rjust(8)}#{COLORS[:reset]} │ #{COLORS[:bold]}#{total_stats[:warning].to_s.rjust(8)}#{COLORS[:reset]} │ #{COLORS[:bold]}#{total_stats[:info].to_s.rjust(8)}#{COLORS[:reset]} │"
    puts "└────────────────┴──────────┴──────────┴──────────┘"
    puts

    # Сравнение с предыдущим запуском
    if previous_run
      puts "📈 Сравнение с предыдущим запуском (#{previous_run['timestamp'][0..9]}):"
      puts

      prev_total = previous_run['metrics']
      diff_critical = total_stats[:critical] - (prev_total['critical'] || 0)
      diff_warning = total_stats[:warning] - (prev_total['warning'] || 0)
      diff_info = total_stats[:info] - (prev_total['info'] || 0)

      puts "  🔴 Критические: #{format_diff(diff_critical)}"
      puts "  🟡 Важные:      #{format_diff(diff_warning)}"
      puts "  🟢 Информация:  #{format_diff(diff_info)}"
      puts
    end

    # Покрытие viewpoints
    if all_results[:viewpoints]
      vp = all_results[:viewpoints]
      puts "📐 Покрытие viewpoints: #{vp[:covered]}/#{vp[:total]} (#{vp[:coverage]}%)"
    end

    # Покрытие глоссария
    if all_results[:terms] && all_results[:terms][:coverage]
      puts "📚 Покрытие глоссария: #{all_results[:terms][:coverage]}%"
    end

    puts
    puts "⏱️  Время выполнения: #{elapsed_time} сек"
    puts

    # Рекомендации
    print_recommendations(total_stats, all_results)

    # Общая оценка
    overall_score = calculate_score(total_stats)
    print_overall_score(overall_score)

    # Сохранить в историю
    @stats = total_stats
    save_history('review')

    {
      commands: {
        lint: lint_stats,
        links: links_stats,
        terms: terms_stats,
        viewpoints: viewpoints_stats,
        contradictions: contradictions_stats,
        gaps: gaps_stats
      },
      total: total_stats,
      elapsed_time: elapsed_time,
      score: overall_score,
      results: all_results
    }
  end

  # === GAPS COMMAND ===

  def gaps(options = {})
    puts "#{COLORS[:bold]}🕳️ /doc:gaps — Анализ полноты покрытия#{COLORS[:reset]}\n\n"

    files = find_markdown_files
    puts "Сканирование #{files.size} файлов...\n\n"

    gaps_found = []

    # 1. Упомянутые но не раскрытые темы
    puts "#{COLORS[:cyan]}📝 Проверка раскрытия тем...#{COLORS[:reset]}"
    mentioned_topics = find_mentioned_but_not_explained(files)
    gaps_found.concat(mentioned_topics)

    # 2. Требования без acceptance criteria
    puts "#{COLORS[:cyan]}📋 Проверка acceptance criteria...#{COLORS[:reset]}"
    missing_ac = find_requirements_without_ac(files)
    gaps_found.concat(missing_ac)

    # 3. Сущности без связанных артефактов
    puts "#{COLORS[:cyan]}📐 Проверка артефактов моделирования...#{COLORS[:reset]}"
    missing_artifacts = find_entities_without_artifacts(files)
    gaps_found.concat(missing_artifacts)

    # 4. Интеграции без описания
    puts "#{COLORS[:cyan]}🔌 Проверка описания интеграций...#{COLORS[:reset]}"
    missing_integrations = find_incomplete_integrations(files)
    gaps_found.concat(missing_integrations)

    puts "\n"

    if gaps_found.any?
      puts "#{COLORS[:red]}🕳️ Обнаружены пробелы в документации:#{COLORS[:reset]}\n\n"

      # Группировать по категории
      by_category = gaps_found.group_by { |g| g[:category] }

      by_category.each do |category, items|
        puts "#{COLORS[:bold]}### #{category}#{COLORS[:reset]} (#{items.size})\n\n"

        items.first(5).each do |gap|
          priority = gap[:priority] || :warning
          p = PRIORITY[priority]

          puts "#{p[:symbol]} #{gap[:file]}#{gap[:line] > 0 ? ":#{gap[:line]}" : ''}"
          puts "   #{gap[:message]}"
          puts

          add_issue('GAP', gap[:file], gap[:line], gap[:message], priority,
                   { fix_type: 'gap', category: category })
        end

        puts "   ... и ещё #{items.size - 5}" if items.size > 5
        puts
      end
    else
      puts "#{COLORS[:green]}✅ Критических пробелов не обнаружено#{COLORS[:reset]}\n"
    end

    print_summary('gaps')
    save_history('gaps')

    {
      gaps: gaps_found,
      by_category: gaps_found.group_by { |g| g[:category] }.transform_values(&:size)
    }
  end

  # === LINKS COMMAND ===

  def links(options = {})
    puts "#{COLORS[:bold]}🔗 /doc:links — Граф связей документации#{COLORS[:reset]}\n\n"

    files = find_markdown_files
    graph = build_link_graph(files)

    puts "📊 Граф документации"
    puts "━" * 50
    puts "Всего документов: #{files.size}"
    puts "Связей: #{graph[:links].size}\n\n"

    # Найти orphans
    orphans = find_orphans(graph, files)
    if orphans.any?
      puts "#{COLORS[:yellow]}⚠️ Orphans (нет входящих ссылок):#{COLORS[:reset]}"
      orphans.each do |orphan|
        puts "  - #{orphan}"
        add_issue('LINK', orphan, 0, 'Документ без входящих ссылок (orphan)', :info)
      end
      puts
    end

    # Найти dead-ends
    dead_ends = find_dead_ends(graph, files)
    if dead_ends.any?
      puts "#{COLORS[:yellow]}⚠️ Dead-ends (нет исходящих ссылок):#{COLORS[:reset]}"
      dead_ends.each do |dead_end|
        puts "  - #{dead_end}"
        add_issue('LINK', dead_end, 0, 'Документ без исходящих ссылок (dead-end)', :info)
      end
      puts
    end

    # Проверить навигацию в README
    readme_coverage = check_readme_navigation(files)
    puts "✅ README навигация: #{readme_coverage[:covered]}/#{readme_coverage[:total]} документов (#{readme_coverage[:percent]}%)\n\n"

    # Генерация Mermaid графа
    mermaid_file = nil
    if options[:mermaid]
      puts "#{COLORS[:cyan]}📊 Генерация Mermaid графа...#{COLORS[:reset]}"
      mermaid_content = generate_mermaid_graph(graph, orphans, dead_ends)
      mermaid_file = save_mermaid_graph(mermaid_content)
      puts "#{COLORS[:green]}✅ Граф сохранён: #{mermaid_file}#{COLORS[:reset]}\n\n"
    end

    print_summary('links')
    save_history('links')

    { graph: graph, orphans: orphans, dead_ends: dead_ends, readme: readme_coverage, mermaid_file: mermaid_file }
  end

  private

  # === CONFIG ===

  def load_config
    config_path = @project_root / '.docvalidate.yml'
    if config_path.exist?
      YAML.load_file(config_path)
    else
      default_config
    end
  rescue => e
    warn "Ошибка загрузки конфигурации: #{e.message}"
    default_config
  end

  def default_config
    {
      'version' => 1,
      'glossary' => { 'file' => '02_GLOSSARY.md' },
      'scope' => {
        'strict' => ['*.md', 'architecture/**/*.md', 'decisions/**/*.md'],
        'ignore' => ['claudedocs/**', '*.draft.md']
      },
      'link_exceptions' => {
        'not_orphans' => ['README.md', 'CHANGELOG.md', '**/GLOSSARY.md'],
        'not_dead_ends' => ['**/GLOSSARY.md', '**/INDEX.md']
      },
      'formatting' => {
        'root_naming' => '^[0-9]{2}_[A-Z_]+\.md$'
      }
    }
  end

  # === FILE OPERATIONS ===

  def find_markdown_files
    patterns = (@config.dig('scope', 'strict') || ['**/*.md'])
    ignore_patterns = (@config.dig('scope', 'ignore') || [])

    files = patterns.flat_map do |pattern|
      Dir.glob(@project_root / pattern)
    end.uniq

    # Фильтрация игнорируемых
    files.reject do |file|
      rel_path = Pathname.new(file).relative_path_from(@project_root).to_s
      ignore_patterns.any? { |p| File.fnmatch(p, rel_path, File::FNM_PATHNAME) }
    end.map { |f| Pathname.new(f).relative_path_from(@project_root).to_s }
  end

  def read_file(relative_path, use_cache: true)
    # Используем кэш для повторных чтений
    return @file_cache[relative_path] if use_cache && @file_cache.key?(relative_path)

    path = @project_root / relative_path
    return nil unless path.exist?

    content = File.read(path, encoding: 'utf-8')
    @file_cache[relative_path] = content if use_cache
    content
  rescue => e
    warn "Ошибка чтения #{relative_path}: #{e.message}"
    nil
  end

  def clear_file_cache
    @file_cache.clear
  end

  def invalidate_cache(relative_path)
    @file_cache.delete(relative_path)
  end

  # === GLOSSARY & TERMS ===

  def load_glossary
    glossary_file = @config.dig('glossary', 'file') || '02_GLOSSARY.md'
    content = read_file(glossary_file)
    return [] unless content

    terms = []
    # Парсим markdown таблицу: | **Term** | Definition |
    content.each_line do |line|
      next if line.include?('---') || line.strip.empty?

      # Ищем строки таблицы с терминами в **bold**
      if (match = line.match(/\|\s*\*\*([^*]+)\*\*\s*\|/))
        terms << match[1].strip
      # Или обычные строки таблицы
      elsif (match = line.match(/\|\s*([^|*]+)\s*\|.*\|/))
        term = match[1].strip
        # Пропускаем заголовки
        next if term.downcase == 'термин' || term.downcase == 'term'
        terms << term unless term.empty?
      end
    end

    terms.uniq
  end

  def forbidden_synonyms
    @config.dig('glossary', 'forbidden_synonyms') || []
  end

  def check_forbidden_synonyms(file, content)
    forbidden_synonyms.each do |synonym_group|
      next unless synonym_group.is_a?(Array) && synonym_group.size > 1

      canonical = synonym_group.first
      forbidden = synonym_group[1..-1]

      content.each_line.with_index(1) do |line, line_num|
        forbidden.each do |synonym|
          # Ищем синоним как отдельное слово (с учётом границ слов)
          if line.match?(/\b#{Regexp.escape(synonym)}\b/i)
            add_issue('TERM', file, line_num,
                     "Запрещённый синоним: \"#{synonym}\" → используйте \"#{canonical}\"",
                     :warning,
                     { fix_type: 'synonym', synonym: synonym, canonical: canonical })
          end
        end
      end
    end
  end

  # === VIEWPOINTS CHECKS ===

  def default_viewpoints
    {
      'data_viewpoint' => {
        'artifacts' => [
          { 'file' => 'architecture/STATE_MACHINES.md', 'priority' => 'must' },
          { 'file' => 'architecture/DATA_FLOWS.md', 'priority' => 'should' }
        ]
      },
      'business_rules_viewpoint' => {
        'artifacts' => [
          { 'file' => 'architecture/BUSINESS_RULES.md', 'priority' => 'must' }
        ]
      },
      'security_viewpoint' => {
        'artifacts' => [
          { 'file' => 'architecture/THREAT_MODEL.md', 'priority' => 'must' }
        ]
      },
      'integration_viewpoint' => {
        'artifacts' => [
          { 'file' => 'architecture/EVENT_CATALOG.md', 'priority' => 'should' }
        ]
      },
      'traceability_viewpoint' => {
        'artifacts' => [
          { 'file' => 'architecture/RTM.md', 'priority' => 'should' }
        ]
      }
    }
  end

  def check_artifact_content(file_path, viewpoint_name)
    content = read_file(file_path)
    return unless content

    case viewpoint_name.to_s
    when 'data_viewpoint'
      # Проверить наличие state diagram
      unless content.include?('stateDiagram') || content.include?('State Diagram')
        add_issue('VIEWPOINT', file_path, 0,
                 "Артефакт не содержит State Diagram (ожидается mermaid stateDiagram)",
                 :info)
      end

    when 'security_viewpoint'
      # Проверить наличие STRIDE или Trust Boundary
      unless content.match?(/STRIDE|Trust.*Bound|Threat.*Model/i)
        add_issue('VIEWPOINT', file_path, 0,
                 "Security артефакт не содержит STRIDE анализ или Trust Boundaries",
                 :warning)
      end

    when 'business_rules_viewpoint'
      # Проверить наличие Decision Table
      unless content.include?('Decision Table') || content.match?(/\|.*\|.*\|.*Результат/i)
        add_issue('VIEWPOINT', file_path, 0,
                 "Артефакт не содержит Decision Tables",
                 :info)
      end
    end
  end

  # === CONTRADICTIONS HELPERS ===

  def extract_parameters(files)
    parameters = []

    # Паттерны для числовых параметров
    patterns = [
      # Проценты: "до 10%", "не более 5%", "минимум 80%"
      /(?:до|не более|минимум|максимум|около)?\s*(\d+(?:[.,]\d+)?)\s*%/i,
      # Суммы: "$100", "100 USD", "1000 руб"
      /\$?\s*(\d+(?:[.,]\d+)?)\s*(?:USD|EUR|RUB|руб|долл)?/i,
      # Временные: "30 секунд", "5 минут", "24 часа"
      /(\d+)\s*(?:секунд|минут|часов|дней|сек|мин)/i,
      # Количества: "N подтверждений", "M частей"
      /(\d+)\s*(?:подтвержд|частей|попыт|раз)/i,
    ]

    files.each do |file|
      content = read_file(file)
      next unless content

      content.each_line.with_index(1) do |line, line_num|
        patterns.each do |pattern|
          line.scan(pattern).each do |match|
            value = match.is_a?(Array) ? match.first : match
            next unless value

            # Извлечь контекст (ключевые слова вокруг числа)
            context_match = line.match(/(\S+\s+){0,5}#{Regexp.escape(value)}(\s+\S+){0,5}/)
            context = context_match ? context_match[0] : line

            # Определить параметр по контексту
            param_name = identify_parameter(line, value)
            next unless param_name

            parameters << {
              parameter: param_name,
              value: value,
              file: file,
              line: line_num,
              context: context
            }
          end
        end
      end
    end

    parameters
  end

  def identify_parameter(line, value)
    # Ключевые слова для идентификации параметров
    keywords = {
      'горячий кошелёк' => 'hot_wallet_limit',
      'hot wallet' => 'hot_wallet_limit',
      'холодный' => 'cold_wallet',
      'подтвержд' => 'confirmations',
      'confirm' => 'confirmations',
      'таймаут' => 'timeout',
      'timeout' => 'timeout',
      'лимит' => 'limit',
      'limit' => 'limit',
      'retry' => 'retry_count',
      'попыт' => 'retry_count',
      'RTO' => 'rto',
      'RPO' => 'rpo',
    }

    line_lower = line.downcase
    keywords.each do |keyword, param_name|
      return param_name if line_lower.include?(keyword.downcase)
    end

    nil
  end

  def find_parameter_conflicts(parameters)
    conflicts = []

    # Группировать по имени параметра
    by_param = parameters.group_by { |p| p[:parameter] }

    by_param.each do |param_name, occurrences|
      values = occurrences.map { |o| o[:value] }.uniq

      if values.size > 1
        conflicts << {
          parameter: param_name,
          values: values,
          occurrences: occurrences
        }
      end
    end

    conflicts
  end

  def find_logical_conflicts(files)
    conflicts = []

    # Ключевые слова для противоположных утверждений
    opposites = [
      ['обязательно', 'необязательно'],
      ['должен', 'не должен'],
      ['всегда', 'никогда'],
      ['разрешено', 'запрещено'],
      ['включен', 'отключен'],
      ['да', 'нет'],
    ]

    # Собрать утверждения с ключевыми словами
    statements = []
    files.each do |file|
      content = read_file(file)
      next unless content

      content.each_line.with_index(1) do |line, line_num|
        opposites.flatten.each do |keyword|
          if line.downcase.include?(keyword)
            statements << {
              file: file,
              line: line_num,
              text: line.strip,
              keyword: keyword
            }
          end
        end
      end
    end

    # Найти потенциальные конфликты (упрощённый алгоритм)
    # В реальности это должен делать AI
    opposites.each do |pair|
      word1, word2 = pair
      stmts1 = statements.select { |s| s[:keyword] == word1 }
      stmts2 = statements.select { |s| s[:keyword] == word2 }

      stmts1.each do |s1|
        stmts2.each do |s2|
          # Пропустить если в одном файле рядом (вероятно контекст)
          next if s1[:file] == s2[:file] && (s1[:line] - s2[:line]).abs < 10

          # Проверить похожий контекст (общие слова)
          words1 = s1[:text].downcase.split(/\W+/)
          words2 = s2[:text].downcase.split(/\W+/)
          common = (words1 & words2) - ['и', 'или', 'в', 'на', 'для', 'с', 'по', 'the', 'a', 'an']

          if common.size >= 2
            conflicts << {
              file1: s1[:file],
              line1: s1[:line],
              text1: s1[:text],
              file2: s2[:file],
              line2: s2[:line],
              text2: s2[:text]
            }
          end
        end
      end
    end

    conflicts.first(10) # Ограничить количество
  end

  # === GAPS HELPERS ===

  def find_mentioned_but_not_explained(files)
    gaps = []

    # Паттерны для упоминаний без раскрытия
    mention_patterns = [
      /см\.\s+(?:раздел\s+)?["«]([^"»]+)["»]/i,
      /подробнее\s+в\s+["«]([^"»]+)["»]/i,
      /описан[оа]?\s+в\s+["«]([^"»]+)["»]/i,
    ]

    files.each do |file|
      content = read_file(file)
      next unless content

      content.each_line.with_index(1) do |line, line_num|
        mention_patterns.each do |pattern|
          line.scan(pattern).each do |match|
            topic = match.is_a?(Array) ? match.first : match

            # Проверить существует ли раздел/файл
            unless topic_exists?(topic, files, content)
              gaps << {
                category: 'Упомянутые темы',
                file: file,
                line: line_num,
                message: "Упомянута тема \"#{topic}\", но не найдена в документации",
                priority: :warning
              }
            end
          end
        end
      end
    end

    gaps
  end

  def topic_exists?(topic, files, current_content)
    # Проверить есть ли файл с таким именем
    topic_file = topic.gsub(/\s+/, '_') + '.md'
    return true if files.any? { |f| f.downcase.include?(topic_file.downcase) }

    # Проверить есть ли заголовок с таким текстом
    return true if current_content.include?("# #{topic}")
    return true if current_content.include?("## #{topic}")

    false
  end

  def find_requirements_without_ac(files)
    gaps = []

    files.each do |file|
      next unless file.include?('REQUIREMENT') || file.match?(/^\d{2}_.*\.md$/)

      content = read_file(file)
      next unless content

      # Найти требования (строки с MUST, SHOULD, или начинающиеся с -)
      in_requirement_block = false
      current_req_line = 0
      current_req_text = ''

      content.each_line.with_index(1) do |line, line_num|
        if line.match?(/^[-*]\s+.*(?:должен|должна|MUST|SHOULD|необходимо)/i)
          # Проверить предыдущее требование
          if in_requirement_block && !has_acceptance_criteria?(current_req_text)
            gaps << {
              category: 'Acceptance Criteria',
              file: file,
              line: current_req_line,
              message: "Требование без acceptance criteria",
              priority: :warning
            }
          end

          in_requirement_block = true
          current_req_line = line_num
          current_req_text = line
        elsif in_requirement_block
          current_req_text += line
          # Конец блока требования
          if line.strip.empty? || line.match?(/^#/)
            in_requirement_block = false
          end
        end
      end
    end

    gaps.first(20) # Ограничить
  end

  def has_acceptance_criteria?(text)
    ac_patterns = [
      /acceptance/i,
      /критери/i,
      /условия приёмки/i,
      /given.*when.*then/i,
      /проверка:/i,
      /тест:/i,
    ]

    ac_patterns.any? { |p| text.match?(p) }
  end

  def find_entities_without_artifacts(files)
    gaps = []

    # Найти упоминания сущностей со статусами
    entity_patterns = [
      /статус[ыа]?\s+(\w+)/i,
      /состояни[ея]\s+(\w+)/i,
      /(\w+)\s+(?:может быть|имеет статус)/i,
    ]

    entities_with_status = []

    files.each do |file|
      content = read_file(file)
      next unless content

      entity_patterns.each do |pattern|
        content.scan(pattern).each do |match|
          entity = match.is_a?(Array) ? match.first : match
          entities_with_status << entity.downcase if entity.length > 2
        end
      end
    end

    entities_with_status = entities_with_status.uniq

    # Проверить есть ли State Diagram
    state_machines = read_file('architecture/STATE_MACHINES.md') || ''

    entities_with_status.each do |entity|
      unless state_machines.downcase.include?(entity)
        gaps << {
          category: 'State Diagrams',
          file: 'architecture/STATE_MACHINES.md',
          line: 0,
          message: "Сущность \"#{entity}\" имеет статусы, но нет State Diagram",
          priority: :info
        }
      end
    end

    gaps.first(10)
  end

  def find_incomplete_integrations(files)
    gaps = []

    # Найти упоминания интеграций
    integration_patterns = [
      /интеграция\s+с\s+(\w+)/i,
      /API\s+(\w+)/i,
      /webhook[ыи]?\s+(\w+)?/i,
      /внешн[яий]+\s+(?:система|сервис)\s+(\w+)?/i,
    ]

    integrations = []

    files.each do |file|
      content = read_file(file)
      next unless content

      integration_patterns.each do |pattern|
        content.scan(pattern).each do |match|
          name = match.is_a?(Array) ? match.first : match
          integrations << { name: name || 'unnamed', file: file } if name.nil? || name.length > 2
        end
      end
    end

    # Проверить есть ли Event Catalog
    event_catalog_path = @project_root / 'architecture/EVENT_CATALOG.md'
    unless event_catalog_path.exist?
      if integrations.any?
        gaps << {
          category: 'Event Catalog',
          file: 'architecture/EVENT_CATALOG.md',
          line: 0,
          message: "Найдены интеграции (#{integrations.size}), но нет Event Catalog",
          priority: :warning
        }
      end
    end

    gaps
  end

  # === LINT CHECKS ===

  def check_broken_links(file)
    content = read_file(file)
    return unless content

    # Найти все markdown ссылки [text](path)
    content.each_line.with_index(1) do |line, line_num|
      line.scan(/\[([^\]]+)\]\(([^)]+)\)/).each do |text, link|
        next if link.start_with?('http://', 'https://', '#', 'mailto:')

        # Разрешить относительный путь
        target = resolve_link(file, link)
        target_path = @project_root / target

        unless target_path.exist?
          add_issue('LINT', file, line_num,
                   "Битая ссылка: [#{text}](#{link}) → файл не существует: #{target}",
                   :info,
                   { fix_type: 'broken_link', link: link, text: text })
        end
      end
    end
  end

  def resolve_link(from_file, link)
    # Убрать якорь
    link = link.split('#').first
    return link if link.nil? || link.empty?

    from_dir = Pathname.new(from_file).dirname
    (from_dir / link).cleanpath.to_s
  end

  def check_naming_conventions(file)
    # Только для корневых файлов
    return unless file.count('/').zero?
    return if %w[README.md CHANGELOG.md TODO.md AGENTS.md].include?(file)

    pattern = Regexp.new(@config.dig('formatting', 'root_naming') || '^[0-9]{2}_[A-Z_]+\.md$')

    unless file.match?(pattern)
      add_issue('LINT', file, 0,
               "Нарушение naming convention: ожидается формат NN_TITLE.md (например, 01_INTRO.md)",
               :info,
               { fix_type: 'naming' })
    end
  end

  def check_empty_sections(file)
    content = read_file(file)
    return unless content

    lines = content.lines
    lines.each_with_index do |line, idx|
      next unless line.match?(/^##+ /)

      # Проверить следующие строки до следующего заголовка
      next_lines = lines[(idx + 1)..-1] || []
      content_before_next_header = []

      next_lines.each do |next_line|
        break if next_line.match?(/^##+ /)
        content_before_next_header << next_line
      end

      # Секция пустая если только пробелы
      if content_before_next_header.join.strip.empty?
        add_issue('LINT', file, idx + 1,
                 "Пустая секция: #{line.strip}",
                 :info,
                 { fix_type: 'empty_section', section: line.strip })
      end
    end
  end

  def check_todo_fixme(file)
    content = read_file(file)
    return unless content

    content.each_line.with_index(1) do |line, line_num|
      if line.match?(/\b(TODO|FIXME|XXX|HACK)\b/i)
        # Проверить есть ли ссылка на issue (#123 или issue URL)
        unless line.match?(/#\d+|github\.com\/.*\/issues\/\d+/)
          add_issue('LINT', file, line_num,
                   "TODO/FIXME без ссылки на issue: #{line.strip[0..80]}",
                   :info,
                   { fix_type: 'todo_no_issue' })
        end
      end
    end
  end

  def check_required_sections(file)
    content = read_file(file)
    return unless content

    # Для requirements файлов
    if file.include?('REQUIREMENT') || file.match?(/^\d{2}_REQUIREMENTS?\.md$/)
      required = @config.dig('formatting', 'requirements_sections') || []
      check_sections(file, content, required)
    end

    # Для decision файлов (ADR)
    if file.include?('ADR') || file.include?('decision')
      required = @config.dig('formatting', 'decision_sections') || []
      check_sections(file, content, required)
    end
  end

  def check_sections(file, content, required_sections)
    required_sections.each do |section|
      unless content.include?(section)
        add_issue('LINT', file, 0,
                 "Отсутствует обязательная секция: #{section}",
                 :warning)
      end
    end
  end

  # === LINKS CHECKS ===

  def build_link_graph(files)
    graph = { nodes: files.dup, links: [] }

    files.each do |file|
      content = read_file(file)
      next unless content

      content.scan(/\[([^\]]+)\]\(([^)]+)\)/).each do |text, link|
        next if link.start_with?('http://', 'https://', '#', 'mailto:')

        target = resolve_link(file, link)
        if files.include?(target)
          graph[:links] << { from: file, to: target }
        end
      end
    end

    graph
  end

  def find_orphans(graph, files)
    # Документы без входящих ссылок
    has_incoming = graph[:links].map { |l| l[:to] }.uniq
    exceptions = @config.dig('link_exceptions', 'not_orphans') || []

    files.reject do |file|
      has_incoming.include?(file) ||
        exceptions.any? { |p| File.fnmatch(p, file, File::FNM_PATHNAME) }
    end
  end

  def find_dead_ends(graph, files)
    # Документы без исходящих ссылок
    has_outgoing = graph[:links].map { |l| l[:from] }.uniq
    exceptions = @config.dig('link_exceptions', 'not_dead_ends') || []

    files.reject do |file|
      has_outgoing.include?(file) ||
        exceptions.any? { |p| File.fnmatch(p, file, File::FNM_PATHNAME) }
    end
  end

  def generate_mermaid_graph(graph, orphans = [], dead_ends = [])
    lines = ["```mermaid", "flowchart LR"]

    # Собираем уникальные узлы
    nodes = {}
    graph[:nodes].each do |node|
      node_id = node_to_id(node)
      node_label = File.basename(node, '.md')

      # Определяем стиль узла
      style = if orphans.include?(node)
                "#{node_id}[\"🔸 #{node_label}\"]"  # Orphan
              elsif dead_ends.include?(node)
                "#{node_id}[\"#{node_label} 🔹\"]"  # Dead-end
              elsif node == 'README.md'
                "#{node_id}((\"#{node_label}\"))"  # Entry point (circle)
              else
                "#{node_id}[\"#{node_label}\"]"
              end

      nodes[node] = { id: node_id, style: style }
    end

    # Добавляем определения узлов
    nodes.each { |_, data| lines << "    #{data[:style]}" }

    lines << ""

    # Добавляем связи
    graph[:links].each do |link|
      from_id = node_to_id(link[:from])
      to_id = node_to_id(link[:to])
      lines << "    #{from_id} --> #{to_id}"
    end

    # Добавляем стили
    lines << ""
    lines << "    %% Стили"
    lines << "    classDef orphan fill:#fff3cd,stroke:#ffc107"
    lines << "    classDef deadend fill:#cfe2ff,stroke:#0d6efd"
    lines << "    classDef entry fill:#d1e7dd,stroke:#198754"

    # Применяем классы
    orphan_ids = orphans.map { |o| node_to_id(o) }
    dead_end_ids = dead_ends.map { |d| node_to_id(d) }

    lines << "    class #{orphan_ids.join(',')} orphan" if orphan_ids.any?
    lines << "    class #{dead_end_ids.join(',')} deadend" if dead_end_ids.any?
    lines << "    class README entry" if nodes.key?('README.md')

    lines << "```"

    lines.join("\n")
  end

  def node_to_id(filename)
    # Преобразуем путь файла в валидный Mermaid ID
    filename
      .gsub(/[\/.]/, '_')
      .gsub(/[^a-zA-Z0-9_]/, '')
      .gsub(/^(\d)/, 'n\1')  # ID не может начинаться с цифры
  end

  def save_mermaid_graph(mermaid_content)
    output_dir = @project_root / '.docvalidate'
    FileUtils.mkdir_p(output_dir)

    output_file = output_dir / 'link_graph.md'

    content = <<~MD
      # Граф связей документации

      > **Сгенерировано:** #{Time.now.strftime('%Y-%m-%d %H:%M')}
      > **Команда:** `doc_validate.rb links --mermaid`

      ## Легенда

      - 🔸 **Orphan** — документ без входящих ссылок (жёлтый)
      - 🔹 **Dead-end** — документ без исходящих ссылок (синий)
      - **README** — точка входа (зелёный круг)

      ## Граф

      #{mermaid_content}

      ## Рекомендации

      1. **Orphans** должны иметь входящие ссылки из README или родительских документов
      2. **Dead-ends** допустимы для глоссариев и индексов
      3. Каждый документ должен быть достижим из README за 2-3 клика
    MD

    File.write(output_file, content)
    output_file.relative_path_from(@project_root).to_s
  end

  def check_readme_navigation(files)
    readme = read_file('README.md')
    return { covered: 0, total: files.size, percent: 0 } unless readme

    covered = files.count do |file|
      readme.include?("](#{file})") || readme.include?("](./#{file})")
    end

    {
      covered: covered,
      total: files.size,
      percent: ((covered.to_f / files.size) * 100).round
    }
  end

  # === ISSUE MANAGEMENT ===

  def add_issue(category, file, line, message, priority, metadata = {})
    id = "#{category}-#{@issues.size + 1}".rjust(3, '0')

    issue = {
      id: id,
      category: category,
      file: file,
      line: line,
      message: message,
      priority: priority,
      metadata: metadata,
      timestamp: Time.now.iso8601
    }

    @issues << issue
    @stats[priority] += 1

    # Вывести проблему (если не batch mode)
    print_issue(issue) unless @mode == MODE_BATCH

    # Интерактивный режим
    if @mode == MODE_INTERACTIVE
      handle_interactive(issue)
    end
  end

  def print_issue(issue)
    p = PRIORITY[issue[:priority]]

    puts "━" * 50
    puts "#{p[:symbol]} [#{issue[:id]}] #{issue[:message][0..60]}"
    puts "━" * 50
    puts
    puts "📄 #{issue[:file]}#{issue[:line] > 0 ? ":#{issue[:line]}" : ''}"
    puts "   #{issue[:message]}"
    puts
  end

  # === INTERACTIVE MODE ===

  def handle_interactive(issue)
    fix_available = can_fix?(issue)

    # Показать доступные действия
    actions = []
    actions << "[#{COLORS[:green]}f#{COLORS[:reset]}]ix" if fix_available
    actions << "(fix unavailable)" unless fix_available
    actions << "[#{COLORS[:yellow]}s#{COLORS[:reset]}]kip"
    actions << "[#{COLORS[:cyan]}i#{COLORS[:reset]}]gnore"
    actions << "[#{COLORS[:blue]}e#{COLORS[:reset]}]dit"
    actions << "e[#{COLORS[:magenta]}x#{COLORS[:reset]}]plain"

    print actions.join("  ")
    print "\n> "

    begin
      choice = $stdin.gets&.chomp&.downcase || 's'
    rescue Interrupt
      puts "\n\n⚠️ Прервано пользователем"
      save_session_state
      exit 0
    end

    case choice
    when 'f'
      if fix_available
        apply_fix(issue)
      else
        puts "#{COLORS[:yellow]}⚠️ Автоисправление недоступно для этой проблемы#{COLORS[:reset]}\n"
      end
    when 's'
      @skipped << issue[:id]
      puts "#{COLORS[:yellow]}⏭️ Пропущено#{COLORS[:reset]}\n"
    when 'i'
      add_to_docignore(issue)
      @ignored << issue[:id]
      puts "#{COLORS[:cyan]}🚫 Добавлено в .docignore#{COLORS[:reset]}\n"
    when 'e'
      open_in_editor(issue)
    when 'x'
      explain_issue(issue)
      # После объяснения повторить prompt
      handle_interactive(issue)
    else
      puts "#{COLORS[:yellow]}Неизвестное действие, пропуск...#{COLORS[:reset]}\n"
      @skipped << issue[:id]
    end

    puts
  end

  def can_fix?(issue)
    fixable_types = %w[broken_link synonym empty_section]
    fix_type = issue.dig(:metadata, :fix_type)
    fixable_types.include?(fix_type.to_s)
  end

  def apply_fix(issue)
    fix_type = issue.dig(:metadata, :fix_type)

    case fix_type.to_s
    when 'broken_link'
      fix_broken_link(issue)
    when 'synonym'
      fix_synonym(issue)
    when 'empty_section'
      fix_empty_section(issue)
    else
      puts "#{COLORS[:yellow]}⚠️ Неизвестный тип исправления: #{fix_type}#{COLORS[:reset]}"
    end
  end

  def fix_broken_link(issue)
    file = issue[:file]
    link = issue.dig(:metadata, :link)
    text = issue.dig(:metadata, :text)

    puts "\n#{COLORS[:cyan]}🔧 Исправление битой ссылки...#{COLORS[:reset]}"

    # Поиск похожих файлов
    candidates = find_similar_files(link)

    if candidates.any?
      puts "Найдены похожие файлы:"
      candidates.each_with_index { |c, i| puts "  #{i + 1}. #{c}" }
      puts "  0. Удалить ссылку (оставить только текст)"
      print "Выберите (0-#{candidates.size}): "

      choice = $stdin.gets&.chomp&.to_i || 0

      if choice == 0
        # Удалить ссылку, оставить текст
        replace_in_file(file, "[#{text}](#{link})", text)
        puts "#{COLORS[:green]}✅ Ссылка удалена, текст сохранён#{COLORS[:reset]}"
      elsif choice > 0 && choice <= candidates.size
        new_link = candidates[choice - 1]
        replace_in_file(file, "[#{text}](#{link})", "[#{text}](#{new_link})")
        puts "#{COLORS[:green]}✅ Ссылка заменена на: #{new_link}#{COLORS[:reset]}"
      end
    else
      puts "Похожих файлов не найдено."
      print "Удалить ссылку? [y/n]: "

      if $stdin.gets&.chomp&.downcase == 'y'
        replace_in_file(file, "[#{text}](#{link})", text)
        puts "#{COLORS[:green]}✅ Ссылка удалена#{COLORS[:reset]}"
      end
    end

    @fixed << issue[:id]
  end

  def fix_synonym(issue)
    file = issue[:file]
    line_num = issue[:line]
    synonym = issue.dig(:metadata, :synonym)
    canonical = issue.dig(:metadata, :canonical)

    puts "\n#{COLORS[:cyan]}🔧 Замена синонима...#{COLORS[:reset]}"
    puts "  \"#{synonym}\" → \"#{canonical}\""

    content = read_file(file)
    return unless content

    lines = content.lines
    return unless lines[line_num - 1]

    # Заменить только в указанной строке
    old_line = lines[line_num - 1]
    new_line = old_line.gsub(/\b#{Regexp.escape(synonym)}\b/i, canonical)

    if old_line != new_line
      lines[line_num - 1] = new_line
      File.write(@project_root / file, lines.join)
      invalidate_cache(file)  # Инвалидируем кэш после изменения
      puts "#{COLORS[:green]}✅ Синоним заменён#{COLORS[:reset]}"
      @fixed << issue[:id]
    else
      puts "#{COLORS[:yellow]}⚠️ Не удалось найти синоним в строке#{COLORS[:reset]}"
    end
  end

  def fix_empty_section(issue)
    file = issue[:file]
    section = issue.dig(:metadata, :section)

    puts "\n#{COLORS[:cyan]}🔧 Удаление пустой секции...#{COLORS[:reset]}"
    puts "  Секция: #{section}"
    print "Удалить секцию? [y/n]: "

    return unless $stdin.gets&.chomp&.downcase == 'y'

    content = read_file(file)
    return unless content

    # Удалить заголовок секции
    new_content = content.gsub(/^#{Regexp.escape(section)}\s*\n/, '')

    if content != new_content
      File.write(@project_root / file, new_content)
      invalidate_cache(file)  # Инвалидируем кэш после изменения
      puts "#{COLORS[:green]}✅ Секция удалена#{COLORS[:reset]}"
      @fixed << issue[:id]
    end
  end

  def find_similar_files(broken_link)
    # Извлечь имя файла из ссылки
    filename = File.basename(broken_link, '.*')

    # Поиск похожих файлов
    all_files = find_markdown_files

    candidates = all_files.select do |f|
      f_name = File.basename(f, '.*').downcase
      filename.downcase.include?(f_name) || f_name.include?(filename.downcase)
    end

    candidates.first(5)
  end

  def replace_in_file(file, old_text, new_text)
    path = @project_root / file
    content = File.read(path)
    new_content = content.gsub(old_text, new_text)
    File.write(path, new_content)
    invalidate_cache(file)  # Инвалидируем кэш после изменения
  end

  def add_to_docignore(issue)
    docignore_path = @project_root / '.docvalidate' / '.docignore'
    FileUtils.mkdir_p(docignore_path.dirname)

    entry = {
      id: issue[:id],
      file: "#{issue[:file]}:#{issue[:line]}",
      reason: "User ignored",
      created: Time.now.strftime('%Y-%m-%d')
    }

    File.open(docignore_path, 'a') do |f|
      f.puts(JSON.generate(entry))
    end
  end

  def open_in_editor(issue)
    editor = ENV['EDITOR'] || 'code'
    file = issue[:file]
    line = issue[:line]

    full_path = @project_root / file

    cmd = case editor
          when /code/
            "#{editor} -g \"#{full_path}:#{line}\""
          when /vim|nvim/
            "#{editor} +#{line} \"#{full_path}\""
          else
            "#{editor} \"#{full_path}\""
          end

    puts "#{COLORS[:blue]}📝 Открываю: #{cmd}#{COLORS[:reset]}"
    system(cmd)

    print "Нажмите Enter после редактирования..."
    $stdin.gets
  end

  def explain_issue(issue)
    puts "\n#{COLORS[:bold]}📚 Подробное объяснение#{COLORS[:reset]}\n\n"

    case issue[:category]
    when 'LINT'
      explain_lint_issue(issue)
    when 'TERM'
      explain_term_issue(issue)
    when 'VIEWPOINT'
      explain_viewpoint_issue(issue)
    when 'CONTRADICTION'
      explain_contradiction_issue(issue)
    when 'GAP'
      explain_gap_issue(issue)
    when 'LINK'
      explain_link_issue(issue)
    else
      puts "Проблема: #{issue[:message]}"
      puts "Файл: #{issue[:file]}:#{issue[:line]}"
    end

    puts
  end

  def explain_lint_issue(issue)
    fix_type = issue.dig(:metadata, :fix_type)

    case fix_type
    when 'broken_link'
      puts "#{COLORS[:yellow]}Битая ссылка#{COLORS[:reset]}"
      puts "Ссылка указывает на несуществующий файл."
      puts "\nВарианты исправления:"
      puts "  1. Исправить путь к файлу"
      puts "  2. Создать отсутствующий файл"
      puts "  3. Удалить ссылку"
    when 'naming'
      puts "#{COLORS[:yellow]}Нарушение naming convention#{COLORS[:reset]}"
      puts "Файл не соответствует шаблону именования."
      puts "Ожидается формат: NN_TITLE.md (например, 01_INTRO.md)"
    when 'empty_section'
      puts "#{COLORS[:yellow]}Пустая секция#{COLORS[:reset]}"
      puts "Заголовок секции без содержимого."
      puts "Добавьте контент или удалите секцию."
    when 'todo_no_issue'
      puts "#{COLORS[:yellow]}TODO без ссылки на issue#{COLORS[:reset]}"
      puts "TODO/FIXME должны ссылаться на GitHub issue."
      puts "Формат: TODO #123 или TODO github.com/.../issues/123"
    else
      puts issue[:message]
    end
  end

  def explain_term_issue(issue)
    puts "#{COLORS[:yellow]}Проблема терминологии#{COLORS[:reset]}"

    if issue.dig(:metadata, :fix_type) == 'synonym'
      puts "Используется запрещённый синоним."
      puts "Для единообразия документации используйте канонический термин."
      puts "\nЗапрещено: #{issue.dig(:metadata, :synonym)}"
      puts "Используйте: #{issue.dig(:metadata, :canonical)}"
    else
      puts "Новый термин, отсутствующий в глоссарии."
      puts "Добавьте термин в глоссарий или используйте существующий."
    end
  end

  def explain_viewpoint_issue(issue)
    puts "#{COLORS[:yellow]}Отсутствует артефакт viewpoint#{COLORS[:reset]}"
    puts "Согласно BABOK viewpoints, этот артефакт обязателен."
    puts "\nViewpoint: #{issue.dig(:metadata, :viewpoint)}"
    puts "Приоритет: #{issue.dig(:metadata, :priority)}"
    puts "\nСоздайте файл с необходимой документацией."
  end

  def explain_contradiction_issue(issue)
    puts "#{COLORS[:red]}Противоречие в документации#{COLORS[:reset]}"
    puts "Один параметр имеет разные значения в разных документах."
    puts "Это может привести к путанице и ошибкам реализации."
    puts "\nНеобходимо выбрать одно правильное значение и обновить все документы."
  end

  def explain_gap_issue(issue)
    puts "#{COLORS[:yellow]}Пробел в документации#{COLORS[:reset]}"
    puts "Обнаружена неполнота документации."
    puts "\nКатегория: #{issue.dig(:metadata, :category)}"
    puts "Добавьте недостающую информацию."
  end

  def explain_link_issue(issue)
    puts "#{COLORS[:yellow]}Проблема графа связей#{COLORS[:reset]}"

    if issue[:message].include?('orphan')
      puts "Документ не имеет входящих ссылок."
      puts "Добавьте ссылку на этот документ из README или связанных файлов."
    else
      puts "Документ не имеет исходящих ссылок."
      puts "Добавьте ссылки на связанные документы."
    end
  end

  def save_session_state
    session_path = @project_root / '.docvalidate' / 'session.json'
    FileUtils.mkdir_p(session_path.dirname)

    state = {
      timestamp: Time.now.iso8601,
      processed: @issues.size,
      skipped: @skipped,
      fixed: @fixed,
      ignored: @ignored,
      stats: @stats
    }

    File.write(session_path, JSON.pretty_generate(state))
    puts "💾 Сессия сохранена в #{session_path}"
  end

  def print_summary(command)
    puts "\n" + "═" * 50
    puts "📊 Итоги /doc:#{command}"
    puts "═" * 50
    puts
    puts "  🔴 Критические:  #{@stats[:critical]}"
    puts "  🟡 Важные:       #{@stats[:warning]}"
    puts "  🟢 Информация:   #{@stats[:info]}"
    puts "  ─" * 20
    puts "  Всего:          #{@issues.size}"
    puts
  end

  # === REVIEW HELPERS ===

  def reset_state
    @issues = []
    @stats = { critical: 0, warning: 0, info: 0 }
  end

  def load_previous_review
    history_file = @project_root / '.docvalidate' / 'history.json'
    return nil unless history_file.exist?

    history = JSON.parse(File.read(history_file))
    reviews = history['runs'].select { |r| r['command'] == 'review' }
    reviews.last
  rescue
    nil
  end

  def format_diff(diff)
    return "#{diff} (без изменений)" if diff == 0
    diff > 0 ? "#{COLORS[:red]}+#{diff} ↑#{COLORS[:reset]}" : "#{COLORS[:green]}#{diff} ↓#{COLORS[:reset]}"
  end

  def print_recommendations(stats, results)
    puts "#{COLORS[:bold]}💡 Рекомендации:#{COLORS[:reset]}\n\n"

    recommendations = []

    # Критические проблемы
    if stats[:critical] > 0
      recommendations << "🔴 Исправьте #{stats[:critical]} критических проблем в первую очередь"
    end

    # Противоречия
    if results[:contradictions] && results[:contradictions][:parameter_conflicts]&.any?
      recommendations << "⚡ Разрешите противоречия в числовых параметрах"
    end

    # Viewpoints
    if results[:viewpoints] && results[:viewpoints][:coverage] && results[:viewpoints][:coverage] < 80
      recommendations << "📐 Увеличьте покрытие viewpoints (сейчас #{results[:viewpoints][:coverage]}%)"
    end

    # Глоссарий
    if results[:terms] && results[:terms][:coverage] && results[:terms][:coverage] < 80
      recommendations << "📚 Улучшите покрытие глоссария (сейчас #{results[:terms][:coverage]}%)"
    end

    # Orphans
    if results[:links] && results[:links][:orphans]&.any?
      recommendations << "🔗 Добавьте ссылки на #{results[:links][:orphans].size} orphan-документов"
    end

    if recommendations.empty?
      puts "  ✅ Документация в отличном состоянии!\n\n"
    else
      recommendations.first(5).each { |r| puts "  • #{r}" }
      puts
    end
  end

  def calculate_score(stats)
    # Формула оценки: 100 - (critical * 10) - (warning * 2) - (info * 0.5)
    # Минимум 0, максимум 100
    score = 100 - (stats[:critical] * 10) - (stats[:warning] * 2) - (stats[:info] * 0.5)
    [[score, 0].max, 100].min.round
  end

  def print_overall_score(score)
    grade = case score
            when 90..100 then { letter: 'A', color: :green, emoji: '🏆' }
            when 80..89 then { letter: 'B', color: :green, emoji: '✅' }
            when 70..79 then { letter: 'C', color: :yellow, emoji: '🟡' }
            when 60..69 then { letter: 'D', color: :yellow, emoji: '⚠️' }
            else { letter: 'F', color: :red, emoji: '🔴' }
            end

    puts "#{COLORS[:bold]}╔══════════════════════════════════════╗#{COLORS[:reset]}"
    puts "#{COLORS[:bold]}║     #{grade[:emoji]} ОБЩАЯ ОЦЕНКА: #{COLORS[grade[:color]]}#{score}/100 (#{grade[:letter]})#{COLORS[:reset]}#{COLORS[:bold]}     ║#{COLORS[:reset]}"
    puts "#{COLORS[:bold]}╚══════════════════════════════════════╝#{COLORS[:reset]}"
    puts
  end

  # === HISTORY ===

  def save_history(command)
    history_dir = @project_root / '.docvalidate'
    FileUtils.mkdir_p(history_dir)

    history_file = history_dir / 'history.json'
    history = if history_file.exist?
                JSON.parse(File.read(history_file))
              else
                { 'runs' => [] }
              end

    history['runs'] << {
      'timestamp' => Time.now.iso8601,
      'command' => command,
      'commit' => `git rev-parse --short HEAD 2>/dev/null`.strip,
      'metrics' => @stats.transform_keys(&:to_s)
    }

    # Хранить последние 100 запусков
    history['runs'] = history['runs'].last(100)

    File.write(history_file, JSON.pretty_generate(history))
  rescue => e
    warn "Не удалось сохранить историю: #{e.message}"
  end
end

# === CLI ===

if __FILE__ == $0
  command = ARGV[0]
  options = {}

  # Парсинг опций
  ARGV[1..-1].each do |arg|
    case arg
    when '--help', '-h'
      options[:help] = true
    when '--json'
      options[:json] = true
    when '--interactive', '-i'
      options[:interactive] = true
    when '--batch', '-b'
      options[:batch] = true
    when '--mermaid', '-m'
      options[:mermaid] = true
    when /^--project=(.+)$/
      options[:project] = $1
    end
  end

  if options[:help] || command.nil?
    puts <<~HELP
      doc_validate.rb — Утилита для валидации документации v#{DocValidator::VERSION}

      Использование:
        ./doc_validate.rb <command> [options]

      Команды:
        lint           Проверка форматирования и структуры
        links          Граф связей документации
        terms          Проверка консистентности терминологии
        viewpoints     Проверка артефактов по BABOK viewpoints
        contradictions Поиск логических противоречий между файлами
        gaps           Анализ полноты покрытия документации
        review         Полный аудит (все команды + сводный отчёт)
        help           Показать эту справку

      Опции:
        --project=PATH   Путь к проекту (по умолчанию: текущая директория)
        --interactive,-i Интерактивный режим (f/s/i/e/x для каждой проблемы)
        --batch, -b      Batch режим для CI/CD (без промптов, с exit codes)
        --mermaid, -m    Генерировать Mermaid граф (для команды links)
        --json           Вывод в формате JSON
        --help, -h       Показать справку

      Режимы работы:
        По умолчанию:    Вывод проблем без интерактива
        --interactive:   Промпт для каждой проблемы [f]ix [s]kip [i]gnore [e]dit e[x]plain
        --batch:         Тихий режим, exit code: 0=ok, 1=warnings, 2=critical

      Примеры:
        ./doc_validate.rb lint --interactive
        ./doc_validate.rb review --batch
        ./doc_validate.rb links --mermaid
        ./doc_validate.rb gaps --project=/path/to/project --json
    HELP
    exit 0
  end

  # Определить режим работы
  mode = if options[:interactive]
           DocValidator::MODE_INTERACTIVE
         elsif options[:batch]
           DocValidator::MODE_BATCH
         else
           DocValidator::MODE_DEFAULT
         end

  validator = DocValidator.new(options[:project] || Dir.pwd, mode: mode)

  # Выполнение команды
  result = case command
           when 'lint'
             validator.lint(options)
           when 'links'
             validator.links(options)
           when 'terms'
             validator.terms(options)
           when 'viewpoints'
             validator.viewpoints(options)
           when 'contradictions'
             validator.contradictions(options)
           when 'gaps'
             validator.gaps(options)
           when 'review'
             validator.review(options)
           else
             puts "Неизвестная команда: #{command}"
             puts "Используйте --help для справки"
             exit 1
           end

  # JSON вывод
  puts JSON.pretty_generate(result) if options[:json] && result

  # Exit codes для batch режима
  if options[:batch]
    stats = result.is_a?(Hash) && result[:total] ? result[:total] : validator.instance_variable_get(:@stats)
    if stats[:critical] > 0
      exit 2
    elsif stats[:warning] > 0 || stats[:info] > 0
      exit 1
    else
      exit 0
    end
  end
end
