#
# Cookbook Name:: db_mysql
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker

log "WARNING: MariaDB 5.2 support is experimental and only available on CentOS."

version = "5.2"
node[:db][:version] = version
node[:db][:flavor] = "mariadb"
node[:db][:provider] = "db_mysql"

log "  Setting DB MySQL:#{node[:db][:flavor]} version to #{version}"

#if node[:platform_version].to_i >= 6
#raise "MariaDB 5.2 is only supported on CentOS 5.  Please relaunch with the correct image."
#end

if node[:db][:flavor] == "mariadb"
    log "Installing OurDelta MariaDB repo for #{node[:platform]}..."
    #MariaDB repo

  if node[:platform] =~ /centos|redhat/
     package "yum-plugin-fastestmirror" do
       action :install
     end

     OurDeltaRepoRPM = "ourdelta-release-5-1.noarch.rpm"

     remote_file "#{Chef::Config[:file_cache_path]}/#{OurDeltaRepoRPM}" do
         source "http://master.ourdelta.org/yum/CentOS-MariaDB52/ourdelta-release-5-1.noarch.rpm"
         mode "0755"
         backup false
         action :create_if_missing
     end

     package OurDeltaRepoRPM do
         source "#{Chef::Config[:file_cache_path]}/#{OurDeltaRepoRPM}"
         options "--nogpgcheck"
         action :install
     end
   end

  else
      log "No extra repo needed for #{node[:db][:flavor]}."
end


# Set MySQL 5.2 specific node variables in this recipe.
#
node[:db][:socket] = value_for_platform(
  "ubuntu" => {
    "default" => "/var/run/mysqld/mysqld.sock"
  },
  "default" => "/var/lib/mysql/mysql.sock"
)

# http://dev.mysql.com/doc/refman/5.1/en/linux-installation-native.html
# For Red Hat and similar distributions, the MySQL distribution is divided into a
# number of separate packages, mysql for the client tools, mysql-server for the
# server and associated tools, and mysql-libs for the libraries.

log "Setting mysql service_name."
node[:db_mysql][:service_name] = value_for_platform(
  "ubuntu" => {
    "10.04" => "",
    "default" => "mysql"
  },
  "default" => "mysql"
)

node[:db_mysql][:server_packages_uninstall] = value_for_platform(
  "ubuntu" => {
    "10.04" => [],
    "default" => ["mysql-server"]
  },
  "default" => ["mysql-server"]
)
log "Set #{node[:db_mysql][:server_packages_uninstall]}."

node[:db_mysql][:server_packages_install] = value_for_platform(
  "ubuntu" => {
    "10.04" => [],
    "default" => ["mariadb-server"]
  },
  "default" => ["MariaDB-server", "MariaDB-common", "MariaDB-shared", "MariaDB-compat", "MariaDB-devel"]
)
log "Set #{node[:db_mysql][:server_packages_install]}."


node[:db][:init_timeout] = node[:db_mysql][:init_timeout]

# Mysql specific commands for db_sys_info.log file
node[:db][:info_file_options] = ["mysql -V", "cat /etc/mysql/conf.d/my.cnf"]
node[:db][:info_file_location] = "/etc/mysql"

log "  Using MySQL service name: #{node[:db_mysql][:service_name]}"
