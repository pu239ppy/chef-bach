
#  Installing Hive & Hcatalog
#
include_recipe "bcpc-hadoop::hive_config"
include_recipe "bcpc-hadoop::hive_table_stat"
include_recipe 'bcpc-hadoop::mysql_connector'

::Chef::Recipe.send(:include, Bcpc_Hadoop::Helper)
::Chef::Resource::Bash.send(:include, Bcpc_Hadoop::Helper)

%w{hadooplzo hadooplzo-native hive-hcatalog}.map do |pp|
  hwx_pkg_str(pp, node[:bcpc][:hadoop][:distribution][:release])
end.each do |pkg|
  package pkg do
    action :upgrade
  end
end

(["hive-webhcat", "hive-metastore", "hive-server2"]).each do |pkg|
  hdp_select(pkg, node[:bcpc][:hadoop][:distribution][:active_release])
end

link '/usr/hdp/current/hive-client/lib/mysql-connector-java.jar' do
  to '/usr/share/java/mysql-connector-java.jar/mysql-connector-java.jar'
end

user_ulimit "hive" do
  filehandle_limit 65536
  process_limit 65536
end

configure_kerberos 'hive_spnego' do
  service_name 'spnego'
end

configure_kerberos 'hive_kerb' do
  service_name 'hive'
end

bash "create-hive-user-home" do
  code <<-EOH
  hdfs dfs -mkdir -p /user/hive
  hdfs dfs -chmod 1777 /user/hive
  hdfs dfs -chown hive:hdfs /user/hive
  EOH
  user 'hdfs'
end

bash 'create-hive-warehouse' do
  code <<-EOH
  hdfs dfs -mkdir -p #{node['bcpc']['hadoop']['hive']['warehouse']['dir']}
  hdfs dfs -chmod 777 #{node['bcpc']['hadoop']['hive']['warehouse']['dir']}
  hdfs dfs -chown hive:hdfs #{node['bcpc']['hadoop']['hive']['warehouse']['dir']}
  EOH
  user 'hdfs'
end

bash 'create-hive-scratch' do
  code <<-EOH
  hdfs dfs -mkdir -p #{node['bcpc']['hadoop']['hive']['scratch']['dir']}
  hdfs dfs -chmod -R 1777 #{node['bcpc']['hadoop']['hive']['scratch']['dir']}
  hdfs dfs -chown -R hive:hdfs #{node['bcpc']['hadoop']['hive']['scratch']['dir']}
  EOH
  user 'hdfs'
end

hive_metastore_database 'hive' do
  hive_password lazy { get_config 'mysql-hive-password' }
  root_password lazy { get_config! 'password', 'mysql-root', 'os' }
  schematool_path '/usr/hdp/current/hive-metastore/bin/schematool'
  action %w(create init upgrade)
  notifies :enable, "service[hive-metastore]", :delayed
end

template "/etc/init.d/hive-metastore" do
  source "hdp_hive-metastore-initd.erb"
  mode 0655
end

template "/etc/init.d/hive-server2" do
  source "hdp_hive-server2-initd.erb"
  mode 0655
end

directory "/var/log/hive/gc" do
  action :create
  mode 0755
  user "hive"
end

service "hive-metastore" do
  action [:enable, :start]
  subscribes :restart, "template[/etc/hive/conf/hive-site.xml]", :delayed
  subscribes :restart, "template[/etc/hive/conf/hive-log4j.properties]", :delayed
  subscribes :restart, "bash[hdp-select hive-metastore]", :delayed
  subscribes :restart, "directory[/var/log/hive/gc]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/core-site.xml]", :delayed
end

service "hive-server2" do
  action [:enable, :start]
  supports :status => true, :restart => true, :reload => false
  subscribes :restart, "bash[hdp-select hive-server2]", :delayed
  subscribes :restart, "template[/etc/hive/conf/hive-site.xml]", :delayed
  subscribes :restart, "template[/etc/hive/conf/hive-log4j.properties]", :delayed
  subscribes :restart, "directory[/var/log/hive/gc]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/core-site.xml]", :delayed
end
