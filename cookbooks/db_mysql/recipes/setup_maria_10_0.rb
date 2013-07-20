#
# Cookbook Name:: db_mysql
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker

version = "10.0"
node[:db][:version] = version
node[:db][:flavor] = "mariadb"
node[:db][:provider] = "db_mysql"

log "  Setting DB MySQL:#{node[:db][:flavor]} version to #{version}"


if node[:db][:flavor] == "mariadb"
    log "Installing MariaDB repo for #{node[:platform]}..."
    #MariaDB repo

  if node[:platform] =~ /centos/
     package "yum-plugin-fastestmirror" do
       action :install
     end

     yum_key "RPM-GPG-KEY-MariaDB" do
       url "https://yum.mariadb.org/RPM-GPG-KEY-MariaDB"
       action :add
     end

     yum_repository "MariaDB" do
       repo_name "MariaDB"
       description "MariaDB"
       url "http://yum.mariadb.org/10.0/centos#{node[:platform_version].to_i}-amd64"
       key "RPM-GPG-KEY-MariaDB"
       action :add
     end
   
  end


  if node[:platform] =~ /redhat/
     package "yum-plugin-fastestmirror" do
       action :install
     end

     yum_key "RPM-GPG-KEY-MariaDB" do
       url "https://yum.mariadb.org/RPM-GPG-KEY-MariaDB"
       action :add
     end

     yum_repository "MariaDB" do
       repo_name "MariaDB"
       description "MariaDB"
       url "http://yum.mariadb.org/10.0/rhel#{node[:platform_version].to_i}-amd64"
       key "RPM-GPG-KEY-MariaDB"
       action :add
     end
  
  end

  if node[:platform] =~ /ubuntu|debian/

       if node[:db][:flavor] == "mariadb"
          log "Installing MariaDB repo for #{node[:platform]}..."
          #MariaDB repo
          
          package "python-software-properties" do
             action :install
          end


       apt_repository "MariaDB" do
          uri "http://ftp.osuosl.org/pub/mariadb/repo/10.0/ubuntu"
          distribution node[:lsb][:codename]
          components ["main"]
          keyserver "keyserver.ubuntu.com"
          key "1BB943DB"
       end

  end


  else
      log "No extra repo needed for #{node[:db][:flavor]}."
  end

end

# Set MySQL 10.0 specific node variables in this recipe.
#
node[:db][:socket] = value_for_platform(
  "ubuntu" => {
    "default" => "/var/run/mysqld/mysqld.sock"
  },
  "default" => "/var/lib/mysql/mysql.sock"
)

# http://dev.mysql.com/doc/refman/5.5/en/linux-installation-native.html
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
