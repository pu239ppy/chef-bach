# vim: tabstop=2:shiftwidth=2:softtabstop=2 
#
# Cookbook Name:: bach_repository
# Recipe:: build_cluster_data_gem
#

execute 'build cluster_data gem' do
  command '/opt/chef/embedded/bin/gem build cluster_data.gemspec'
  cwd File.join(Chef::Config.file_cache_path, 'cluster-data-gem')
  # TODO: Come up with a really witty not_if
end

execute 'copy to bins' do
  command 'cp *.gem /home/vagrant/chef-bcpc/gems'
  cwd File.join(Chef::Config.file_cache_path, 'cluster-data-gem')
  # TODO: Multiversion
  # TODO: not_if
end
