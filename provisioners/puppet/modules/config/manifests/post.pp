# == Class: config::post
#
# Post configuration for AEM AMIs
#
# === Parameters
#
# === Authors
#
# Shinesolutions <opensource@shinesolutions.com>
#
# === Copyright
#
# Copyright © 2023	Shine Solutions Group, unless otherwise noted.
#
class config::post (
  $exclude_packages = [],
) {
    # Updating yum.conf to exclude packages from being updated
    #
    # Using ini_settings instead of the built in yum config update of the
    # yum puppet module due to an error during updating yum.conf
    ini_setting { 'Exclude packages from yum update':
      ensure  => present,
      path    => '/etc/yum.conf',
      section => 'main',
      setting => 'exclude',
      key_val_separator => '=',
      value   => $exclude_packages.join(' '),
    }
}
