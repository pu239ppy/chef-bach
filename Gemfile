# -*- mode: enh-ruby -*-
ruby RUBY_VERSION
# These versions are pinned to match ChefDK
if File.exist?('/opt/chefdk/Gemfile')
  # overload the path so we do not re-cache these gems
    opscode_gem_data = IO.read("/opt/chefdk/Gemfile")
    # strip off a Gem from a Git repo as it seems to confuse things
    opscode_gem_data.gsub!(/^gem.*opscode-pushy-client.*\n/,'')
    instance_eval(opscode_gem_data, "/opt/chefdk/Gemfile")
elsif File.exist?('/opt/chef/Gemfile')
  # overload the path so we do not re-cache these gems
    opscode_gem_data = IO.read("/opt/chef/Gemfile")
    instance_eval(opscode_gem_data, "/opt/chef/Gemfile")
else
  source 'https://rubygems.org' do
    gem 'faraday'
    gem 'parallel'
    gem 'chef-vault'
    gem 'ipaddress'
    gem 'highline'
    gem 'mixlib-shellout'
    gem 'chef-provisioning'
    gem 'rack'
    gem 'buff-extensions'
    gem 'buff-ruby_engine'
    gem 'chef'
    gem 'fauxhai'
    gem 'nio4r'
    gem 'json'
  end
end

gem 'fpm'
gem 'cluster_data', :path => 'lib/cluster-data-gem/lib'

source 'https://rubygems.org' do
  gem 'faker'
  gem 'poise'

  # We rely on chef-provisioning to monitor hosts on SSH.
  gem 'chef-provisioning-ssh'
  gem 'ridley'
  gem 'hashie'
  gem 'pry'
  gem 'ruby-progressbar'
end

# Pull in the other Gemfiles from our cookbooks
Dir.glob(File.join(File.dirname(__FILE__), 'cookbooks',
    '**', "Gemfile")) do |gemfile|
  eval(IO.read(gemfile), binding)
end
