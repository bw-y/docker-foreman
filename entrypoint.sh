#!/bin/bash
set -e

: ${MCO_HOST:=127.0.0.1}
: ${MCO_PORT:=61613}
: ${MCO_USER:=mcollective}
: ${MCO_PASS:=mcopassword}
: ${PSK_PASS:=mcopskstr}

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
puppet_dir="/etc/puppet"
db_dir="/var/lib/postgresql/9.3/main"

McoClientConf(){
  cat << MCOCONF > /etc/mcollective/client.cfg
main_collective = mcollective
collectives = mcollective
libdir = /usr/share/mcollective/plugins
logger_type = console
loglevel = warn

# Plugins
securityprovider = psk
plugin.psk = ${PSK_PASS}

connector = activemq
plugin.activemq.pool.size = 1
plugin.activemq.pool.1.host = ${MCO_HOST}
plugin.activemq.pool.1.port = ${MCO_PORT}
plugin.activemq.pool.1.user = ${MCO_USER}
plugin.activemq.pool.1.password = ${MCO_PASS}

# Facts
factsource = yaml
plugin.yaml = /etc/mcollective/facts.yaml
MCOCONF
}

# 
McoConfCheck(){
  sed -i "s@987654321@${MCO_PASS}@g" /usr/local/apache-activemq-5.11.1/conf/activemq.xml
  McoClientConf
  if [[ ${MCO_HOST} == '127.0.0.1' || ${MCO_HOST} == 'localhost' ]];then
    /root/activemq.sh start
  fi
}

ConfReset(){
  local hn=$(hostname -f) ; local dn=$(facter domain)
  local old_hn=$(grep server_certname /etc/foreman/foreman-installer-answers.yaml|awk '{print $NF}')
  local old_dn=$(grep srv_domain /etc/foreman/foreman-installer-answers.yaml|awk '{print $NF}')

  if [[ $hn != $old_hn || $old_dn != $dn ]];then

    local reset_files[0]="/etc/apache2/sites-available/05-foreman.conf"
    local reset_files[1]="/etc/apache2/sites-available/05-foreman-ssl.conf"
    local reset_files[2]="/etc/foreman/foreman-installer-answers.yaml"
    local reset_files[3]="/etc/foreman/settings.yaml"
    local reset_files[4]="/etc/foreman-proxy/settings.yml"
    local reset_files[5]="/etc/foreman-proxy/settings.d/templates.yml"
    local reset_files[6]="/etc/foreman-proxy/settings.d/puppet.yml"
    local reset_files[7]="/etc/apache2/sites-available/25-puppet.conf"

    for f in ${reset_files[@]};do
      sed -i "s@$old_hn@$hn@g" $f
      sed -i "s@$old_dn@$dn@g" $f
    done
  fi
 
  if [[ ! -f "$puppet_dir/node.rb" ]];then
    rsync -av "$puppet_dir".bak/ $puppet_dir/
  fi
  
  if [[ ! -f "$db_dir/PG_VERSION" ]];then
    rsync -av "$db_dir".bak/ $db_dir/
  fi
}

Reset_All_Conf(){
  foreman-installer &> /dev/null || return 0
}

ConfCheck(){
  if [[ ! -f "$puppet_dir/node.rb" || ! -f "$db_dir/PG_VERSION" ]];then
    Reset_All_Conf
  fi
}

ApacheRun(){
   /etc/init.d/apache2 start &> /dev/null || Reset_All_Conf
}

runService(){
  /etc/init.d/postgresql status &> /dev/null || /etc/init.d/postgresql start
  /etc/init.d/apache2 status &> /dev/null || ApacheRun
  /etc/init.d/foreman-proxy status &> /dev/null || /etc/init.d/foreman-proxy start
}

PresentChown(){
  chown -R puppet:root /etc/puppet/ /usr/local/puppet_files/
  chown foreman-proxy:puppet /etc/puppet/autosign.conf
  chown -R postgres:postgres /var/lib/postgresql/9.3/main
}

MainFunc(){
  McoConfCheck
  ConfReset
  ConfCheck
  PresentChown
  runService
  read
}

MainFunc
