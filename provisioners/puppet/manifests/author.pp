class { 'config::base':
  before => [
    Class['config::certs'],
    Class['config::license'],
    Class['aem_curator::install_aem_java'],
    Class['aem_curator::install_author']
  ]
}

class { 'config::certs':
  require => [
    Class['config::base']
  ],
  before  => [
    Class['aem_curator::install_aem_java'],
    Class['aem_curator::install_author']
  ]
}

class {'config::license':
  require => [
    Class['config::base']
  ],
  before  => [
    Class['aem_curator::install_aem_java'],
    Class['aem_curator::install_author']
  ]
}

class {'aem_curator::install_aem_java':
  require => [
    Class['config::base'],
    Class['config::certs'],
    Class['config::license']
  ],
  before  => [
    Class['aem_curator::install_author']
  ]
}

include aem_curator::install_author

if $::config::base::install_cloudwatchlogs {
  if $::config::base::install_cloudwatchlogs_aem {
    config::cloudwatchlogs_aem { 'Setup CloudWatch for AEM Author':
      aem_id => 'author',
    }
  }

  # At the end of doing all Cloudwatch actions we are disabling and stopping the
  # CloudWatch agent, and removing the awslogs pid file.
  # Related to https://github.com/shinesolutions/packer-aem/issues/192
  exec { 'Disable Cloudwatchlogs agent':
    command => "systemctl disable ${::config::base::awslogs_service_name}",
    path    => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    before  => Exec['Stop Cloudwatchlogs agent'],
    require => Service[$::config::base::awslogs_service_name],
  } -> exec { 'Stop Cloudwatchlogs agent':
    command => "systemctl stop ${::config::base::awslogs_service_name}",
    path    => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    before  => File["${::config::base::awslogs_path}/state/awslogs.pid"],
    require => Exec['Disable Cloudwatchlogs agent'],
  } -> file {"${::config::base::awslogs_path}/state/awslogs.pid":
    ensure  => absent,
    require => Exec['Stop Cloudwatchlogs agent']
  }
}

if $::config::base::install_collectd {
  config::collectd_jmx { '[author] Setup collectd-generic-jmx plugin':
    require           => [
      Class['config::certs'],
      Class['aem_curator::install_aem_java']
    ],
    aem_id            => 'author',
    # Loading JMX Keystore Path from the hiera parameter aem_keystore_path, to ensure
    # we are using the same location for the JMX
    jmx_keystore_path => dirname(hiera('aem_curator::install_author::aem_keystore_path')),
    certificate       => "${::config::base::tmp_dir}/certs/aem.cert",
    private_key       => "${::config::base::tmp_dir}/certs/aem.key",
  }
}

if $::config::base::install_cloudwatch_metric_agent {
  config::cloudwatch_metric_agent { 'Setup Cloudwatch Metric Agent for AEM Author':
    disk_path   => [
      $::config::base::metric_root_disk_path,
      $::config::base::metric_data_disk_path
    ],
    autoscaling => false
  }
}
