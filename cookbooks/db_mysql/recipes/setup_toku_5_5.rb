#
# Cookbook Name:: db_mysql
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker

version = "5.5"
node[:db][:version] = version
node[:db][:flavor] = "tokudb"
node[:db][:provider] = "db_mysql"
TokuTek = "mariadb-5.5.30-tokudb-7.0.3-linux-x86_64"

extract_path = "/opt/tokutek"

log "  Setting DB MySQL:#{node[:db][:flavor]} version to #{version}"
log "We setup MariaDB 5.5 first to get all MariaDB dependencies via yum."

if node[:db][:flavor] == "mariadb|tokudb" 
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
       url "http://yum.mariadb.org/5.5/centos#{node[:platform_version].to_i}-amd64"
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
       url "http://yum.mariadb.org/5.5/rhel#{node[:platform_version].to_i}-amd64"
       key "RPM-GPG-KEY-MariaDB"
       action :add
     end
  
  end

  if node[:platform] =~ /ubuntu|debian/

       if node[:db][:flavor] == "mariadb|tokudb"
          log "Installing MariaDB repo for #{node[:platform]}..."
          #MariaDB repo
          
          package "python-software-properties" do
             action :install
          end


       apt_repository "MariaDB" do
          uri "http://ftp.osuosl.org/pub/mariadb/repo/5.5/ubuntu"
          distribution node['lsb']['codename']
          components ["main"]
          keyserver "keyserver.ubuntu.com"
          key "1BB943DB"
       end

  end


  else
      log "No extra repo needed for #{node[:db][:flavor]}."
  end

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
  "default" => ["MariaDB-common", "MariaDB-shared", "MariaDB-compat", "MariaDB-devel"]
)
log "Set #{node[:db_mysql][:server_packages_install]}."

log "MariaDB is installed without the server package.  Proceeding with TokuDB."

     remote_file "#{Chef::Config[:file_cache_path]}/#{TokuTek}.tar.gz" do
         source "http://www.tokutek.com/download.php?download_file=#{TokuTek}.tar.gz&bypass=1"
         mode "0755"
         backup false
         action :create_if_missing
     end


     bash 'extract_tar' do
        cwd "#{Chef::Config[:file_cache_path]}"
        code <<-EOH
           mkdir -p #{extract_path}
           tar xzf #{Chef::Config[:file_cache_path]}/#{TokuTek}.tar.gz -C #{extract_path}
           mv #{extract_path}/*/* #{extract_path}/
        EOH
      not_if { ::File.exists?(extract_path) }
     end

     link "#{extract_path}/#{TokuTek}" do
        to "#{extract_path}/mysql"
     end

    directory "#{extract_path}/mysql" do
        owner "mysql"
        group "mysql"
        recursive true
    end

   remote_file "mysql_convert_table_format" do
      source "https://raw.github.com/azilber/mariadb/45f81eba12283e58717ab2b3de02b9e2054ee2ec/scripts/mysql_convert_table_format.sh"  
      mode "0755"
      backup false
      action :create_if_missing
   end



node[:db][:init_timeout] = node[:db_mysql][:init_timeout]

# Mysql specific commands for db_sys_info.log file
node[:db][:info_file_options] = ["mysql -V", "cat /etc/mysql/conf.d/my.cnf"]
node[:db][:info_file_location] = "/etc/mysql"

log "  Using MySQL service name: #{node[:db_mysql][:service_name]}"
