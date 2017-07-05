#
# Cookbook Name:: bcpc
# Library:: utils
#
# Copyright 2013, Bloomberg Finance L.P.
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

require 'openssl'
require 'thread'

#
# Constant string which defines the default attributes which need to be retrieved from node objects
# The format is hash { key => value , key => value }
# Key will be used as the key in the search result which is a hash and the value is the node attribute which needs
# to be included in the result. Attribute hierarchy can be expressed as a dot seperated string. User the following
# as an example
#

# For Kerberos to work we need FQDN for each host. Changing "HOSTNAME" to "FQDN".
# Hadoop breaks principal into 3 parts  (Service, FQDN and REALM)

HOSTNAME_ATTR_SRCH_KEYS = {'hostname' => 'fqdn'}
HOSTNAME_NODENO_ATTR_SRCH_KEYS = {'hostname' => 'fqdn',
                                  'node_number' => 'bcpc.node_number',
                                  'zookeeper_myid' => 'bcpc.hadoop.zookeeper.myid'}
MGMT_IP_ATTR_SRCH_KEYS = {'mgmt_ip' => 'bcpc.management.ip'}

def init_config
  if not Chef::DataBag.list.key?('configs')
     puts "************ Creating data_bag \"configs\""
     bag = Chef::DataBag.new
     bag.name("configs")
     bag.create
  end rescue nil
  begin
     $dbi = Chef::DataBagItem.load('configs', node.chef_environment)
     $edbi = Chef::EncryptedDataBagItem.load('configs', node.chef_environment) if node['bcpc']['encrypt_data_bag']
     puts "============ Loaded existing data_bag_item \"configs/#{node.chef_environment}\""
  rescue
     $dbi = Chef::DataBagItem.new
     $dbi.data_bag('configs')
     $dbi.raw_data = { 'id' => node.chef_environment }
     $dbi.save
     $edbi = Chef::EncryptedDataBagItem.load('configs', node.chef_environment) if node['bcpc']['encrypt_data_bag']
     puts "++++++++++++ Created new data_bag_item \"configs/#{node.chef_environment}\""
  end
end

def make_config(key, value)
  init_config if $dbi.nil?
  if $dbi[key].nil?
    $dbi[key] = (node['bcpc']['encrypt_data_bag'] ? Chef::EncryptedDataBagItem.encrypt_value(value, Chef::EncryptedDataBagItem.load_secret) : value)
    $dbi.save
    $edbi = Chef::EncryptedDataBagItem.load('configs', node.chef_environment) if node['bcpc']['encrypt_data_bag']
    puts "++++++++++++ Creating new item with key \"#{key}\""
    return value
  else
    puts "============ Loaded existing item with key \"#{key}\""
    return (node['bcpc']['encrypt_data_bag'] ? $edbi[key] : $dbi[key])
  end
end

def make_config!(key, value)
  init_config if $dbi.nil?
  $dbi[key] = (node['bcpc']['encrypt_data_bag'] ? Chef::EncryptedDataBagItem.encrypt_value(value, Chef::EncryptedDataBagItem.load_secret) : value)
  $dbi.save
  $edbi = Chef::EncryptedDataBagItem.load('configs', node.chef_environment) if node['bcpc']['encrypt_data_bag']
  puts "++++++++++++ Updating existing item with key \"#{key}\""
  return value
end

def get_hadoop_heads
  #results = Chef::Search::Query.new.search(:node, "role:BCPC-Hadoop-Head AND chef_environment:#{node.chef_environment}").first
  results = BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Head]" }
  if results.any?{|x| x['hostname'] == node[:hostname]}
    results.map!{|x| x['hostname'] == node[:hostname] ? node : x}
  else
    results.push(node) if node[:roles].include? "BCPC-Hadoop-Head"
  end
  return results.sort
end

def get_quorum_hosts
  #results = Chef::Search::Query.new.search(:node, "(roles:BCPC-Hadoop-Quorumnode or role:BCPC-Hadoop-Head) AND chef_environment:#{node.chef_environment}").first
  results = BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Quorumnode]" or hst[:runlist].include? "role[BCPC-Hadoop-Head]" }
  if results.any?{|x| x['hostname'] == node[:hostname]}
    results.map!{|x| x['hostname'] == node[:hostname] ? node : x}
  else
    results.push(node) if node[:roles].include? "BCPC-Hadoop-Quorumnode"
  end
  return results.sort
end

def get_hadoop_workers
  #results = Chef::Search::Query.new.search(:node, "role:BCPC-Hadoop-Worker AND chef_environment:#{node.chef_environment}").first
  results = BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Worker]" }
  if results.any?{|x| x['hostname'] == node[:hostname]}
    results.map!{|x| x['hostname'] == node[:hostname] ? node : x}
  else
    results.push(node) if node[:roles].include? "BCPC-Hadoop-Worker"
  end
  return results.sort
end

def get_namenodes()
  # Logic to get all namenodes if running in HA
  # or to get only the master namenode if not running in HA
  if node['bcpc']['hadoop']['hdfs']['HA']
    #nnrole = Chef::Search::Query.new.search(:node, "role:BCPC-Hadoop-Head-Namenode* AND chef_environment:#{node.chef_environment}").first
    #nnroles = Chef::Search::Query.new.search(:node, "roles:BCPC-Hadoop-Head-Namenode* AND chef_environment:#{node.chef_environment}").first
    #nn_hosts = nnrole.concat nnroles
    nn_hosts = BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Head-Namenode]" or hst[:runlist].include? "role[BCPC-Hadoop-Head-Namenode-Standby]" }
  else
    #nn_hosts = get_nodes_for("namenode_no_HA")
    nn_hosts = BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Head-Namenode-NoHA]" }
  end
  return nn_hosts.uniq{ |x| float_host(x[:hostname]) }.sort
end

def get_nodes_for(recipe, cookbook=cookbook_name)
  results = Chef::Search::Query.new.search(:node, "recipes:#{cookbook}\\:\\:#{recipe} AND chef_environment:#{node.chef_environment}").first
  results.map!{ |x| x['hostname'] == node[:hostname] ? node : x }
  if node.run_list.expand(node.chef_environment).recipes.include?("#{cookbook}::#{recipe}") and not results.include?(node)
    results.push(node)
  end
  return results.sort
end

def get_binary_server_url
  return("http://#{URI(Chef::Config['chef_server_url']).host}/") if node[:bcpc][:binary_server_url].nil?
  return(node[:bcpc][:binary_server_url])
end

def secure_password(len=20)
  pw = String.new
  while pw.length < len
    pw << ::OpenSSL::Random.random_bytes(1).gsub(/\W/, '')
  end
  pw
end

def float_host(*args)
  if node[:bcpc][:management][:ip] != node[:bcpc][:floating][:ip]
    return ("f-" + args.join('.'))
  else
    return args.join('.')
  end
end

def storage_host(*args)
  if node[:bcpc][:management][:ip] != node[:bcpc][:floating][:ip]
    return ("s-" + args.join('.'))
  else
    return args.join('.')
  end
end

def znode_exists?(znode_path, zk_host="localhost:2181")
  require 'rubygems'
  require 'zookeeper'
  znode_found = false
  begin
    zk = Zookeeper.new(zk_host)
    if !zk.connected?
      raise "znode_exists : Unable to connect to zookeeper quorum #{zk_host}"
    end
    r = zk.get(:path => znode_path)
    if r[:rc] == 0
      znode_found = true
    end
  rescue Exception => e
    puts e.message
  ensure
    if !zk.nil?
      zk.close unless zk.closed?
    end
  end
  return znode_found
end

#
# Function to retrieve commonly used node attributes so that the call to chef server is minimized
#
def set_hosts
  #node.default[:bcpc][:hadoop][:zookeeper][:servers] = get_node_attributes(HOSTNAME_NODENO_ATTR_SRCH_KEYS,"zookeeper_server","bcpc-hadoop")
  # every head is a zookeeper server
  node.default[:bcpc][:hadoop][:zookeeper][:servers] = 
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Head]" }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain], 'node_number' => hst[:node_id], 'zookeeper_myid' => nil } }

  #node.default[:bcpc][:hadoop][:jn_hosts] = get_node_attributes(HOSTNAME_ATTR_SRCH_KEYS,"journalnode","bcpc-hadoop")
  # Every head is a journal node
  node.default[:bcpc][:hadoop][:jn_hosts] = 
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Head]" }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain]} }

  #node.default[:bcpc][:hadoop][:rm_hosts] = get_node_attributes(HOSTNAME_NODENO_ATTR_SRCH_KEYS,"resource_manager","bcpc-hadoop")
  node.default[:bcpc][:hadoop][:rm_hosts] = 
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Head-ResourceManager]" }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain], 'node_number' => hst[:node_id], 'zookeeper_myid' => nil } }

  #node.default[:bcpc][:hadoop][:hs_hosts] = get_node_attributes(HOSTNAME_ATTR_SRCH_KEYS,"historyserver","bcpc-hadoop")
  # BCPC-Hadoop-Head-MapReduce
  node.default[:bcpc][:hadoop][:hs_hosts] = 
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Head-MapReduce]" }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain]} }

  #node.default[:bcpc][:hadoop][:dn_hosts] = get_node_attributes(HOSTNAME_ATTR_SRCH_KEYS,"datanode","bcpc-hadoop")
  # every BCPC-Hadoop-Worker is a datanode
  node.default[:bcpc][:hadoop][:dn_hosts] = 
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Worker]" }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain]} }

  #node.default[:bcpc][:hadoop][:hb_hosts] = get_node_attributes(HOSTNAME_ATTR_SRCH_KEYS,"hbase_master","bcpc-hadoop")
  # Misnomer that really menas region servers every BCPC-Hadoop-Head-HBase is a hbase region server
  node.default[:bcpc][:hadoop][:hb_hosts] = 
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Head-HBase]" }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain]} }

  #node.default[:bcpc][:hadoop][:hive_hosts] = get_node_attributes(HOSTNAME_ATTR_SRCH_KEYS,"hive_hcatalog","bcpc-hadoop")
  # different flavors of hive
  node.default[:bcpc][:hadoop][:hive_hosts] = 
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist] =~ /role\[BCPC-Hadoop-Hive/ }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain]} }

  #node.default[:bcpc][:hadoop][:oozie_hosts]  = get_node_attributes(HOSTNAME_ATTR_SRCH_KEYS,"oozie","bcpc-hadoop")
  # BCPC-Hadoop-Head-MapReduce
  node.default[:bcpc][:hadoop][:oozie_hosts]  = 
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Head-MapReduce]" }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain]} }
  
  #node.default[:bcpc][:hadoop][:httpfs_hosts] = get_node_attributes(HOSTNAME_ATTR_SRCH_KEYS,"httpfs","bcpc-hadoop")
  # every datanode
  node.default[:bcpc][:hadoop][:httpfs_hosts] = 
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Worker]" }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain]} }

  #node.default[:bcpc][:hadoop][:rs_hosts] = get_node_attributes(HOSTNAME_ATTR_SRCH_KEYS,"region_server","bcpc-hadoop")
  # Worker
  node.default[:bcpc][:hadoop][:rs_hosts] = get_node_attributes(HOSTNAME_ATTR_SRCH_KEYS,"region_server","bcpc-hadoop")
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Worker]" }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain]} }

  #node.default[:bcpc][:hadoop][:mysql_hosts] = get_node_attributes(HOSTNAME_ATTR_SRCH_KEYS,"mysql","bcpc")
  # BCPC-Hadoop-Head
  node.default[:bcpc][:hadoop][:mysql_hosts] = 
      BACH::ClusterData.fetch_cluster_def.select { |hst| hst[:runlist].include? "role[BCPC-Hadoop-Head]" }.map {
        |hst| { 'hostname' => hst[:hostname] + hst[:dns_domain]} }
end

#
# Restarting of hadoop processes need to be controlled in a way that all the nodes
# are not down at the sametime, the consequence of which will impact users. In order
# to achieve this, nodes need to acquire a lock before restarting the process of interest.
# This function is to acquire the lock which is a znode in zookeeper. The znode name is the name
# of the service to be restarted for e.g "hadoop-hdfs-datanode" and is located by default at "/".
# The imput parameters are service name along with the ZK path (znode name), string of zookeeper
# servers ("zk_host1:port,sk_host2:port"), and the fqdn of the node acquiring the lock
# Return value : true or false
#
def acquire_restart_lock(znode_path, zk_hosts="localhost:2181",node_name)
  require 'zookeeper'
  lock_acquired = false
  zk = nil
  begin
    zk = Zookeeper.new(zk_hosts)
    if !zk.connected?
      raise "acquire_restart_lock : unable to connect to ZooKeeper quorum #{zk_hosts}"
    end
    ret = zk.create(:path => znode_path, :data => node_name)
    if ret[:rc] == 0
      lock_acquired = true
    end
  rescue Exception => e
    puts e.message
  ensure
    if !zk.nil?
      zk.close unless zk.closed?
    end
  end
  return lock_acquired
end

#
# This function is to check whether the lock to restart a particular service is held by a node.
# The input parameters are the path to the znode used to restart a hadoop service, a string containing the
# host port values of the ZooKeeper nodes "host1:port, host2:port" and the fqdn of the host
# Return value : true or false
#
def my_restart_lock?(znode_path,zk_hosts="localhost:2181",node_name)
  require 'zookeeper'
  my_lock = false
  zk = nil
  begin
    zk = Zookeeper.new(zk_hosts)
    if !zk.connected?
      raise "my_restart_lock?: unable to connect to ZooKeeper quorum #{zk_hosts}"
    end
    ret = zk.get(:path => znode_path)
    val = ret[:data]
    if val == node_name
      my_lock = true
    end
  rescue Exception => e
    puts e.message
  ensure
    if !zk.nil?
      zk.close unless zk.closed?
    end
  end
  return my_lock
end

#
# Function to release the lock held by the node to restart a particular hadoop service
# The input parameters are the name of the path to znode which was used to lock for restarting service,
# string containing the zookeeper host and port ("host1:port,host2:port") and the fqdn
# of the node trying to release the lock.
# Return value : true or false based on whether the lock release was successful or not
#
def rel_restart_lock(znode_path, zk_hosts="localhost:2181",node_name)
  require 'zookeeper'
  lock_released = false
  zk = nil
  begin
    zk = Zookeeper.new(zk_hosts)
    if !zk.connected?
      raise "rel_restart_lock : unable to connect to ZooKeeperi quorum #{zk_hosts}"
    end
    if my_restart_lock?(znode_path, zk_hosts, node_name)
      ret = zk.delete(:path => znode_path)
    else
      raise "rel_restart_lock : node who is not the owner is trying to release the lock"
    end
    if ret[:rc] == 0
      lock_released = true
    end
  rescue Exception => e
    puts e.message
  ensure
    if !zk.nil?
      zk.close unless zk.closed?
    end
  end
  return lock_released
end

#
# Function to get the node name which is holding a particular service restart lock
# Input parameters: The path to the znode (lock) and the string of zookeeper hosts:port
# Return value    : The fqdn of the node which created the znode to restart or nil
#
def get_restart_lock_holder(znode_path, zk_hosts="localhost:2181")
  require 'zookeeper'
  begin
    zk = Zookeeper.new(zk_hosts)
    if !zk.connected?
      raise "get_restart_lock_holder : unable to connect to ZooKeeper quorum #{zk_hosts}"
    end
    ret = zk.get(:path => znode_path)
    if ret[:rc] == 0
      val = ret[:data]
    end
  rescue Exception => e
    puts e.message
  ensure
    if !zk.nil?
      zk.close unless zk.closed?
    end
  end
  return val
end


#
# Function to generate the full path of znode which will be used to create a restart lock znode
# Input paramaters: The path in ZK where znodes are created for the retart locks and the lock name
# Return value    : Fully formed path which can be used to create the znode
#
def format_restart_lock_path(root, lock_name)
  begin
    if root.nil?
      return "/#{lock_name}"
    elsif root == "/"
      return "/#{lock_name}"
    else
      return "#{root}/#{lock_name}"
    end
  end
end
#
# Function to identify start time of a process
# Input paramater: string to identify the process through pgrep command
# Returned value : The starttime for the process. If multiple instances are returned from pgrep
# command, time returned will be the earliest time of all the instances
#
def process_start_time(process_identifier)
  require 'time'
  begin
    target_process_pid = `pgrep -f #{process_identifier}`
    if target_process_pid == ""
      return nil
    else
      target_process_pid_arr = Array.new()
      target_process_pid_arr = target_process_pid.split("\n").map{|pid| (`ps --no-header -o lstart #{pid}`).strip}
      start_time_arr = Array.new()
      target_process_pid_arr.each do |t|
        if t != ""
          start_time_arr.push(Time.parse(t))
        end
      end
      return start_time_arr.sort.first.to_s
    end
  end
end
#
# Function to check whether a process was started manually after restart of the process failed during prev chef client run
# Input paramaters : Last restart failure time, string to identify the process
# Returned value   : true or false
#
def process_restarted_after_failure?(restart_failure_time, process_identifier)
  require 'time'
  begin
    start_time = process_start_time(process_identifier)
    if start_time.nil?
      return false
    elsif Time.parse(restart_failure_time).to_i < Time.parse(start_time).to_i
      Chef::Log.info ("#{process_identifier} seem to be started at #{start_time} after last restart failure at #{restart_failure_time}")
      return true
    else
      return false
    end
  end
end

def user_exists?(user_name)
  user_found = false
  chk_usr_cmd = "getent passwd #{user_name}"
  Chef::Log.debug("Executing command: #{chk_usr_cmd}")
  cmd = Mixlib::ShellOut.new(chk_usr_cmd, :timeout => 10).run_command
  if cmd.exitstatus == 0
    user_found = true
  end
  return user_found
end

def group_exists?(group_name)
  chk_grp_cmd = "getent group #{group_name}"
  Chef::Log.debug("Executing command: #{chk_grp_cmd}")
  cmd = Mixlib::ShellOut.new(chk_grp_cmd, :timeout => 10).run_command
  return cmd.exitstatus == 0 ? true : false
end

def get_group_action(group_name)
  return group_exists?(group_name) ? :manage : :create
end

def has_vip?
  cmd = Mixlib::ShellOut.new(
    "ip addr show", :timeout => 10
  ).run_command
  cmd.stderr.empty? && cmd.stdout.include?(node[:bcpc][:management][:vip])
end

# Internal: Check if oozie server is running on the given host.
#
# host - Endpoint (FQDN/IP) on which Oozie server is available.
#
# Examples
#
#   oozie_running?("f-bcpc-vm2.bcpc.example.com")
#   # => true
#
# Returns true if oozie server is operational with 'NORMAL' status, false otherwise.
def oozie_running?(host)
    oozie_url = "sudo -u oozie oozie admin -oozie http://#{host}:11000/oozie -status"
    cmd = Mixlib::ShellOut.new(
      oozie_url, :timeout => 20
    ).run_command
    Chef::Log.debug("Oozie status: #{cmd.stdout}")
    cmd.exitstatus == 0 && cmd.stdout.include?('NORMAL')
end

# Internal: Have the specified Oozie host update its ShareLib to the latest lib_<timestamp>
#           sharelib directory on hdfs:/user/oozie/share/lib/, without having to restart
#           that Oozie server. Oozie server, by default, uses the latest one when it (re)starts.
#
# host - Endpoint (FQDN/IP) on which Oozie server is available.
#
# Returns nothing.
def update_oozie_sharelib(host)
  if oozie_running?(host)
    update_sharelib = "sudo -u oozie oozie admin -oozie http://#{host}:11000/oozie -sharelibupdate"
    cmd = Mixlib::ShellOut.new(
      update_sharelib, :timeout => 20
    ).run_command
    if cmd.exitstatus == 0
      Chef::Log.info("Sharelibupdate: Updated sharelib on #{host}")
    else
      Chef::Log.info("Sharelibupdate: sharelibupdate command failed on #{host}")
      Chef::Log.info("  stdout: #{cmd.stdout}")
      Chef::Log.info("  stderr: #{cmd.stderr}")
    end
  else
    Chef::Log.info("Sharelibupdate: Oozie server not running on #{host}")
  end
end

def get_cluster_nodes()

  cluster_file = node['bcpc']['cluster']['file_path']

  if !File::file?(cluster_file)
    Chef::Log.fatal("File #{cluster_file} does not exist.")
    raise
  end

  nodeList = Array.new

  File::open(cluster_file,"r").each_line do |line|
    lines = line.split()
    nodeList.push("#{lines[0]}.#{lines[5]}")
  end

  if ! node[:bcpc][:management][:viphost].nil?
    nodeList.push(node[:bcpc][:management][:viphost])
  end

  nodeList  
end
