# vim: tabstop=2:shiftwidth=2:softtabstop=2 
module HadoopSmokeTests
  module OozieHelper
    def test_oozie_running?(host, user)
      oozie_cmd = "sudo -u #{user} oozie admin -oozie http://#{host}:11000/oozie -status"
      Chef::Log.debug("Running oozie command #{oozie_cmd}")
      cmd = Mixlib::ShellOut.new( oozie_cmd, :timeout => 20).run_command
      Chef::Log.debug("Oozie status: #{cmd.stdout} #{cmd.stderr}")
      cmd.exitstatus == 0 && cmd.stdout.include?('NORMAL')
    end

    def submit_workflow(host, user, prop_file)
      oozie_cmd = "sudo -u #{user} oozie job -run -config #{prop_file} -oozie http://#{host}:11000/oozie"
      cmd = Mixlib::ShellOut.new(oozie_cmd, timeout: 20).run_command
      if cmd.exitstatus == 0
        Chef::Log.debug("Job submission result: #{cmd.stdout}")
      else
        # raise exception?
        Chef::Log.error("Job submission result: #{cmd.stderr}")
      end
      cmd.exitstatus
    end

    def submit_workflow_running_host(user, prop_file)
      operational_hosts =
        node[:bcpc][:hadoop][:oozie_hosts].select do 
          |oozie_host| test_oozie_running?(oozie_host, user) 
        end
      if operational_hosts.length > 0 then
        Chef::Log.debug('Identified live oozie server(s) ' +  operational_hosts.to_s) 
        submit_workflow(operational_hosts[0], user, prop_file)
      else
        Chef::Log.error('Unable to find a live oozie server')
      end
    end
  end
end
