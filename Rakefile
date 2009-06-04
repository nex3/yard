require File.dirname(__FILE__) + '/lib/yard'
require 'rubygems'
require 'rake/gempackagetask'
require 'spec'
require 'spec/rake/spectask'

WINDOWS = (PLATFORM =~ /win32|cygwin/ ? true : false) rescue false
SUDO = WINDOWS ? '' : 'sudo'

task :default => :specs

load 'yard.gemspec'
Rake::GemPackageTask.new(SPEC) do |pkg|
  pkg.gem_spec = SPEC
  pkg.need_zip = true
  pkg.need_tar = true
end

desc "Install the gem locally"
task :install => :package do 
  sh "#{SUDO} gem install pkg/#{SPEC.name}-#{SPEC.version}.gem --local"
  sh "rm -rf pkg/yard-#{SPEC.version}" unless ENV['KEEP_FILES']
end

desc "Run all specs"
Spec::Rake::SpecTask.new("specs") do |t|
  $DEBUG = true if ENV['DEBUG']
  t.spec_opts = ["--format", "specdoc", "--colour"]
  t.spec_files = Dir["spec/**/*_spec.rb"].sort
  t.rcov = true
  t.rcov_opts = ['-x', '_spec\.rb$,spec_helper\.rb$']
end

YARD::Rake::YardocTask.new do |t|
  extra_files = %w(docs/WHATSNEW.markdown docs/OVERVIEW.markdown
    docs/CODE_OBJECTS.markdown docs/PARSER.markdown docs/FAQ.markdown 
    docs/GLOSSARY.markdown LICENSE)
  t.options = ["--files", extra_files.join(",")]
  t.after = lambda { `cp -R docs/images/ doc/images/` }
end