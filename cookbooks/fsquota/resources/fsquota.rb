# vim: tabstop=2:shiftwidth=2:softtabstop=2
actions :enforce
default_action :enforce

provides :fsquota

attribute :mount_point, :kind_of => String, :required => false, :default => nil
attribute :group_type, :kind_of => Symbol, :required => true
attribute :group_name, :kind_of => String, :required => false
attribute :group_members, :kind_of => Array, :required => false
# quota spec expects to be defined as 
# :soft_blocks => spec, :hard_blocks => spec, :soft_inodes => spec, :hard_inodes => spec
attribute :quota_spec, :kind_of => Hash, :required => false
