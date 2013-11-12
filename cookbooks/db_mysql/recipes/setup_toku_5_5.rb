#
# Cookbook Name:: db_mysql
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker

maria_version = "5.5"
node[:db][:version] = maria_version
node[:db][:flavor] = "tokudb"
node[:db][:provider] = "db_mysql"

require 'uri'

log "  Setting DB MySQL:#{node[:db][:flavor]} version to #{node[:db][:version]}"
log "We setup MariaDB 5.5 first to get all MariaDB dependencies via yum."

arch = case node['kernel']['machine']
       when "x86_64" then "amd64"
       when "amd64" then "amd64"
       else "x86"
       end

pversion = node['platform_version'].split('.').first

    log "Installing MariaDB repo for #{node[:platform]}..."
    #MariaDB repo

  case node[:platform]
  when "centos", "redhat"
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
       url "http://yum.mariadb.org/5.5/#{node[:platform_family]}#{pversion}-#{arch}"
       key "RPM-GPG-KEY-MariaDB"
       action :add
     end
     log "Installed repo for #{node[:platform]}, #{node[:platform_family]}"

  when "ubuntu", "debian"
       package "python-software-properties" do
          action :install
       end

      package "libterm-readkey-perl" do
          action :install
      end

       apt_repository "MariaDB" do
          uri "http://ftp.osuosl.org/pub/mariadb/repo/5.5/ubuntu"
          distribution node['lsb']['codename']
          components ["main"]
          keyserver "keyserver.ubuntu.com"
          key "1BB943DB"
       end
       log "Installed repo for #{node[:platform]}"
  end


# Set MySQL 5.5 specific node variables in this recipe.
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

log "MariaDB is installed with the server package.  Proceeding with TokuDB."

     log "  Make sure to the original Tokutek filename is kept"

     node[:db_mysql][:tokudb][:version]=File.basename(URI.parse(node[:db_mysql][:tokudb_url]).path).split('.tar.gz').first

     remote_file "#{Chef::Config[:file_cache_path]}/tokudb.tar.gz" do
         source "#{node[:db_mysql][:tokudb_url]}"
         mode "0755"
         backup false
         action :create_if_missing
     end

     bash 'extract_tar' do
        cwd "#{Chef::Config[:file_cache_path]}"
        code <<-EOH
           mkdir -p #{node[:db_mysql][:tokudb][:install_path]}
           tar xzf #{Chef::Config[:file_cache_path]}/tokudb.tar.gz -C #{node[:db_mysql][:tokudb][:install_path]}
        EOH
      not_if { ::File.exists?(node[:db_mysql][:tokudb][:install_path]) }
     end


    group "mysql" do
       gid 927
       action :create
    end

    user "mysql" do
       name "MariaDB"
       comment "#{node[:db_mysql][:tokudb][:version]}"
       uid 927
       gid "mysql"
       system true
       action :create
    end

    execute "chown -Rf #{node[:db_mysql][:tokudb][:install_path]}/#{node[:db_mysql][:tokudb][:version]}" do
        command "chown -Rf mysql.mysql #{node[:db_mysql][:tokudb][:install_path]}"
        only_if { ::File.exists?(node[:db_mysql][:tokudb][:install_path]) }
    end

     link "#{node[:db_mysql][:tokudb][:base_dir]}" do
        to "#{node[:db_mysql][:tokudb][:install_path]}/#{node[:db_mysql][:tokudb][:version]}"
     end

   log " Use mysql_convert_table_format.pl for Innodb -> TokuDB conversions"
   cookbook_file "#{node[:db_mysql][:tokudb][:base_dir]}/scripts/mysql_convert_table_format.pl" do
      source "mysql_convert_table_format.sh"  
      mode "0755"
      backup false
      action :create_if_missing
   end


node[:db][:init_timeout] = node[:db_mysql][:init_timeout]

# Mysql specific commands for db_sys_info.log file
node[:db][:info_file_options] = ["mysql -V", "cat /etc/mysql/conf.d/my.cnf"]
node[:db][:info_file_location] = "/etc/mysql"

log "  Using MySQL service name: #{node[:db_mysql][:service_name]}"
