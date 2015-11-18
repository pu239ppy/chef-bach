# vim: tabstop=2:shiftwidth=2:softtabstop=2
#
# Cookbook Name:: fsquota
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.
#

package "quota" do
  action :install
end


quotaenable "/mnt/dev_sdb1" do
  mount_point "/mnt/dev_sdb1"
  mount_device "UUID=68fa07b6-07d4-4a18-99c9-29fccd5fd1cd"
  quota_type :user
end

fsquota "lp gets no love" do
  mount_point "/mnt/dev_sdb1"
  group_type :user_list
  group_members ["lp"]
  group_name "stuff"
  quota_spec :soft_blocks => 100, :hard_blocks => 200, :soft_inodes => 100, :hard_inodes => 200
  action :enforce
end
