require 'solr_wrapper'
require 'fcrepo_wrapper'
require 'active_fedora/rake_support'

require 'rspec/core/rake_task'
desc 'Run tests only'
RSpec::Core::RakeTask.new(:rspec) do |spec|
  spec.rspec_opts = ['--backtrace'] if ENV['CI']
end

require 'rubocop/rake_task'
desc 'Run style checker'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.requires << 'rubocop-rspec'
  task.fail_on_error = true
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.rcov = true
end

desc "CI build"
task :ci do
  Rake::Task['rubocop'].invoke unless ENV['NO_RUBOCOP']
  ENV['environment'] = "test"
  with_test_server do
    Rake::Task[:coverage].invoke
  end
end

desc "Execute specs with coverage"
task :coverage do
  # Put spec opts in a file named .rspec in root
  ruby_engine = defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"
  ENV['COVERAGE'] = 'true' unless ruby_engine == 'jruby'
  Rake::Task[:spec].invoke
end

desc "Execute specs with coverage"
task :spec do
  with_test_server do
    Rake::Task[:rspec].invoke
  end
end

task default: :ci
