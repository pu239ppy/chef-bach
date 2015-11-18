# fsquota

LWRP to support Linux quota

# Current support
QUOTA TYPE: user and group
User Groupings: posix users, groups and arbitary groupings provided as lists


Will find devices by mount point if mount_device is not provided will guess by looking in /etc/fstab or curently mountedf filesystems in node["filesystem"] 

# Example Usage
*Enable quota for a volume*
````ruby
quotaenable "update_fs" do
  mount_point "/mnt/virtualfs"
  mount_device "UUID=68fa07b6-07d4-4a18-99c9-29fccd5fd1cd"
  quota_type :user
end

quotaenable "/mnt/virtuslfs" do
  mount_point "/mnt/virtualfs"
  imount_device "/dev/sdb1"
  quota_type :group
end
````
The above code assumes that a filesystem is already mounted with *usrquota* or *grpquota* options

*Enable quota for a posix group per individual user*
````ruby
fsquota "testgroup quotas" do
  mount_point "/mnt/mount"
  group_type :posix_group_expander
  group_name "testgroup"
  quota_spec :soft_blocks => 100, :hard_blocks => 200, :soft_inodes => 100, :hard_inodes => 200
  action :enforce
end
````

*Enable quota for a user*
````ruby
fsquota "lp gets no love" do
  mount_point "/mnt/mount"
  group_type :user_list
  group_members ["lp"]
  group_name "stuff"
  quota_spec :soft_blocks => 100, :hard_blocks => 200, :soft_inodes => 100, :hard_inodes => 200
  action :enforce
end
````

*Enable quota for an entire posix group*
````ruby
fsquota "testgroup quotas" do
  mount_point "/mnt/virtualfs"
  group_type :posix_group
  group_name "testgroup"
  quota_spec :soft_blocks => 100, :hard_blocks => 300, :soft_inodes => 100, :hard_inodes => 300
  action :enforce
end
````
