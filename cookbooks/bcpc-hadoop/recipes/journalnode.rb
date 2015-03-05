require 'base64'
include_recipe 'dpkg_autostart'
include_recipe 'bcpc-hadoop::hadoop_config'

%w{hadoop-hdfs-namenode }.each do |pkg|
  dpkg_autostart pkg do
    allow false
  end
  package pkg do
    action :upgrade
  end
end

if get_config("namenode_txn_fmt") then
  file "#{Chef::Config[:file_cache_path]}/nn_fmt.tgz" do
    user "hdfs"
    group "hdfs"
    user 0644
    content Base64.decode64(get_config("namenode_txn_fmt"))
    not_if { lazy { node[:bcpc][:hadoop][:mounts].all? { |d| File.exists?("/disk/#{d}/dfs/jn/#{node.chef_environment}/current/VERSION") } }.call }
  end
end

ruby_block "hadoop disks" do
  block do
    node[:bcpc][:hadoop][:mounts].each do |d|
      dir = Chef::Resource::Directory.new("/disk/#{d}/dfs/jn/", run_context)
      dir.owner "hdfs"
      dir.group "hdfs"
      dir.mode 0755
      dir.run_action :create
      dir.recursive true

      dir = Chef::Resource::Directory.new("/disk/#{d}/dfs/jn/#{node.chef_environment}", run_context)
      dir.owner "hdfs"
      dir.group "hdfs"
      dir.mode 0755
      dir.run_action :create
      dir.recursive true

      bash = Chef::Resource::Bash.new("unpack nn fmt image", run_context)
      bash.user "hdfs"
      bash.code ["pushd /disk/#{d}/dfs/",
                 "tar xzvf #{Chef::Config[:file_cache_path]}/nn_fmt.tgz",
                 "popd"].join("\n")
      bash.notifies :restart, "service[hadoop-hdfs-journalnode]", :delayed
      bash.only_if { not get_config("namenode_txn_fmt").nil? and not File.exists?("/disk/#{d}/dfs/jn/#{node.chef_environment}/current/VERSION") }
    end
  end
end

# need to ensure hdfs user is in hadoop and hdfs
# groups. Packages will not add hdfs if it
# is already created at install time (e.g. if
# machine is using LDAP for users).

# Create all the resources to add them in resource collection
node[:bcpc][:hadoop][:os][:group].keys.each do |group_name|
  node[:bcpc][:hadoop][:os][:group][group_name][:members].each do|user_name|
    user user_name do
      home "/var/lib/hadoop-#{user_name}"
      shell '/bin/bash'
      system true
      action :create
      not_if { user_exists?(user_name) }
    end
  end

  group group_name do
    append true
    members node[:bcpc][:hadoop][:os][:group][group_name][:members]
    action :nothing
  end
end
  
# Take action on each group resource based on its existence 
ruby_block 'create_or_manage_groups' do
  block do
    node[:bcpc][:hadoop][:os][:group].keys.each do |group_name|
      res = run_context.resource_collection.find("group[#{group_name}]")
      res.run_action(get_group_action(group_name))
    end
  end
end

template "hadoop-hdfs-journalnode" do
  path "/etc/init.d/hadoop-hdfs-journalnode"
  source "hdp_hadoop-hdfs-journalnode-initd.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :restart, "service[hadoop-hdfs-journalnode]"
end

service "hadoop-hdfs-journalnode" do
  action [:start, :enable]
  supports :status => true, :restart => true, :reload => false
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
  subscribes :restart, "template[/etc/hadoop/conf/hdfs-site_HA.xml]", :delayed
end
