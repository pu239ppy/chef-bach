# vim: tabstop=2:shiftwidth=2:softtabstop=2 
default['hadoop_smoke_tests'] = {}
default['hadoop_smoke_tests']['oozie_user'] = 'ubuntu'
default['hadoop_smoke_tests']['hdfs_wf_path'] = '/user/ubuntu/oozie-smoke-tests'
default['hadoop_smoke_tests']['secure_cluster'] = true
default['hadoop_smoke_tests']['krb5_realm'] = 'BCPC.EXAMPLE.COM'
default['hadoop_smoke_tests']['rm'] = 'Test-Laptop'
default['hadoop_smoke_tests']['fs'] = 'hdfs://Test-Laptop'
default['hadoop_smoke_tests']['thrift_uris'] = ''
default['hadoop_smoke_tests']['zk_quorum'] = ''
