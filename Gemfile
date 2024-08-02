# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

major, minor, patch = RUBY_VERSION.split('.')
major = major.to_i
minor = minor.to_i
patch = patch.to_i


if major == 3 && minor >= 1   
    gem 'activerecord', '~> 6.0', '>= 6.0.3.3'
    gem 'sqlite3', '~> 1.4'                                             
    gem 'activerecord-import', '~> 1.4', '>= 1.4.1'
    gem 'bio', '~> 2.0'
    gem 'rubyzip', '~> 2.3.0'
    gem 'rubytree', '~> 2.0'
    gem 'parallel', '~> 1.19', '>= 1.19.2'
    gem 'pastel', '= 0.8.0'
    gem 'rexml', '~> 3.3'
    gem 'biodiversity', '~> 5.1', '>= 5.1.2', '< 5.2'
    gem 'countries', '~> 1.2', '>= 1.2.5'
    gem 'geokit', '~> 1.13', '>= 1.13.1'
    gem 'shp', '= 0.1.0'
    gem 'net-ftp', '= 0.3.7'

    if minor >= 3
        gem 'mutex_m', '~> 0.2.0' # Also contact author of activesupport-6.1.7.8 to add mutex_m into its gemspec.
        gem 'base64', '~> 0.2.0' # Also contact author of activesupport-6.1.7.8 to add mutex_m into its gemspec.
        gem 'bigdecimal', '~> 3.1', '>= 3.1.8' # Also contact author of activesupport-6.1.7.8 to add mutex_m into its gemspec.
        gem 'csv', '~> 3.3'
        gem 'resolv-replace', '~> 0.1.1'
    end
else
    gem 'activerecord', '~> 6.0', '>= 6.0.3.3'
    gem 'sqlite3', '~> 1.4' 
    gem 'activerecord-import', '~> 1.4', '>= 1.4.1'
    gem 'bio', '~> 2.0'
    gem 'rubyzip', '~> 2.3'
    gem 'rubytree', '~> 2.0'
    gem 'parallel', '~> 1.19', '>= 1.19.2'
    gem 'pastel', '= 0.8.0'
    gem 'rexml', '~> 3.3'
    gem 'biodiversity', '~> 5.1', '>= 5.1.2', '< 5.2'
    gem 'countries', '~> 1.2', '>= 1.2.5'
    gem 'geokit', '~> 1.13', '>= 1.13.1'
    gem 'shp', '= 0.1.0'
end

group :dev do
    gem 'test-unit'
    gem 'byebug'
end

