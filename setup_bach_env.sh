#!/bin/bash -e

# download external environment -- roles, cluster.txt and environments
#[[ -d external_environment ]] || git clone https://github.com/bloomberg/chef-bach-env.git external-environment 

git submodule add https://github.com/bloomberg/chef-bach-env.git --name external-environment -- external-environment
ln -s external_environment/environments
ln -s external_environment/cluster.txt
ln -s external_environment/roles
