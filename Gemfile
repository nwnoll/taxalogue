# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

major, minor, patch = RUBY_VERSION.split('.')
major = major.to_i
minor = minor.to_i
patch = patch.to_i


if major == 3 && minor >= 1   
    gem 'activerecord'                                        
    gem 'sqlite3'                                             
    gem 'activerecord-import'                                 
    gem 'bio'                                                 
    gem 'fuzzy-string-match'
    gem 'byebug'         
    gem 'rubyzip', '~> 2.3.0'
    gem 'rubytree', '~> 2.0'
    gem 'parallel'
    gem 'pastel'
    gem 'test-unit'
    gem 'rexml'
    gem 'biodiversity'
    gem 'countries', '~> 1.2', '>= 1.2.5'
    gem 'geokit'
    gem 'shp'
    gem 'net-ftp'
else
    gem 'activerecord', '~> 6.0', '>= 6.0.3.3'
    gem 'sqlite3'
    gem 'activerecord-import'
    gem 'bio'
    gem 'fuzzy-string-match', '~> 0.9.7'
    gem 'byebug'
    gem 'rubyzip', '~> 2.3'
    gem 'rubytree', '~> 2.0'
    gem 'parallel', '~> 1.19', '>= 1.19.2'
    gem 'pastel', '~> 0.8.0'
    gem 'test-unit'
    gem 'rexml', '~> 3.2', '>= 3.2.4'
    gem 'biodiversity', '~5.1', '>= 5.1.2', '< 5.2'
    gem 'countries', '~> 1.2', '>= 1.2.5'
    gem 'geokit', '~> 1.13', '>= 1.13.1'
    gem 'shp'
end
