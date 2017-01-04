# vim: tabstop=2:shiftwidth=2:softtabstop=2 
#
# Cookbook Name:: bcpc
# Recipe:: graphite
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
ruby_block "collect_properties_data" do
  block do
    chef_env = node.environemnt
    krb_realm = node[:bcpc][:hadoop][:kerberos][:realm]
    resource_managers = node[:bcpc][:hadoop][:rm_hosts].map do |rms| rms.hostname end 
    zookeper_quorum = node[:bcpc][:hadoop][:zookeeper][:servers].map do |zks| zks.hostname end
    fs = "hdfs://#{chef_env}"
    rm = if resource_managers.length > 1 then chef_env else resource_managers[0] end
    thrift_uris = node[:bcpc][:hadoop][:hive_hosts]
      .map { |s| float_host(s[:hostname]) + ":9083" }.join(",")
    node.run_state['smoke']['rm'] = rm
    node.run_state['smoke']['fs'] = fs
    node.run_state['smoke']['thrift_uris'] = thrift_uris
    node.run_state['smoke']['krb_realm'] = krb_realm
  end
end

template '/etc/hadoop/conf/oozie-smoke-test/workflow.xml' do
  source 'smoke_test_xml.erb'
end

template '/etc/hadoop/conf/oozie-smoke-test/smoke_test_job.properties' do
  source 'smoke_test_job_properties.erb'
  variables ( smoke: node.run_state['smoke'] )
end

ruby_block 'submit oozie smoke test' do
  block do
  end
end
 
