# frozen_string_literal: true
require File.expand_path('../lib/speedy_af/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'speedy-af'
  s.version = SpeedyAF::VERSION

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['Michael B. Klein']
  s.description = 'Performance enhancements for ActiveFedora'
  s.email = 'mbklein@gmail.com'
  s.extra_rdoc_files = [
    'CONTRIBUTING.md',
    'README.md',
    'LICENSE'
  ]
  s.homepage = 'http://github.com/samvera-labs/speedy_af'
  s.licenses = 'APACHE2'
  s.require_paths = ['lib']
  s.rubygems_version = '1.5.2'
  s.summary = 'Performance enhancements for ActiveFedora'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")

  s.add_dependency 'active-fedora', '>= 11.0.0'
  s.add_dependency 'activesupport', '> 5.2', '< 6.1'
  s.add_development_dependency 'solr_wrapper'
  s.add_development_dependency 'fcrepo_wrapper'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'rspec_junit_formatter'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'bixby'
end
