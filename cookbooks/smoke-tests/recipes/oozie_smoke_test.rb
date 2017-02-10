# vim: tabstop=2:shiftwidth=2:softtabstop=2 
#
# Cookbook Name:: hadoop-smoke-tests
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

test_user = node['hadoop_smoke_tests']['oozie_user']
workflow_path = node['hadoop_smoke_tests']['wf_path']
coordinator_path = node['hadoop_smoke_tests']['co_path']
 
#ruby_block "collect_properties_data" do
#  block do
#    chef_env = node.environment
#    krb_realm = node[:bcpc][:hadoop][:kerberos][:realm]
#    resource_managers = node[:bcpc][:hadoop][:rm_hosts].map do |rms| float_host(rms.hostname) end
#    zookeeper_quorum = node[:bcpc][:hadoop][:zookeeper][:servers].map do |zks| float_host(zks.hostname) end
#    fs = "hdfs://#{chef_env}"
#    rm = if resource_managers.length > 1 then chef_env else resource_managers[0] end
#    thrift_uris = node[:bcpc][:hadoop][:hive_hosts]
#      .map { |s| 'thrift://' + float_host(s[:hostname]) + ':9083' }.join(",")
#    node.run_state['smoke'] = {}
#    node.run_state['smoke']['wf_path'] = workflow_path
#    node.run_state['smoke']['rm'] = rm
#    node.run_state['smoke']['fs'] = fs
#    node.run_state['smoke']['thrift_uris'] = thrift_uris
#    node.run_state['smoke']['krb_realm'] = krb_realm
#    node.run_state['smoke']['zk_quorum'] = zookeeper_quorum.join(",")
#  end
#end

directory "#{Chef::Config['file_cache_path']}/oozie-smoke-test" do
end

template "#{Chef::Config['file_cache_path']}/oozie-smoke-test/workflow.xml" do
  source 'smoke_test_xml.erb'
end

file "#{Chef::Config['file_cache_path']}/oozie-smoke-test/smoke_test_coordinator.props" do
  content "oozie.coord.application.path=#{node['hadoop_smoke_tests']['co_path']}"
end

template "#{Chef::Config['file_cache_path']}/oozie-smoke-test/coordinator.xml" do
  source 'coordinator.xml.erb'
  variables ( {
                appname: 'Oozie-Smoke-Test-Coordinator',
                properties: node['hadoop_smoke_tests']['wf'],
                workflow: workflow_path,
                frequency: '${coord:minutes(10)}'
              } )
end

execute "create HDFS coordinator path #{coordinator_path}" do
  command "hdfs dfs -mkdir -p #{coordinator_path}"
  user ubuntu
  not_if "hdfs dfs -test #{coordinator_path}"
end

execute "create HDFS workflow path #{workflow_path}" do
  command "hdfs dfs -mkdir -p #{workflow_path}"
  user ubuntu
  not_if "hdfs dfs -test #{workflow_path}"
end

execute "upload coordinator to #{coordinator_path}" do
  command "hdfs dfs -copyFromLocal -f #{Chef::Config['file_cache_path']}/oozie-smoke-test/coordinator.xml #{workflow_path}" 
  user test_user
end

execute "upload workflow to #{workflow_path}" do
  command "hdfs dfs -copyFromLocal -f #{Chef::Config['file_cache_path']}/oozie-smoke-test/workflow.xml #{workflow_path}" 
  user test_user
end

Chef::Resource::RubyBlock.send(:include, HadoopSmokeTests::OozieHelper)

ruby_block 'submit oozie smoke test' do
  block do
    submit_workflow_running_host(test_user, "#{Chef::Config['file_cache_path']}/oozie-smoke-test/smoke_test_job.properties")
  end
end
