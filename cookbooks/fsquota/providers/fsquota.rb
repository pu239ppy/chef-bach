# vim: tabstop=2:shiftwidth=2:softtabstop=2
use_inline_resources

provides :fsquota

action :enforce do
  mount_point = @new_resource.mount_point || @new_resource.name
  group_type = @new_resource.group_type
  group_name = @new_resource.group_name
  group_members = @new_resource.group_members
  quota_spec = @new_resource.quota_spec

  soft_blocks = quota_spec[:soft_blocks]
  hard_block = quota_spec[:hard_blocks]
  soft_indoes = quota_spec[:soft_inodes]
  hard_indoes = quota_spec[:hard_inodes]

  if group_type == :posix_group_expander
    group_members = posix_group_members(group_name)
  end  

  if group_type == :posix_group_expander or group_type == :user_list 
    group_members.each do |gmember| 
      apply_quota(gmember, soft_blocks.to_s, hard_block.to_s,
                soft_indoes.to_s, hard_indoes.to_s, mount_point, group_type)
    end
  elsif group_type == :posix_group
    apply_quota(group_name, soft_blocks.to_s, hard_block.to_s,
                soft_indoes.to_s, hard_indoes.to_s, mount_point, group_type) 
  end
end

def apply_quota(target, sblock, hblock, sinode, hinode, mount_point, group_type) 
  quota_flag_map = {:user_list => 'u', :posix_group => 'g', :posix_group_expander => 'u'}
  quota_flag = quota_flag_map[group_type]
  
  cmdl = ["setquota", "-#{quota_flag}", target, sblock, hblock, sinode, hinode, mount_point]
  Chef::Log.info("Running #{cmdl.join(' ')}")
  cmd = Mixlib::ShellOut.new(cmdl).run_command
  if cmd.exitstatus != 0
    Chef::Log.warn("Failed to set quota for #{target}!")
    Chef::Log.warn("Ran #{cmdl.join(' ')}")
    Chef::Log.warn("STDOUT: #{cmd.stdout}")
    Chef::Log.warn("STDERR: #{cmd.stderr}")
  end
end

def posix_group_members(group_name)
  return node['etc']['group'][group_name]['members']
end
