# vim: tabstop=2:shiftwidth=2:softtabstop=2 
module HadoopSmokeTests
  module OozieHelper
    def oozie_running?(host)
      oozie_url = "oozie admin -oozie http://#{host}:11000/oozie -status"
      cmd = Mixlib::ShellOut.new( oozie_url, :timeout => 20).run_command
      Chef::Log.debug("Oozie status: #{cmd.stdout}")
      cmd.exitstatus == 0 && cmd.stdout.include?('NORMAL')
    end

    def submit_workflow(host, user, prop_file)
      oozie_cmd = "sudo -u #{user} oozie job -run -config #{prop_file}"
      cmd = Mixlib::Shellout.new(oozie_cmd, timeout: 20).run_command
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
          |oozie_host| oozie_running?(oozie_host) 
        end
      if operational_hosts.length > 0 then
        submit_workflow(operationl_hosts[0], user, prop_file)
      end
    end
  end
end
