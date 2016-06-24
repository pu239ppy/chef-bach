# encoding: utf-8

name             'bach_spark'
maintainer       'Bloomberg Finance L.P.'
description      'Cookbook to setup Apache Spark'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '1.0.0'

depends 'bcpc', '= 1.0.0'
depends 'bcpc-hadoop', '= 1.0.0'

%w(ubuntu).each do |os|
  supports os
end

