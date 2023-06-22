define config::collectd_jmx (
  $aem_id,
  $jdk_filename,
  $jmx_keystore_path,
  $tmp_dir,
  $jmx_keystore_password = 'changeit',
) {

  # Location of the JMX Keystore
  $jmx_keystore_location = "${jmx_keystore_path}/jmx.ks"
  $jmx_cert_location = "${tmp_dir}/certs/${aem_id}/jmx.cert"
  # Determining the location of the Java CA Keystore
  # Split JDK filename to determine JDK Major Version
  $jdk_filename_splitted = split($jdk_filename, '-')
  # Case to Setup variables per JDK Version
  case $jdk_filename_splitted[1] {
    /^8/: {
      # Automation to determine JDK Version via default filename
      # Splitting JDK File Name jdk-8u221-linux-x64.rpm to [8, 221]
      $jdk_version = $jdk_filename_splitted[1]
      $jdk_version_splitted = split($jdk_version, 'u')
      $jdk_version_major = $jdk_version_splitted[0]
      $jdk_version_update = $jdk_version_splitted[1]
      # Support of different JDK8 versions with different binary pathes
      if Integer($jdk_version_update) == 371 {
        $java_home_path = "/usr/java/jdk1.${jdk_version_major}.0_${jdk_version_update}-amd64"
        $libjvm_content_path = "${java_home_path}/jre/lib/amd64/server/\n"
        $cacert_path = "${java_home_path}/jre/lib/security/cacerts"
      } elsif Integer($jdk_version_update) >= 261 and Integer($jdk_version_update) < 371 {
        $java_home_path = "/usr/java/jdk1.${jdk_version_major}.0_${jdk_version_update}-amd64"
        $cacert_path = "${java_home_path}/jre/lib/security/cacerts"
      } elsif Integer($jdk_version_update) <= 162 {
        $java_home_path = "/usr/java/jdk1.${jdk_version_major}.0_${jdk_version_update}/jre"
        $cacert_path = "${java_home_path}/lib/security/cacerts"
      } else {
        $java_home_path = "/usr/java/jdk1.${jdk_version_major}.0_${jdk_version_update}-amd64/jre"
        $cacert_path = "${java_home_path}/lib/security/cacerts"
      }
    }
    /^11/:
    {
      # Automation to determine JDK Version via default filename
      # Splitting JDK File Name jdk-11.0.7_linux-x64_bin.rpm
      # to receive JDK version 11.0.7
      $jdk_version_raw = split($jdk_filename_splitted[1], '_')
      $jdk_version = $jdk_version_raw[0]
      $java_home_path = "/usr/java/jdk-${jdk_version}"
      $cacert_path = "${java_home_path}/lib/security/cacerts"
    }
    default: {
      fail('Error: Unknown Java Version. Supported java versions are : ( 8 | 11 )')
      }
  }

  # collectd::plugin::genericjmx also installs collectd-java plugin, which in
  # turn also installs openjdk and makes it a default alternative, hence we need  # to set the default back to Oracle JDK
  if !defined(Class['collectd::plugin::genericjmx']) {
    class { 'collectd::plugin::genericjmx':
      manage_package => true,
    }
  }

  # Create location of the JMX Keystore
  exec { "Create ${jmx_keystore_path}":
    creates => "${jmx_keystore_path}",
    command => "mkdir -p ${jmx_keystore_path}",
    path    => '/usr/local/bin/:/bin/:/usr/bin',
  } -> exec { "Update owner of ${jmx_keystore_path}":
    command => "chown aem-${aem_id}:aem-${aem_id} ${jmx_keystore_path}",
    path    => '/usr/local/bin/:/bin/:/usr/bin',
  } -> exec { "Update permissions of ${jmx_keystore_path}":
    command => "chmod 0540 ${jmx_keystore_path}",
    path    => '/usr/local/bin/:/bin/:/usr/bin',
  }

  # Create TMP JMX Cert location if it does not exist
  file { dirname($jmx_cert_location):
    ensure => directory,
    mode   => '0700',
  }

  exec { "${aem_id} Create JMX KeyStore":
    command => "keytool -genkey -alias jmx -keyalg RSA -keysize 2048 -validity 365 -keystore ${jmx_keystore_location} -storepass ${jmx_keystore_password} -dname 'CN=localhost, OU=AEMOpenCloud, O=Shinesolutions, L=Melbourne, S=VIC, C=AU' -ext SAN=dns:localhost",
    creates => $jmx_keystore_location,
    path    => ['/bin','/usr/bin'],
  } ->  exec { "${aem_id} Export JMX Certificate":
    command => "keytool -exportcert -alias jmx -keystore ${jmx_keystore_location} -storepass ${jmx_keystore_password} -rfc -file ${jmx_cert_location}",
    creates => $jmx_cert_location,
    path    => ['/bin','/usr/bin'],
  } -> java_ks { "jmx-${aem_id}:${cacert_path}": # Adding JMX Cert to Java Default Keystore, so the self-managed certificate is trusted
    ensure      => present,
    certificate => $jmx_cert_location,
    password    => 'changeit',
    path        => ['/bin','/usr/bin'],
  }

  file { $jmx_keystore_location: # Ensuring JMX Keystore is only readable by AEM
    ensure => file,
    mode   => '0400',
    owner  => "aem-${aem_id}",
    group  => "aem-${aem_id}",
  }

}
