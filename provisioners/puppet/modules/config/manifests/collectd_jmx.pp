define config::collectd_jmx (
  $aem_id,
  $certificate,
  $jmx_keystore_path,
  $private_key,
  $jmx_keystore_password = 'changeit',
) {
  # collectd::plugin::genericjmx also installs collectd-java plugin, which in
  # turn also installs openjdk and makes it a default alternative, hence we need  # to set the default back to Oracle JDK
  if !defined(Class['collectd::plugin::genericjmx']) {
    class { 'collectd::plugin::genericjmx':
      manage_package => true,
    }
  }
  java_ks { "jmx-ssl:${jmx_keystore_path}/jmx.ks":
    ensure       => latest,
    certificate  => $certificate,
    private_key  => $private_key,
    password     => $jmx_keystore_password,
    trustcacerts => true,
  } -> file { "${jmx_keystore_path}/jmx.ks":
    ensure => file,
    mode   => '0400',
    owner  => "aem-${aem_id}",
    group  => "aem-${aem_id}",
  }
  # The Java Keystore needs to have a copy of the Certificate added if it's not signed by an official CA.
  # Since we are using the AEM SSL Certificate for JMX aem_install_java is taking care of adding the certificate
  # to the Java Keystore. In case we need change this in the future we need to use below method
  # to add the JMX cert to the Java Keystore.
  #  -> java_ks { 'jmx:/usr/java/default/jre/lib/security/cacerts':
  #   ensure      => present,
  #   certificate => $certificate,
  #   password    => 'changeit',
  #   path        => ['/bin','/usr/bin'],
  # }
}
