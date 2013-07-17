#
# Cookbook Name:: db_mysql
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker

version = "5.1"
node[:db][:version] = version
node[:db][:provider] = "db_mysql"

log "  Setting DB MySQL version to #{version}"

# Set MySQL 5.1 specific node variables in this recipe.
#

node[:db_mysql][:service_name] = value_for_platform(
  ["centos", "redhat"] => {
    "5.8" => "mysql",
    "default" => "mysqld"
  },
  "default" => "mysql"
)

node[:db][:socket] = value_for_platform(
  "ubuntu" => {
    "default" => "/var/run/mysqld/mysqld.sock"
  },
  "default" => "/var/lib/mysql/mysql.sock"
)


node[:db_mysql][:server_packages_uninstall] = []

# Ubuntu 12.04 doesn't support MySQL 5.1 server

node[:db_mysql][:server_packages_install] = value_for_platform(
  ["centos", "redhat"] => {
    "5.8" => ["MySQL-server-community"],
    "default" => ["mysql-server"]
  },
  "ubuntu" => {
    "10.04" => ["mysql-server-5.1"],
    "default" => []
  },
  "default" => []
)

node[:db][:init_timeout] = node[:db_mysql][:init_timeout]

# Mysql specific commands for db_sys_info.log file
node[:db][:info_file_options] = ["mysql -V", "cat /etc/mysql/conf.d/my.cnf"]
node[:db][:info_file_location] = "/etc/mysql"
log "  Using MySQL service name: #{node[:db_mysql][:service_name]}"
