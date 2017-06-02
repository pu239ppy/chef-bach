# vim: tabstop=2:shiftwidth=2:softtabstop=2 
#
# This module holds utility methods shared between repxe_host.rb and
# cluster_assign_roles.rb.
#
# Most of the methods pertain to cluster.txt and its contents.  A few
# will attempt to contact the chef server.  These should probably be
# separated from each other.
#
require 'chef'
require 'chef-vault'
require 'json'
require 'ohai'
require 'pry'
require 'ridley'
require 'faraday'
Ridley::Logging.logger.level = Logger.const_get 'ERROR'

module BACH
  module ClusterData
    def chef_environment
      ridley.environment.find(chef_environment_name)
    end

    def chef_environment_path
      env_files = Dir.glob(File.join(repo_dir, 'environments', '*.json'))

      if env_files.count != 1
        raise "Found #{env_files.count} environment files, " \
          'but exactly one should be present!'
      end

      env_files.first
    end

    def chef_environment_name
      File.basename(chef_environment_path).gsub(%r{.json$}, '')
    end

    #
    # Returns the password for the 'ubuntu' account in plaintext.
    # The method name comes from the confusing name of the data bag item.
    #
    def cobbler_root_password
      # Among other things, Ridley will set up Chef::Config for ChefVault.
      unless ridley.data_bag.find('os/cobbler_keys')
        raise('No os/cobbler_keys data bag item found. ' \
              'Is this cluster using chef-vault?')
      end

      ChefVault::Item.load('os', 'cobbler')['root-password']
    end

    def corrected_mac(entry)
      if is_virtualbox_vm?(entry)
        # If it's a virtualbox VM, cluster.txt is wrong, and we need to
        # find the real MAC.
        ping = Mixlib::ShellOut.new('ping', entry[:ip_address], '-c', '1')
        ping.run_command
        if !ping.status.success?
          puts "Ping to #{entry[:hostname]} (#{entry[:ip_address]}) failed, " \
            'checking ARP anyway.'
        end

        arp = Mixlib::ShellOut.new('arp', '-an')
        arp.run_command
        arp_entry = arp.stdout.split("\n")
          .map{|l| l.chomp}
          .select{ |l| l.include?(entry[:ip_address]) }
          .first
        match_data =
          /(\w\w:\w\w:\w\w:\w\w:\w\w:\w\w) .ether./.match(arp_entry.to_s)
        if !match_data.nil? && match_data.captures.count == 1
          mac = match_data[1]
          puts "Found #{mac} for #{entry[:hostname]} (#{entry[:ip_address]})"
          mac
        else
          raise 'Could not find ARP entry for ' +
            "#{entry[:hostname]} (#{entry[:ip_address]})!"
        end
      else
        # Otherwise, assume cluster.txt is correct.
        entry[:mac_address]
      end
    end

    def fqdn(entry)
      if(entry[:dns_domain])
        entry[:hostname] + '.' + entry[:dns_domain]
      else
        entry[:hostname]
      end
    end

    def get_entry(name)
      parse_cluster_txt.select do |ee|
        ee[:hostname] == name || fqdn(ee) == name
      end.first
    end

    def is_virtualbox_vm?(entry)
      %r{^08:00:27}.match(entry[:mac_address])
    end

    def validate_cluster_def(cluster_def, fields)
        # validate columns
        if (cluster_def.select{ |row| row.length != fields.length }).length > 0  then
          fail "Retreived cluster data appears to be invalid -- missing columns"
        end
        # validate node ids 
        if (cluster_def.select{ |row| row[:node_id] ! = '-' and row[:node_id].to_i = 0 }).length > 0  then
          fail "Retreived cluster data appears to be invalid -- node IDs must be positive integers between 0 and 256 (1..255)"
       end 
    end

    def parse_cluster_def(cluster_def)
      # parse something that looks like cluster.txt and memorize the result
      if node.run_state[:cluster_def] != nil then 
        node.run_state[:cluster_def]
      else
        fields = [
                  :node_id,
                  :hostname,
                  :mac_address,
                  :ip_address,
                  :ilo_address,
                  :cobbler_profile,
                  :dns_domain,
                  :runlist
                 ]

          # This is really gross because Ruby 1.9 lacks Array#to_h.
          node.run_state[:cluster_def] = cluster_def.map do |line|
            entry = Hash[*fields.zip(line.split(' ')).flatten(1)]
            entry.merge({fqdn: fqdn(entry)})
          validate_cluster_def(node.run_state[:cluster_def], fields)
          node.run_state[:cluster_def] 
        end
      end
    end

    # we will probbaly need a function that combines a remote fetcer
    # with local and returns whichever returns at all
    def fetch_cluster_def
      cluster_def_url = node[:bcpc][:bootstrap][:server] + node[:bcpc][:bootstrap][:cluster_def_path]
      response = Faraday.get cluster_def_url 
      if response.success? then
        parse_cluster_def(response.body)
      else
        nil
      end
    end 
      
    def parse_cluster_txt
      parse_cluster_def(File.readlines(File.join(repo_dir, 'cluster.txt')))
    end

    def refresh_vault_keys(entry=nil)
      reindex_and_wait(entry) if entry

      #
      # Vault data bags can be identified by distinctively named data
      # bag items ending in "_keys".
      #
      # Here we build a list of all the vaults by looking for "_keys"
      # and ignoring any data bags that contain no vault-items.
      #
      vault_list = ridley.data_bag.all.map do |db|
        vault_items = db.item.all.map do |dbi|
          if dbi.chef_id.end_with?('_keys')
            dbi.chef_id.gsub(%r{_keys$}, '')
          else
            nil
          end
        end.compact

        if vault_items.any?
          { db.name => vault_items }
        else
          nil
        end
      end.compact.reduce({}, :merge)

      vault_list.each do |vault, item_list|
        item_list.each do |item|
          begin
            vv = ChefVault::Item.load(vault, item)
            vv.refresh
            vv.save
            puts "Refreshed chef-vault item #{vault}/#{item}"
          rescue
            $stderr.puts "Failed to refresh chef-vault item #{vault}/#{item}!"
          end
        end
      end
    end

    def reindex_chef_server
      cc = Mixlib::ShellOut.new('sudo', 'chef-server-ctl', 'reindex')
      result = cc.run_command
      cc.error!
      result
    end

    def reindex_and_wait(entry)
      180.times do |i|
        if ridley.search(:node, "name:#{entry[:fqdn]}").any?
          puts "Found #{entry[:fqdn]} in search index"
          return
        else
          reindex_chef_server if i == 0

          if i % 60 == 0
            puts "Waiting for #{entry[:fqdn]} to appear in Chef index..."
          end
          sleep 1
        end
      end

      raise "Did not find #{entry[:fqdn]} in Chef index after 180 seconds!"
    end

    def repo_dir
      # This file is in the 'lib' subdirectory, so the repo dir is its parent.
      File.expand_path('..', File.dirname(__FILE__))
    end

    def ridley
      @ridley ||= Dir.chdir(repo_dir) { Ridley.from_chef_config }
    end
  end
end
