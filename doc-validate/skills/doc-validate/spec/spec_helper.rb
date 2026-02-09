# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'pathname'

# Загружаем тестируемый класс
require_relative '../doc_validate'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/.rspec_status'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end

# Хелпер для создания временного проекта
module TempProjectHelper
  def create_temp_project
    @temp_dir = Dir.mktmpdir('doc_validate_test')
    @temp_path = Pathname.new(@temp_dir)
  end

  def cleanup_temp_project
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def write_file(relative_path, content)
    full_path = @temp_path / relative_path
    FileUtils.mkdir_p(full_path.dirname)
    File.write(full_path, content)
  end

  def write_config(config_hash)
    write_file('.docvalidate.yml', YAML.dump(config_hash))
  end
end

RSpec.configure do |config|
  config.include TempProjectHelper

  config.before(:each) do |example|
    if example.metadata[:temp_project]
      create_temp_project
    end
  end

  config.after(:each) do |example|
    if example.metadata[:temp_project]
      cleanup_temp_project
    end
  end
end
