# vim: tabstop=2:shiftwidth=2:softtabstop=2 
#
# This module holds utility methods shared between repxe_host.rb and
# cluster_assign_roles.rb.
#
# Most of the methods pertain to cluster.txt and its contents.  A few
# will attempt to contact the chef server.  These should probably be
# separated from each other.
#
require 'faraday'

module BACH
  module ClusterData
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

    def validate_node_number?(nn)
      # node number must either be '-' or a positive integer 
      # 1..255
      if nn != '-' and nn < 1 and nn > 255 then
        false
      else
        true
      end 
    end

    def validate_cluster_def(cluster_def, fields)
        cdef_copy = cluster_def.filter{ |row| row[:runlist] != 'SKIP' }
        # validate columns each row has the same number of fields as fields
        if (cdef_copy.select{ |row| row.length != fields.length }).length > 0  then
          fail "Retreived cluster data appears to be invalid -- missing columns"
        end
        # validate node ids 
        if (cluster_def.select{ |row| validate_node_number?[:node_id] == false }).length > 0  then
          fail "Retreived cluster data appears to be invalid -- node IDs must be positive integers between 0 and 256 (1..255)"
        end 
    end

    def parse_cluster_def(cluster_def)
      # parse something that looks like cluster.txt and memorize the result
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
        cdef = cluster_def.map do |line|
          entry = Hash[*fields.zip(line.split(' ')).flatten(1)]
          entry.merge({fqdn: fqdn(entry)})
        end
        validate_cluster_def(cdef, fields)
        cdef
    end

    # combines local cluster.txt access with http call to cluster data
    def fetch_cluster_def
        begin
          fetch_cluster_def_http
        rescue
          fetch_cluster_def_local 
        end
    end

    # fetch cluster definition via http
    def fetch_cluster_def_http
      cluster_def_url = node[:bcpc][:bootstrap][:server] + node[:bcpc][:bootstrap][:cluster_def_path]
      response = Faraday.get cluster_def_url 
      if response.success? then
        parse_cluster_def(response.body)
      else
        nil
      end
    end 
      
    # locally access cluster.txt
    def fetch_cluster_def_local
      parse_cluster_def(File.readlines(File.join(repo_dir, 'cluster.txt')))
    end

    def repo_dir
      '/home/vagrant/chef-bcpc'
    end
  end
end
