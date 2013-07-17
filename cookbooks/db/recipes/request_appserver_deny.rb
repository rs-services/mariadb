#
# Cookbook Name:: db
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker

log "  Request all databases close ports to this application server"

# See cookbooks/db_<provider>/providers/default.rb for the "firewall_update_request" action.
db node[:db][:data_dir] do
  machine_tag "database:active=true"
  enable false
  ip_addr node[:cloud][:private_ips][0]
  action :firewall_update_request
end
