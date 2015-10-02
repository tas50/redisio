#
# Cookbook Name:: redisio
# Recipe:: configure
#
# Copyright 2013, Brian Bianco <brian.bianco@gmail.com>
# Copyright 2013, Rackspace Hosting <ryan.cleere@rackspace.com>
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
include_recipe 'redisio::default'
include_recipe 'ulimit::default'

if node['redisio']['servers'].nil?
  node.default['redisio']['servers'] = [{'port' => '6379'}]
end

redis = node['redisio']

redisio_configure "redis-servers" do
  version redis['version'] if redis['version']
  default_settings redis['default_settings']
  servers redis['servers']
  base_piddir redis['base_piddir']
end

template '/usr/lib/systemd/system/redis@.service' do
  source    'redis@.service.erb'
  variables({ :bin_path => node['redisio']['bin_path'] })
  only_if   { node['redisio']['job_control'] == 'systemd' }
end

# Create a service resource for each redis instance, named for the port it runs on.
redis['servers'].each do |current_server|
  server_name = current_server['name'] || current_server['port']
  job_control = node['redisio']['job_control']

  case node['redisio']['job_control']
  when 'initd'
    service "redis#{server_name}" do
      # don't supply start/stop/restart commands, Chef::Provider::Service::*
      # do a fine job on it's own, and support systemd correctly
      supports :start => true, :stop => true, :restart => false, :status => true
    end
  when 'upstart'
    service "redis#{server_name}" do
      provider Chef::Provider::Service::Upstart
      start_command "start redis#{server_name}"
      stop_command "stop redis#{server_name}"
      restart_command "restart redis#{server_name}"
      supports :start => true, :stop => true, :restart => true, :status => false
    end
  when 'systemd'
    service "redis@#{server_name}" do
      provider Chef::Provider::Service::Systemd
      supports :start => true, :stop => true, :restart => true, :status => true
    end
  else
    Chef::Log.error("Unknown job control type, no service resource created!")
  end

end
