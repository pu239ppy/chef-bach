# vim: tabstop=2:shiftwidth=2:softtabstop=2 
#
# Cookbook Name:: smoke-test
# Recipe:: oozie_smoke_test
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
# Collect all we need to generate a job.properties
# This will need to eventually be decoupled from bcpc-hadop

test_user = node[:hadoop_smoke_tests][:oozie_user]
test_user_home = node[:hadoop_smoke_tests][:home_path]
workflow_path = "#{test_user_home}/#{node[:hadoop_smoke_tests][:hdfs_wf_path]}"

ruby_block "collect_properties_data" do
  block do
    chef_env = node.environemnt
    krb_realm = node[:bcpc][:hadoop][:kerberos][:realm]
    resource_managers = node[:bcpc][:hadoop][:rm_hosts].map do |rms| rms.hostname end 
    zookeeper_quorum = node[:bcpc][:hadoop][:zookeeper][:servers].map do |zks| zks.hostname end
    fs = "hdfs://#{chef_env}"
    rm = if resource_managers.length > 1 then chef_env else resource_managers[0] end
    thrift_uris = node[:bcpc][:hadoop][:hive_hosts]
      .map { |s| float_host(s[:hostname]) + ":9083" }.join(",")
    node.run_state['smoke']['rm'] = rm
    node.run_state['smoke']['fs'] = fs
    node.run_state['smoke']['thrift_uris'] = thrift_uris
    node.run_state['smoke']['krb_realm'] = krb_realm
    node.run_state['smoke']['zk_quorum'] = zookeeper_quorum
  end
end

template "#{Chef::Config['file_cache_path']}/oozie-smoke-test/workflow.xml" do
  source 'smoke_test_xml.erb'
end

template "#{Chef::Config['file_cache_path']}/oozie-smoke-test/smoke_test_job.properties" do
  source 'smoke_test_job_properties.erb'
  variables ( {smoke: node.run_state['smoke']} )
end

execute "create HDFS workflow path #{workflow_path}" do
  command "hdfs dfs -mkdir -p #{workflow_path} "\
    && "hdfs dfs -chown -r #{test_user} #{workflow_path}"
  user 'hdfs'
  not_if "hdfs dfs -test #{workflow_path}"
end

execute "upload workflow to #{workflow_path}" do
  command "hdfs dfs -copyFromLocal #{Chef::Config['file_cache_path']}/oozie-smoke-test/smoke_test_job.properties #{workflow_path}" 
  user test_user
end

ruby_block 'submit oozie smoke test' do
  block do
    submit_workflow_running_host("#{Chef::Config['file_cache_path']}/oozie-smoke-test/smoke_test_job.properties")
  end
  user test_user
end
