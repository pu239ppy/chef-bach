#!/bin/bash -e

# download external environment -- roles, cluster.txt and environments
[[ -d external_environment ]] || git clone https://github.com/pu239ppy/chef-bach-env.git -b no_roles_environment_cluster_text external-environment 

ln -s external_environment/environments
ln -s external_environment/cluster.txt
ln -s external_environment/roles
