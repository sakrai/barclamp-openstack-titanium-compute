#
# Copyright 2011, Dell
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
# Author: sak rai
#

####
Chef::Log.info(">>>>>> Nova: qemu Recipe")

if node["attributes"]["nova"]["libvirt_type"] = "qemu"
  Chef::Log.info(">>>>>> Nova: hypervisor qemu")
  # recipe added as qemu package is required for creating bootable volumes.
  package "qemu" do
    action :install
  end
end

