# vim: tabstop=2:shiftwidth=2:softtabstop=2
actions :enable 
default_action :enable

provides :quotaenable

attribute :mount_point, :kind_of => String, :required => false, :default => nil
attribute :mount_device, :kind_of => String, :required => false, :default => nil
# :user or :group
attribute :quota_type, :kind_of => Symbol, :required => true
