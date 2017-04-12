# vim: tabstop=2:shiftwidth=2:softtabstop=2 
#
# Cookbook Name:: bcpc-hadoop
# Recipe:: smoke_test_principal
#
# Copyright 2016, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'base64'
require 'tempfile'

test_user = node['hadoop_smoke_tests']['oozie_user']
test_user_password = get_config('password', 'test_user_password', 'os') 
test_user_keytab = get_config('keytab', 'test_user_keytab', 'os')
  
ruby_block "create test_user_password" do
  block do
    if test_user_password == nil then
      node['run_state']['tests_user_password'] = secure_password
    end
  end
  only_if { test_user_password == nil }
  notifies :run, 'chef_vault_secret[test_user_password]', :immidiately
end

chef_vault_secret 'test_user_password' do
  provider ChefVaultCookbook::Provider::ChefVaultSecret
  data_bag 'os'
  raw_data({ 'password' => test_user_password })
  search '*:*'
  notifies :run, "execute[create #{test_user} principal]", :immidiately
  action :nothing
end

execute "create #{test_user} principal" do
  command "kadmin.local -q 'add_principal #{test_user} -pw #{test_user_password}'"
  notifies :run, 'ruby_block[create temp file keytab]', :immidiately
  action :nothing
end

ruby_block "create temp file keytab"  do 
  block do
    tmpfile = Tempfile.new(test_user)
    node['run_state']['test_user_keytab_file'] = tmpfile.path
    tmpfile.close
  end
  action :nothing
  notifies :run, "execute[dump keytab for #{test_user}]", :immidiately
end
    
execute "dump keytab for #{test_user}" do
  command "kadmin.local -q 'ktadd -k #{node['run_state']['test_user_keytab_file']} -norandkey #{test_user}'"
  action :nothing
  notifies :run, 'chef_vault_secret[test_user_keytab]', :immidiately
end

chef_vault_secret 'test_user_keytab' do
  provider ChefVaultCookbook::Provider::ChefVaultSecret
  data_bag 'os'
  raw_data ({ 'keytab' => Base64.encode64(File.open(node['run_state']['test_user_keytab_file'])) })
  search '*:*'
  action :nothing
  notifies :run, 'ruby_block[delete templ file keytab]', :immidiately
end

ruby_block "delete temp file keytab" do
  block do
    File.unlink(node['run_state']['test_user_keytab_file'])
  end
  action :nothing
end
