require "securerandom"

package "xfsprogs" do
  action :install
end

directory "/disk" do
  owner "root"
  group "root"
  mode 00755
  action :create
end

user_disk = nil
hadoop_disks = node[:bcpc][:hadoop][:disks]
# have we reserved a disk for user directories
if node[:bcpc][:hadoop][:user_disk] == true then
  # perhaps instead of doing array slicing math, we explicitly specify
  # a disk to be used as a user partition as en environment var
  user_disk =  node[:bcpc][:hadoop][:disks][-1]
  hadoop_disks = node[:bcpc][:hadoop][:disks][0..-2]
end

if hadoop_disks.length != nil then
  hadoop_disks.each_index do |i|
    directory "/disk/#{i}" do
      owner "root"
      group "root"
      mode 00755
      action :create
      recursive true
    end
   
    d = hadoop_disks[i]
    execute "mkfs -t xfs /dev/#{d}" do
      not_if "file -s /dev/#{d} | grep -q 'SGI XFS filesystem'"
    end
 
    mount "/disk/#{i}" do
      device "/dev/#{d}"
      fstype "xfs"
      options "noatime,nodiratime,inode64"
      action [:enable, :mount]
    end
  end
  node.set[:bcpc][:hadoop][:mounts] = (0..hadoop_disks.length-1).to_a
else
  Chef::Application.fatal!('Please specify enough disks in node[:bcpc][:hadoop][:disks]!')
end
  
# create the user disk
if node[:bcpc][:hadoop][:user_disk] == true then
  if user_disk != nil then
    uuid_label = SecureRandom.uuid
    execute "mkfs -t ext4 -U #{uuid_label} /dev/#{user_disk}" do
      not_if "file -s /dev/#{user_disk} | grep -q 'ext4 filesystem data'"
    end

    directory "/opt/graphite" do
      owner "root"
      group "root"
      mode 00755
      action :create
    end
   
    quotaenable "user_dir_quota" do
      mount_pount "/opt/graphite"
      mount_device "UUID=#{uuuid_label}"  
      quota_type :group
    end
  else
    Chef::Application.fatal!('Please specify enough disks in node[:bcpc][:hadoop][:disks]!')
  end
end
