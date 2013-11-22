#
# Cookbook Name:: nova
# Recipe:: api
#
# Copyright 2010, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "nova::config"

# sak - add VIP
haproxy = search(:node, "roles:haproxy").first
if haproxy.length > 0
  admin_vip = haproxy.haproxy.admin_ip
  public_vip = haproxy.haproxy.public_ip
end

Chef::Log.info("============================================")
Chef::Log.info("admin vip at #{admin_vip}")
Chef::Log.info("public vip at #{public_vip}")
Chef::Log.info("============================================")
#end of change

env_filter = " AND keystone_config_environment:keystone-config-#{node[:nova][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

unless node[:nova][:use_gitrepo]
  package "python-keystone"
  package "python-novaclient"
else
  pfs_and_install_deps "keystone" do
    cookbook "keystone"
    cnode keystone
  end
end

nova_package("api")

# sak - use VIP
#keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_address = admin_vip
#end of change
keystone_token = keystone["keystone"]["service"]["token"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["nova"]["service_user"]
keystone_service_password = node["nova"]["service_password"]

Chef::Log.info("Keystone server found at #{keystone_address}")
Chef::Log.info("Keystone token:            #{keystone_token}")
Chef::Log.info("Keystone service port:     #{keystone_service_port}")
Chef::Log.info("Keystone admin port:       #{keystone_admin_port}")
Chef::Log.info("Keystone service tenant:   #{keystone_service_tenant}")
Chef::Log.info("Keystone service user:     #{keystone_service_user}")
Chef::Log.info("Keystone service password: #{keystone_service_password}")
Chef::Log.info("Keystone admin username:   #{keystone_service_user}")
Chef::Log.info("Keystone admin password    #{keystone_service_password}")

template "/etc/nova/api-paste.ini" do
  source "api-paste.ini.erb"
  owner node[:nova][:user]
  group "root"
  mode "0640"
  variables(
    :keystone_ip_address => keystone_address,
    :keystone_admin_token => keystone_token,
    :keystone_service_port => keystone_service_port,
    :keystone_service_tenant => keystone_service_tenant,
    :keystone_service_user => keystone_service_user,
    :keystone_service_password => keystone_service_password,
    :keystone_admin_port => keystone_admin_port
  )
  notifies :restart, resources(:service => "nova-api"), :immediately
end

apis = search(:node, "recipes:nova\\:\\:api#{env_filter}") || []
if apis.length > 0 and !node[:nova][:network][:ha_enabled]
  api = apis[0]
  api = node if api.name == node.name
else
  api = node
end

# sak - use VIP
#public_api_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(api, "public").address
#admin_api_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(api, "admin").address
public_api_ip = public_vip
admin_api_ip = admin_vip
# end of change

keystone_register "nova api wakeup keystone" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  action :wakeup
end

keystone_register "register nova user" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  user_password keystone_service_password
  tenant_name keystone_service_tenant
  action :add_user
end

keystone_register "give nova user access" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  tenant_name keystone_service_tenant
  role_name "admin"
  action :add_access
end

keystone_register "register nova service" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  service_name "nova"
  service_type "compute"
  service_description "Openstack Nova Service"
  action :add_service
end

keystone_register "register ec2 service" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  service_name "ec2"
  service_type "ec2"
  service_description "EC2 Compatibility Layer"
  action :add_service
end

keystone_register "register nova endpoint" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  endpoint_service "nova"
  endpoint_region "RegionOne"
  endpoint_publicURL "http://#{public_api_ip}:8774/v2/$(tenant_id)s"
  endpoint_adminURL "http://#{admin_api_ip}:8774/v2/$(tenant_id)s"
  endpoint_internalURL "http://#{admin_api_ip}:8774/v2/$(tenant_id)s"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

keystone_register "register nova ec2 endpoint" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  endpoint_service "ec2"
  endpoint_region "RegionOne"
  endpoint_publicURL "http://#{public_api_ip}:8773/services/Cloud"
  endpoint_adminURL "http://#{admin_api_ip}:8773/services/Admin"
  endpoint_internalURL "http://#{admin_api_ip}:8773/services/Cloud"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

