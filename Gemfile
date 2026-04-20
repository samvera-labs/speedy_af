# frozen_string_literal: true
source 'https://rubygems.org'

gemspec

gem 'byebug'
gem 'pry-byebug' unless ENV['CI']
gem 'psych', '< 4' # pinned to less than 4 due to ActiveFedora not specifying this restriction

# Workaround faraday and rdf issue in CI and dev environments
gem 'faraday', '>= 2.9.2'
gem 'rdf', '>= 3.3.2'
