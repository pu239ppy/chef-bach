#
# Cookbook Name:: bcpc-hadoop
# Recipe:: oozie_spark_action
#
# Copyright 2016, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# This recipe adds spark action support to the oozie war
#

# unwind oozie war in some temp directory


# for each dir containing spark copy the libs to WAR location
ruby_block 'find_spark_libraries' do
  block do
    Dir.entries("/usr/spark").select { |d| File.directory("/usr/spark/#{d}") and d != "current" }.each do |spark_ver|
      bash "oozie spark action #{spark_ver}" do
        # make a corresponding direcotry in the war
        code <<- EOH
        mkdir "#{temp_war_loc}/#{spark_ver}"
        cp "/usr/spark/#{spark_ver}/lib/* #{temp_war_loc}/#{spark_ver}"
        EOH
      end
    end 
  end
end
