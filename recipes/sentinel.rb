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

redis = node['redisio']

sentinel_instances = redis['sentinels']
if sentinel_instances.nil?
  sentinel_instances = [{'port' => '26379', 'name' => 'mycluster'}]
end

redisio_sentinel "redis-sentinels" do
  default_settings redis['sentinel_defaults']
  sentinels sentinel_instances
  base_piddir redis['base_piddir']
end

# Create a service resource for each sentinel instance, named for the port it runs on.
sentinel_instances.each do |current_sentinel|
  sentinel_name = current_sentinel['name']
  job_control = current_sentinel['job_control'] || redis['default_settings']['job_control'] 

  if job_control == 'initd'
  	service "redis#{sentinel_name}" do
      start_command "/etc/init.d/redissentinel_#{sentinel_name} start"
      stop_command "/etc/init.d/redissentinel_#{sentinel_name} stop"
      status_command "pgrep -lf 'redis.*#{sentinel_name}' | grep -v 'sh'"
      restart_command "/etc/init.d/redissentinel_#{sentinel_name} stop && /etc/init.d/redissentinel_#{sentinel_name} start"
      supports :start => true, :stop => true, :restart => true, :status => false
  	end
  else
    Chef::Log.error("Unknown job control type, no service resource created!")
  end

end

node.set['redisio']['sentinels'] = sentinel_instances 

