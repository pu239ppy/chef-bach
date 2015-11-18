# vim: tabstop=2:shiftwidth=2:softtabstop=2
use_inline_resources
provides :quotaenable

action :enable do
  mount_point = @new_resource.mount_point || @new_resource.name
  mount_device = @new_resource.mount_device
  quota_type = @new_resource.quota_type
  enable_quota(mount_point, mount_device, quota_type)
end

def enable_quota(mount_point, mount_device, quota_type)
  if quota_type != :user and quota_type != :group 
    Chef::Log.error("Must specify either user or group quota enablement")
    return
  end

  if mount_device == nil then
    mount_device = find_fstab_entry(mount_point)[:device] || 
      introspect_mount(mount_point, nil, "device") 
  end
  if mount_device == nil then
    Chef::Log.error("Unable to determine device for mount point #{mount_point}")
    return
  end
  
  # quota may be enabled on a device that already exists so it may be possible that the mount_device 
  # was not provided, we may need to dicover what it is, in order to make mount resource behave
  device_type = case mount_device
    when /^label/i
      :label
    when /^uuid/i
      :uuid
    else
      :device
  end
  if device_type == :label or device_type == :uuid then
    mount_device = mount_device.split('=')[1]
  end

  quota_fs_map = {:user => 'usrquota', :group => 'grpquota'}
  Chef::Log.info("Mount Device is: #{mount_device}")
  mount_options_fs = find_fstab_entry(mount_point)[:options] ||
    introspect_mount(mount_point, nil, "mount_options") 
  Chef::Log.info("Mount options: #{mount_options_fs}")
  if not mount_options_fs.include? quota_fs_map[quota_type] then
    mount_options_fs.push(quota_fs_map[quota_type])
    mount "update-mount" do
      device mount_device
      device_type device_type
      mount_point mount_point
      options mount_options_fs
      action [:enable, :remount, :mount]
    end
  end
 
  quota_flag_map = {:user => 'u', :group => 'g'}
  quota_flag = quota_flag_map[quota_type]

  quotaon_check = ["quotaon", "-p#{quota_flag}", mount_point]
  cmd = Mixlib::ShellOut.new(quotaon_check).run_command
  begin
    cmd.error!
  rescue
    Chef::Log.error("#{quotaon_check.join(' ')} exited with a non-zero status")
    Chef::Log.error("STDOUT: #{cmd.stdout}")
    Chef::Log.error("STDERR: #{cmd.stderr}")
    return
  end

  execute "quotacheck" do
    command "quotacheck -F vfsv1 -cmv#{quota_flag} #{mount_point}"
  end

  execute "quotaon" do
    command "quotaon -v#{quota_flag} #{mount_point}"
  end
end


def introspect_mount(mount_point, mount_device, key)
  # this is only useful for filesystems that 
  # are already mounted
  # looking for node["filesystem"][mount_point][key]
  results = []
  node['filesystem'].keys.each do |dev|
    if node['filesystem'][dev]['mount'] == mount_point or dev == mount_device 
      if key == 'device' then
        return dev
      end
      return node['filesystem'][dev][key] || results
    end
  end
  return results 
end

def find_fstab_entry(mount_point)
  # used to discover entries in /etc/fstab
  results = Hash.new()
  ::File.foreach("/etc/fstab") do |line|
    case line
    when /^[#\s]/
      next
    when /^(\S+)\s+#{Regexp.escape(mount_point)}\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/
      results[:device] = $1
      results[:fstype] = $2
      results[:options] = $3.split(",")
      results[:dump] = $4.to_i
      results[:pass] = $5.to_i
    end
  end 
  return results
end

