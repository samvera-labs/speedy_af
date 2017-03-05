ENV['environment'] ||= 'test'
require 'bundler/setup'

require 'simplecov'
require 'coveralls'

SimpleCov.start do
  add_filter '/spec/'
end

require 'active-fedora'
require 'active_fedora/performance'
require 'rspec'
require 'rspec/its'

require 'active_fedora/cleaner'
RSpec.configure do |config|
  # Stub out test stuff.
  config.before(:each) do
    begin
      ActiveFedora::Cleaner.clean!
    rescue Faraday::ConnectionFailed, RSolr::Error::ConnectionRefused => e
      $stderr.puts e.message
    end
  end
end

def load_fixture_classes!
  load File.expand_path('../fixture_classes.rb', __FILE__)
end

def unload_fixture_classes!
  Object.send(:remove_const, :Book)
  Object.send(:remove_const, :Chapter)
end
