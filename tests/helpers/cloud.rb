require_helper "errors"

# Represents a cloud with methods that encapsulate cloud specific behavior.
#
class Cloud
  extend VirtualMonkey::TestCase::Mixin

  # Factory that returns an instance of the specific Cloud subclass for a given
  # test run.
  #
  # @return [Cloud] an instance of the specific Cloud subclass
  #
  def self.factory
    cloud_name = get_cloud_name

    case cloud_name
    when nil, ""
      raise AssertionError, "get_cloud_name returned an invalid value: #{cloud_name}"
    when /^AWS /
      EC2.new cloud_name
    when /^Azure /
      Azure.new cloud_name
    when /^CS /, /^Datapipe /, /^IDC Frontier /, "Logicworks",
      "TATA InstaCompute"
      CloudStack.new cloud_name
    when /Openstack/i, "HP Cloud", "Rackspace Private V3"
      Openstack.new cloud_name
    when "Google"
      Google.new cloud_name
    when /^Rackspace Open Cloud /
      RackspaceOpenCloud.new cloud_name
    else
      Cloud.new cloud_name
    end
  end

  # The name of the cloud represented by this object.
  #
  # @return [String] the name of the cloud
  #
  attr_reader :cloud_name

  # Checks if a server can have ephemeral devices. If not overridden by a
  # subclass this method always returns false.
  #
  # @param server [Server] the server to check for ephemeral support
  #
  # @return [Boolean] whether the cloud supports ephemeral devices
  #
  def supports_ephemeral?(server)
    false
  end

  # Checks if a server has stop/start support. If not overridden by a subclass
  # this method always returns false.
  #
  # @param server [Server] the server to check for stop/start support
  #
  # @return [Boolean] whether the server supports stop/start
  #
  def supports_stop_start?(server)
    false
  end

  # Checks if the cloud is configured in a way where SSH must be done to a
  # private IP address from within the cloud. If not overridden by a subclass
  # this method always returns false.
  #
  # @return [Boolean] whether to SSH to a private IP address within the cloud
  #
  def needs_private_ssh?
    false
  end

  # Gets the MCI used on a Server.
  #
  # @param server [Server] the server to get the MCI from
  #
  # @return [MultiCloudImage] the MCI used on the server
  #
  def get_server_mci(server)
    if server.multicloud
      server.reload_as_current
      mci_id = server.current_instance.multi_cloud_image.split('/').last.to_i
    else
      # Legacy EC2 servers don't have a way of discovering their MCI. To work
      # around this the monkey adds a tag to the deployment which is the ID of
      # the MCI used for all of the servers.
      deployment = Deployment.find(server.deployment_href)
      mci_id_tag = deployment.get_info_tags["self"].find do |tag, _|
        tag =~ /mci_id/
      end
      mci_id = mci_id_tag.last.to_i
    end

    MultiCloudImage.find mci_id
  end

  # Checks if the cloud supports reboot. If not overridden by a subclass this
  # method always returns true.
  #
  # @return [Boolean] whether the cloud supports reboot
  #
  def supports_reboot?
    true
  end

  # Checks if the cloud supports creating and attaching volumes to servers. If
  # not overridden by a subclass this method will always return false.
  #
  # @return [Boolean] whether the cloud supports volumes
  #
  def supports_volumes?
    false
  end

  # Checks if the cloud supports the creation of live volume snapshots. If not
  # overridden by a subclass this method will always return false.
  #
  # @return [Boolean] whether the cloud supports volume snapshots
  #
  def supports_snapshots?
    false
  end

private
  # Constructs a cloud object. This method should not be used directly. Instead
  # {.factory} will create an instance of the correct Cloud subclass based on
  # which cloud a specific test is being run on.
  #
  # @see .factory
  #
  # @param cloud_name [String] the name of the cloud
  #
  def initialize(cloud_name)
    @cloud_name = cloud_name
  end
end

# Represents the Amazon EC2 cloud specific behavior.
#
# @see Cloud
#
class EC2 < Cloud
  # Checks if a server can have ephemeral devices. Epehemeral is supported on
  # the Amazon EC2 cloud except for on HVM instances.
  #
  # @param server [Server] the server to check for ephemeral support
  #
  # @return [Boolean] whether the cloud supports ephemeral devices
  #
  # @see Cloud#supports_ephemeral?
  #
  def supports_ephemeral?(server)
    # Ephemeral is not supported on EC2 HVM instances.
    get_server_mci(server).name =~ /hvm/i ? false : true
  end

  # Checks if a server has stop/start support. Stop/start is supported on EBS
  # images on the Amazon EC2 cloud.
  #
  # @param server [Server] the server to check for stop/start support
  #
  # @return [Boolean] whether the server supports stop/start
  #
  # @see Cloud#supports_stop_start?
  #
  def supports_stop_start?(server)
    # Only EC2 EBS images support stop/start.
    # All RHEL images are EBS, but may not say so.
    get_server_mci(server).name =~ /ebs|rhel/i ? true : false
  end

  # Checks if the cloud supports creating and attaching volumes to servers.
  # EC2 clouds support volumes.
  #
  # @return [Boolean] whether the cloud supports volumes
  #
  # @see Cloud#supports_volumes?
  #
  def supports_volumes?
    true
  end

  # Checks if the cloud supports the creation of live volume snapshots. EC2
  # clouds support volume snapshots.
  #
  # @return [Boolean] whether the cloud supports volume snapshots
  #
  # @see Cloud#supports_snapshots?
  #
  def supports_snapshots?
    true
  end
end

# Represents the Microsoft Azure cloud specific behavior.
#
# @see Cloud
#
class Azure < Cloud
  # Checks if a server can have ephemeral devices. Epehemeral is supported on
  # the Microsoft Azure cloud.
  #
  # @param server [Server] the server to check for ephemeral support
  #
  # @return [Boolean] whether the cloud supports ephemeral devices
  #
  # @see Cloud#supports_ephemeral?
  #
  def supports_ephemeral?(server)
    true
  end

  # Checks if the cloud supports creating and attaching volumes to servers.
  # Azure Cloud supports volumes.
  #
  # @return [Boolean] whether the cloud supports volumes
  #
  # @see Cloud#supports_volumes?
  #
  def supports_volumes?
    true
  end

  # Checks if the cloud supports the creation of live volume snapshots. Azure
  # Cloud supports volume snapshots.
  #
  # @return [Boolean] whether the cloud supports volume snapshots
  #
  # @see Cloud#supports_snapshots?
  #
  def supports_snapshots?
    true
  end
end

# Represents the Apache CloudStack cloud specific behavior. Datapipe, IDC
# Frontier, and Logicworks are CloudStack clouds.
#
class CloudStack < Cloud
  # Checks if the cloud is configured in a way where SSH must be done to a
  # private IP address from within the cloud. The IDC Frontier and Logicworks
  # clouds require SSHing from a private IP address.
  #
  # @return [Boolean] whether to SSH to a private IP address within the cloud
  #
  # @see Cloud#needs_private_ssh?
  #
  def needs_private_ssh?
    case @cloud_name
    when /^IDC Frontier /, "Logicworks"
      true
    else
      false
    end
  end

  # Checks if the cloud supports creating and attaching volumes to servers.
  # Cloudstack clouds supports volumes.
  #
  # @return [Boolean] whether the cloud supports volumes
  #
  # @see Cloud#supports_volumes?
  #
  def supports_volumes?
    true
  end

  # Checks if the cloud supports the creation of live volume snapshots.
  # Cloudstack clouds with VMware and XenServer hypervisors support volume
  # snapshots.
  #
  # @return [Boolean] whether the cloud supports volume snapshots
  #
  # @see Cloud#supports_snapshots?
  #
  def supports_snapshots?
    case @cloud_name
    when /VMware/, /XenServer/, /^IDC Frontier /, "Logicworks",
      "TATA InstaCompute"
      true
    else
      false
    end
  end
end

# Represents the Openstack cloud specific behavior. HP Cloud and Rackspace
# Private are Openstack clouds.
#
# @see Cloud
#
class Openstack < Cloud
  # Checks if a server can have ephemeral devices. Ephemeral is supported on
  # Openstack clouds.
  #
  # @param server [Server] the server to check for ephemeral support
  #
  # @return [Boolean] whether the cloud supports ephemeral devices
  #
  # @see Cloud#supports_ephemeral?
  #
  def supports_ephemeral?(server)
    true
  end

  # Checks if the cloud supports creating and attaching volumes to servers.
  # Openstack clouds supports volumes.
  #
  # @return [Boolean] whether the cloud supports volumes
  #
  # @see Cloud#supports_volumes?
  #
  def supports_volumes?
    true
  end
end

# Represents the Google cloud specific behavior.
#
# @see Cloud
#
class Google < Cloud
  # Checks if a server can have ephemeral devices. Ephemeral is supported on
  # Google cloud only if the server uses an instance type with the "-d" prefix.
  #
  # @param server [Server] the server to check for ephemeral support
  #
  # @return [Boolean] whether the cloud supports ephemeral devices
  #
  # @see Cloud#supports_ephemeral?
  #
  def supports_ephemeral?(server)
    instance_type = InstanceType.find(server.current_instance["instance_type"])
    instance_type.resource_uid =~ /-d$/ ? true : false
  end

  # Checks if the cloud supports creating and attaching volumes to servers.
  # Google cloud support volumes.
  #
  # @return [Boolean] whether the cloud supports volumes
  #
  # @see Cloud#supports_volumes?
  #
  def supports_volumes?
    true
  end

  # Checks if the cloud supports the creation of live volume snapshots. Google
  # cloud support volume snapshots.
  #
  # @return [Boolean] whether the cloud supports volume snapshots
  #
  # @see Cloud#supports_snapshots?
  #
  def supports_snapshots?
    true
  end

  # Checks if the cloud supports reboot. Google does not support reboot.
  #
  # @return [Boolean] whether the cloud supports reboot
  #
  # @see Cloud#supports_reboot?
  #
  def supports_reboot?
    false
  end
end

# Represents the Rackspace Open Cloud specific behavior.
#
# @see Cloud
#
class RackspaceOpenCloud < Cloud
  # Checks if the cloud supports creating and attaching volumes to servers.
  # Rackspace Open Cloud supports volumes.
  #
  # @return [Boolean] whether the cloud supports volumes
  #
  # @see Cloud#supports_volumes?
  #
  def supports_volumes?
    true
  end

  # Checks if the cloud supports the creation of live volume snapshots.
  # Rackspace Open Cloud supports volume snapshots.
  #
  # @return [Boolean] whether the cloud supports volume snapshots
  #
  # @see Cloud#supports_snapshots?
  #
  def supports_snapshots?
    true
  end
end
