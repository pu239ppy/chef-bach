#!/bin/bash

#
# This script expects to be run in the chef-bcpc directory
#

set -e
set -x

# Default to Test-Laptop if environment not passed in
ENVIRONMENT="${1-Test-Laptop}"

# We may need the proxy for apt-get later
if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi

if [[ -z "$CURL" ]]; then
  echo "CURL is not defined"
  exit
fi

# Make the bootstrap a client of its own BCPC local repo
echo "deb [trusted=yes arch=amd64] file://$(pwd)/bins/ 0.5.0 main" > \
     /etc/apt/sources.list.d/bcpc.list

# Update only the BCPC local repo
apt-get -o Dir::Etc::SourceList=/etc/apt/sources.list.d/bcpc.list \
	-o Dir::Etc::SourceParts="-" \
	-o APT::Get::List-Cleanup="0" \
	update

apt-get -y install chef=12.19.36-1
# Faraday will be required in libs, so we will not have a chance to recipe this away
/opt/chef/embedded/bin/gem install faraday
pushd /home/vagrant/chef-bcpc/lib/cluster-data-gem > /dev/null
sudo /opt/chef/embedded/bin/gem install cluster_data
popd > /dev/null

if dpkg -s chef-server 2>/dev/null | grep -q ^Status.*installed && \
   dpkg -s chef 2>/dev/null | grep -q ^Version.*12; then
  chef-server-ctl restart
  echo 'chef-server and client are installed and the server has been restarted'
else
  apt-get -y install chef-server
  mkdir -p /etc/chef-server
  printf "chef_server_webui['enable'] = false\n" >> /etc/chef-server/chef-server.rb
  printf "nginx['enable_non_ssl'] = false\n" >> /etc/chef-server/chef-server.rb
  printf "nginx['non_ssl_port'] = 4000\n" >> /etc/chef-server/chef-server.rb
  # we can take about 45 minutes to Chef the first machine when running on VMs
  # so follow tuning from CHEF-4253
  printf "erchef['s3_url_ttl'] = 3600\n" >> /etc/chef-server/chef-server.rb
  export NO_PROXY=${NO_PROXY-127.0.0.1}
  chef-server-ctl reconfigure
fi

# copy our ssh-key to be authorized for root
if [[ -f $HOME/.ssh/authorized_keys && ! -f /root/.ssh/authorized_keys ]]; then
  if [[ ! -d /root/.ssh ]]; then
    mkdir /root/.ssh
  fi
  cp $HOME/.ssh/authorized_keys /root/.ssh/authorized_keys
fi



