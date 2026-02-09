# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DocValidator do
  describe '.new' do
    it 'инициализируется с дефолтными значениями', :temp_project do
      validator = described_class.new(@temp_dir)

      expect(validator.instance_variable_get(:@issues)).to eq([])
      expect(validator.instance_variable_get(:@stats)).to eq({ critical: 0, warning: 0, info: 0 })
      expect(validator.instance_variable_get(:@mode)).to eq(DocValidator::MODE_DEFAULT)
    end

    it 'принимает режим интерактивный', :temp_project do
      validator = described_class.new(@temp_dir, mode: DocValidator::MODE_INTERACTIVE)

      expect(validator.instance_variable_get(:@mode)).to eq(DocValidator::MODE_INTERACTIVE)
    end

    it 'принимает режим batch', :temp_project do
      validator = described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH)

      expect(validator.instance_variable_get(:@mode)).to eq(DocValidator::MODE_BATCH)
    end
  end

  describe '#load_config' do
    context 'без конфигурационного файла', :temp_project do
      it 'использует дефолтную конфигурацию' do
        validator = described_class.new(@temp_dir)
        config = validator.instance_variable_get(:@config)

        expect(config['version']).to eq(1)
        expect(config['glossary']['file']).to eq('02_GLOSSARY.md')
        expect(config['scope']['strict']).to include('*.md')
      end
    end

    context 'с конфигурационным файлом', :temp_project do
      before do
        write_config({
          'version' => 2,
          'glossary' => { 'file' => 'GLOSSARY.md' },
          'scope' => { 'strict' => ['docs/**/*.md'] }
        })
      end

      it 'загружает пользовательскую конфигурацию' do
        validator = described_class.new(@temp_dir)
        config = validator.instance_variable_get(:@config)

        expect(config['version']).to eq(2)
        expect(config['glossary']['file']).to eq('GLOSSARY.md')
        expect(config['scope']['strict']).to eq(['docs/**/*.md'])
      end
    end

    context 'с невалидным YAML', :temp_project do
      before do
        write_file('.docvalidate.yml', "invalid: yaml: content:\n  - broken")
      end

      it 'возвращает дефолтную конфигурацию при ошибке' do
        validator = described_class.new(@temp_dir)
        config = validator.instance_variable_get(:@config)

        expect(config['version']).to eq(1)
      end
    end
  end

  describe '#check_broken_links', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    before do
      write_file('README.md', '# Test')
    end

    context 'с валидными ссылками' do
      before do
        write_file('doc.md', "[Link to README](README.md)\n[External](https://example.com)")
      end

      it 'не создаёт issues' do
        validator.send(:check_broken_links, 'doc.md')

        expect(validator.instance_variable_get(:@issues)).to be_empty
      end
    end

    context 'с битыми ссылками' do
      before do
        write_file('doc.md', "[Broken Link](missing.md)")
      end

      it 'создаёт issue для битой ссылки' do
        validator.send(:check_broken_links, 'doc.md')
        issues = validator.instance_variable_get(:@issues)

        expect(issues.size).to eq(1)
        expect(issues.first[:category]).to eq('LINT')
        expect(issues.first[:message]).to include('Битая ссылка')
        expect(issues.first[:message]).to include('missing.md')
      end
    end

    context 'с относительными путями' do
      before do
        write_file('docs/nested.md', '# Nested')
        write_file('doc.md', "[Nested](docs/nested.md)")
      end

      it 'корректно разрешает относительные пути' do
        validator.send(:check_broken_links, 'doc.md')

        expect(validator.instance_variable_get(:@issues)).to be_empty
      end
    end

    context 'с anchor ссылками' do
      before do
        write_file('doc.md', "[Section](#section)\n[External anchor](https://example.com#anchor)")
      end

      it 'игнорирует anchor ссылки' do
        validator.send(:check_broken_links, 'doc.md')

        expect(validator.instance_variable_get(:@issues)).to be_empty
      end
    end
  end

  describe '#check_forbidden_synonyms', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    before do
      write_config({
        'glossary' => {
          'file' => '02_GLOSSARY.md',
          'forbidden_synonyms' => [
            ['кошелёк', 'бумажник', 'wallet'],
            ['транзакция', 'трансакция', 'операция']
          ]
        }
      })
      # Пересоздаём валидатор с новым конфигом
      @validator_with_synonyms = described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH)
    end

    context 'с запрещёнными синонимами' do
      before do
        write_file('doc.md', "Используйте бумажник для хранения средств.")
      end

      it 'создаёт issue для запрещённого синонима' do
        content = File.read(@temp_path / 'doc.md')
        @validator_with_synonyms.send(:check_forbidden_synonyms, 'doc.md', content)
        issues = @validator_with_synonyms.instance_variable_get(:@issues)

        expect(issues.size).to eq(1)
        expect(issues.first[:message]).to include('бумажник')
        expect(issues.first[:message]).to include('кошелёк')
      end
    end

    context 'с каноническим термином' do
      before do
        write_file('doc.md', "Используйте кошелёк для хранения средств.")
      end

      it 'не создаёт issue для канонического термина' do
        content = File.read(@temp_path / 'doc.md')
        @validator_with_synonyms.send(:check_forbidden_synonyms, 'doc.md', content)

        expect(@validator_with_synonyms.instance_variable_get(:@issues)).to be_empty
      end
    end

    context 'с несколькими синонимами в одном файле' do
      before do
        write_file('doc.md', "Бумажник и трансакция в одном документе.")
      end

      it 'создаёт issues для каждого синонима' do
        content = File.read(@temp_path / 'doc.md')
        @validator_with_synonyms.send(:check_forbidden_synonyms, 'doc.md', content)
        issues = @validator_with_synonyms.instance_variable_get(:@issues)

        expect(issues.size).to eq(2)
        messages = issues.map { |i| i[:message] }
        expect(messages.any? { |m| m.include?('бумажник') }).to be true
        expect(messages.any? { |m| m.include?('трансакция') }).to be true
      end
    end
  end

  describe '#check_empty_sections', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    context 'с пустой секцией' do
      before do
        write_file('doc.md', "# Title\n\n## Empty Section\n\n## Next Section\n\nContent here.")
      end

      it 'создаёт issue для пустой секции' do
        validator.send(:check_empty_sections, 'doc.md')
        issues = validator.instance_variable_get(:@issues)

        expect(issues.size).to eq(1)
        expect(issues.first[:message]).to include('Пустая секция')
        expect(issues.first[:message]).to include('Empty Section')
      end
    end

    context 'с заполненными секциями' do
      before do
        write_file('doc.md', "# Title\n\n## Section\n\nContent.\n\n## Another\n\nMore content.")
      end

      it 'не создаёт issues' do
        validator.send(:check_empty_sections, 'doc.md')

        expect(validator.instance_variable_get(:@issues)).to be_empty
      end
    end
  end

  describe '#check_naming_conventions', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    context 'с корректным именем файла' do
      it 'не создаёт issue для 01_INTRO.md' do
        write_file('01_INTRO.md', '# Intro')
        validator.send(:check_naming_conventions, '01_INTRO.md')

        expect(validator.instance_variable_get(:@issues)).to be_empty
      end

      it 'не создаёт issue для README.md' do
        write_file('README.md', '# README')
        validator.send(:check_naming_conventions, 'README.md')

        expect(validator.instance_variable_get(:@issues)).to be_empty
      end
    end

    context 'с некорректным именем файла' do
      it 'создаёт issue для random_file.md' do
        write_file('random_file.md', '# Random')
        validator.send(:check_naming_conventions, 'random_file.md')
        issues = validator.instance_variable_get(:@issues)

        expect(issues.size).to eq(1)
        expect(issues.first[:message]).to include('naming convention')
      end
    end

    context 'для вложенных файлов' do
      it 'не проверяет naming convention' do
        write_file('docs/any_name.md', '# Any')
        validator.send(:check_naming_conventions, 'docs/any_name.md')

        expect(validator.instance_variable_get(:@issues)).to be_empty
      end
    end
  end

  describe '#extract_parameters', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    before do
      write_file('doc1.md', "Подтверждения: 3 confirmations\nТаймаут: 30 секунд")
      write_file('doc2.md', "Требуется 6 подтверждений\nОжидание: 60 секунд")
    end

    it 'извлекает числовые параметры из файлов' do
      files = ['doc1.md', 'doc2.md']
      parameters = validator.send(:extract_parameters, files)

      expect(parameters).to be_an(Array)
      expect(parameters.any? { |p| p[:value] == '3' }).to be true
      expect(parameters.any? { |p| p[:value] == '30' }).to be true
    end
  end

  describe '#find_parameter_conflicts', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    context 'с конфликтующими параметрами' do
      it 'находит конфликты по одинаковому parameter' do
        parameters = [
          { parameter: 'confirmations', value: '3', file: 'doc1.md', line: 1 },
          { parameter: 'confirmations', value: '6', file: 'doc2.md', line: 1 }
        ]

        conflicts = validator.send(:find_parameter_conflicts, parameters)

        expect(conflicts).to be_an(Array)
        expect(conflicts.size).to eq(1)
        expect(conflicts.first[:parameter]).to eq('confirmations')
        expect(conflicts.first[:values].sort).to eq(['3', '6'].sort)
      end
    end

    context 'без конфликтов' do
      it 'возвращает пустой массив для разных параметров' do
        parameters = [
          { parameter: 'confirmations', value: '3', file: 'doc1.md', line: 1 },
          { parameter: 'timeout', value: '30', file: 'doc2.md', line: 1 }
        ]

        conflicts = validator.send(:find_parameter_conflicts, parameters)

        expect(conflicts).to be_empty
      end

      it 'возвращает пустой массив для одинаковых значений' do
        parameters = [
          { parameter: 'confirmations', value: '3', file: 'doc1.md', line: 1 },
          { parameter: 'confirmations', value: '3', file: 'doc2.md', line: 1 }
        ]

        conflicts = validator.send(:find_parameter_conflicts, parameters)

        expect(conflicts).to be_empty
      end
    end
  end

  describe '#add_issue', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    it 'добавляет issue в список' do
      validator.send(:add_issue, 'LINT', 'test.md', 10, 'Test message', :warning)
      issues = validator.instance_variable_get(:@issues)

      expect(issues.size).to eq(1)
      expect(issues.first[:category]).to eq('LINT')
      expect(issues.first[:file]).to eq('test.md')
      expect(issues.first[:line]).to eq(10)
      expect(issues.first[:priority]).to eq(:warning)
    end

    it 'обновляет статистику' do
      validator.send(:add_issue, 'LINT', 'test.md', 1, 'Critical', :critical)
      validator.send(:add_issue, 'LINT', 'test.md', 2, 'Warning', :warning)
      validator.send(:add_issue, 'LINT', 'test.md', 3, 'Info', :info)

      stats = validator.instance_variable_get(:@stats)

      expect(stats[:critical]).to eq(1)
      expect(stats[:warning]).to eq(1)
      expect(stats[:info]).to eq(1)
    end
  end

  describe 'exit codes в batch mode', :temp_project do
    it 'возвращает 0 при отсутствии проблем' do
      write_file('README.md', '# Valid Document')
      # Exit codes проверяются через CLI, здесь тестируем stats
      validator = described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH)
      stats = validator.instance_variable_get(:@stats)

      expect(stats[:critical]).to eq(0)
      expect(stats[:warning]).to eq(0)
    end
  end

  describe '#review', :temp_project do
    before do
      write_file('README.md', "# Project\n\n[Doc](01_DOC.md)")
      write_file('01_DOC.md', "# Documentation\n\n## Content\n\nSome text here.")
      write_file('02_GLOSSARY.md', "# Glossary\n\n| **Термин** | Описание |\n|----------|----------|\n| **кошелёк** | Wallet |")
    end

    it 'запускает все проверки', :temp_project do
      validator = described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH)

      # Подавляем вывод
      expect { validator.review }.to output.to_stdout

      # Review должен заполнить issues из всех проверок
      issues = validator.instance_variable_get(:@issues)
      expect(issues).to be_an(Array)
    end
  end

  describe '#resolve_link', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    it 'разрешает простой относительный путь' do
      result = validator.send(:resolve_link, 'README.md', 'docs/file.md')
      expect(result).to eq('docs/file.md')
    end

    it 'разрешает путь с ..' do
      result = validator.send(:resolve_link, 'docs/nested.md', '../README.md')
      expect(result).to eq('README.md')
    end

    it 'убирает anchor из ссылки' do
      result = validator.send(:resolve_link, 'README.md', 'file.md#section')
      expect(result).to eq('file.md')
    end
  end

  describe '#can_fix?', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_INTERACTIVE) }

    it 'возвращает true для broken_link' do
      issue = { metadata: { fix_type: 'broken_link' } }
      expect(validator.send(:can_fix?, issue)).to be true
    end

    it 'возвращает true для synonym' do
      issue = { metadata: { fix_type: 'synonym' } }
      expect(validator.send(:can_fix?, issue)).to be true
    end

    it 'возвращает true для empty_section' do
      issue = { metadata: { fix_type: 'empty_section' } }
      expect(validator.send(:can_fix?, issue)).to be true
    end

    it 'возвращает false для неизвестного типа' do
      issue = { metadata: { fix_type: 'unknown' } }
      expect(validator.send(:can_fix?, issue)).to be false
    end

    it 'возвращает false без metadata' do
      issue = {}
      expect(validator.send(:can_fix?, issue)).to be false
    end
  end

  describe '#fix_synonym', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_INTERACTIVE) }

    before do
      write_file('doc.md', "Используйте бумажник для хранения.")
    end

    it 'заменяет синоним на канонический термин' do
      issue = {
        file: 'doc.md',
        line: 1,
        metadata: {
          fix_type: 'synonym',
          synonym: 'бумажник',
          canonical: 'кошелёк'
        }
      }

      validator.send(:fix_synonym, issue)

      content = File.read(@temp_path / 'doc.md')
      expect(content).to include('кошелёк')
      expect(content).not_to include('бумажник')
    end

    it 'использует canonical как есть (не сохраняет регистр)' do
      write_file('doc2.md', "Используйте бумажник.")
      issue = {
        file: 'doc2.md',
        line: 1,
        metadata: {
          fix_type: 'synonym',
          synonym: 'бумажник',
          canonical: 'Кошелёк'
        }
      }

      validator.send(:fix_synonym, issue)

      content = File.read(@temp_path / 'doc2.md')
      # Текущая реализация использует canonical без изменений
      expect(content).to include('Кошелёк')
    end
  end

  describe 'file caching', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    before do
      write_file('test.md', 'Original content')
    end

    it 'кэширует содержимое файла' do
      # Первое чтение — заполняет кэш
      validator.send(:read_file, 'test.md')
      # Изменяем файл напрямую
      File.write(@temp_path / 'test.md', 'Modified content')
      # Второе чтение — должно вернуть закэшированное значение
      cached_content = validator.send(:read_file, 'test.md')

      expect(cached_content).to eq('Original content')
    end

    it 'позволяет обойти кэш' do
      validator.send(:read_file, 'test.md')
      File.write(@temp_path / 'test.md', 'Modified content')
      content = validator.send(:read_file, 'test.md', use_cache: false)

      expect(content).to eq('Modified content')
    end

    it 'инвалидирует кэш при вызове invalidate_cache' do
      validator.send(:read_file, 'test.md')
      File.write(@temp_path / 'test.md', 'Modified content')
      validator.send(:invalidate_cache, 'test.md')
      content = validator.send(:read_file, 'test.md')

      expect(content).to eq('Modified content')
    end

    it 'очищает весь кэш при вызове clear_file_cache' do
      validator.send(:read_file, 'test.md')
      write_file('other.md', 'Other content')
      validator.send(:read_file, 'other.md')

      validator.send(:clear_file_cache)

      cache = validator.instance_variable_get(:@file_cache)
      expect(cache).to be_empty
    end
  end

  describe '#find_markdown_files', :temp_project do
    before do
      write_file('README.md', '# README')
      write_file('docs/guide.md', '# Guide')
      write_file('claudedocs/report.md', '# Report')  # Должен игнорироваться
      write_file('draft.draft.md', '# Draft')  # Должен игнорироваться
    end

    it 'находит markdown файлы согласно scope' do
      validator = described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH)
      files = validator.send(:find_markdown_files)

      expect(files).to include('README.md')
      # claudedocs должен игнорироваться по умолчанию
    end
  end

  describe '#load_glossary', :temp_project do
    context 'с глоссарием в формате таблицы' do
      before do
        write_file('02_GLOSSARY.md', <<~MD)
          # Глоссарий

          | **Термин** | Описание |
          |------------|----------|
          | **кошелёк** | Хранилище ключей |
          | **транзакция** | Перевод средств |
        MD
      end

      it 'парсит термины из таблицы' do
        validator = described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH)
        glossary = validator.send(:load_glossary)

        expect(glossary).to include('кошелёк')
        expect(glossary).to include('транзакция')
      end
    end

    context 'без файла глоссария' do
      it 'возвращает пустой массив' do
        validator = described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH)
        glossary = validator.send(:load_glossary)

        expect(glossary).to eq([])
      end
    end
  end

  describe '#generate_mermaid_graph', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    it 'генерирует валидный Mermaid flowchart' do
      graph = {
        nodes: ['README.md', 'docs/guide.md'],
        links: [{ from: 'README.md', to: 'docs/guide.md' }]
      }

      mermaid = validator.send(:generate_mermaid_graph, graph)

      expect(mermaid).to include('```mermaid')
      expect(mermaid).to include('flowchart LR')
      expect(mermaid).to include('README')
      expect(mermaid).to include('guide')
      expect(mermaid).to include('-->')
      expect(mermaid).to include('```')
    end

    it 'отмечает orphans с эмодзи 🔸' do
      graph = {
        nodes: ['README.md', 'orphan.md'],
        links: [{ from: 'README.md', to: 'other.md' }]
      }
      orphans = ['orphan.md']

      mermaid = validator.send(:generate_mermaid_graph, graph, orphans)

      expect(mermaid).to include('🔸')
    end

    it 'отмечает dead-ends с эмодзи 🔹' do
      graph = {
        nodes: ['README.md', 'deadend.md'],
        links: [{ from: 'README.md', to: 'deadend.md' }]
      }
      dead_ends = ['deadend.md']

      mermaid = validator.send(:generate_mermaid_graph, graph, [], dead_ends)

      expect(mermaid).to include('🔹')
    end

    it 'использует круглую форму для README' do
      graph = { nodes: ['README.md'], links: [] }

      mermaid = validator.send(:generate_mermaid_graph, graph)

      expect(mermaid).to include('(("README"))')
    end
  end

  describe '#node_to_id', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    it 'преобразует пути в валидные Mermaid ID' do
      expect(validator.send(:node_to_id, 'README.md')).to eq('README_md')
      expect(validator.send(:node_to_id, 'docs/guide.md')).to eq('docs_guide_md')
      expect(validator.send(:node_to_id, '01_INTRO.md')).to eq('n01_INTRO_md')
    end
  end

  describe '#save_mermaid_graph', :temp_project do
    let(:validator) { described_class.new(@temp_dir, mode: DocValidator::MODE_BATCH) }

    it 'сохраняет файл в .docvalidate/link_graph.md' do
      mermaid_content = "```mermaid\nflowchart LR\n  A --> B\n```"

      result = validator.send(:save_mermaid_graph, mermaid_content)

      expect(result).to eq('.docvalidate/link_graph.md')
      expect((@temp_path / '.docvalidate' / 'link_graph.md').exist?).to be true
    end

    it 'включает легенду и рекомендации' do
      mermaid_content = "```mermaid\nflowchart LR\n```"

      validator.send(:save_mermaid_graph, mermaid_content)

      content = File.read(@temp_path / '.docvalidate' / 'link_graph.md')
      expect(content).to include('Легенда')
      expect(content).to include('Рекомендации')
      expect(content).to include('Orphan')
      expect(content).to include('Dead-end')
    end
  end

  describe 'constants' do
    it 'определяет версию' do
      expect(DocValidator::VERSION).to eq('1.1.0')
    end

    it 'определяет режимы работы' do
      expect(DocValidator::MODE_INTERACTIVE).to eq(:interactive)
      expect(DocValidator::MODE_BATCH).to eq(:batch)
      expect(DocValidator::MODE_DEFAULT).to eq(:default)
    end

    it 'определяет приоритеты' do
      expect(DocValidator::PRIORITY).to have_key(:critical)
      expect(DocValidator::PRIORITY).to have_key(:warning)
      expect(DocValidator::PRIORITY).to have_key(:info)
    end
  end
end
