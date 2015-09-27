#!/bin/bash
set -e

: ${MCO_HOST:=127.0.0.1}
: ${MCO_PORT:=61613}
: ${MCO_USER:=mcollective}
: ${MCO_PASS:=mcopassword}
: ${PSK_PASS:=mcopskstr}

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


ConfReset(){
  local PATH="/usr/sbin:/usr/bin:/sbin:/bin"
  local reset_files[0]="/etc/apache2/sites-available/05-foreman.conf"
  local reset_files[1]="/etc/apache2/sites-available/05-foreman-ssl.conf"
  local reset_files[2]="/etc/foreman/foreman-installer-answers.yaml"
  local reset_files[3]="/etc/foreman/settings.yaml"
  local reset_files[4]="/etc/foreman-proxy/settings.yml"
  local reset_files[5]="/etc/foreman-proxy/settings.d/templates.yml"
  local reset_files[6]="/etc/foreman-proxy/settings.d/puppet.yml"
  local hn=$(hostname) ; local dn=$(facter domain)

  for f in ${reset_files[@]};do
    sed -i "s@foreman.bw-y.com@$hn@g" $f
    sed -i "s@bw-y.com@$dn@g" $f
  done

  rsync -av "$puppet_dir".bak/ $puppet_dir/
  rsync -av "$db_dir".bak/ $db_dir/
  chown -R puppet:root /etc/puppet/
  chown foreman-proxy:puppet /etc/puppet/autosign.conf

  /usr/sbin/foreman-installer &> /dev/null || return 0
}

McoConfCheck(){
  sed -i "s@987654321@${MCO_PASS}@g" /usr/local/apache-activemq-5.11.1/conf/activemq.xml
  McoClientConf
  if [[ ${MCO_HOST} == '127.0.0.1' || ${MCO_HOST} == 'localhost' ]];then
    /root/activemq.sh start
  fi
}

ConfCheck(){
  if [[ ! -f "$puppet_dir/node.rb" && ! -f "$db_dir/PG_VERSION" ]];then
    ConfReset
  fi
}

runService(){
  for nn in {1..10};do
    if /etc/init.d/postgresql status &> /dev/null ;then
      local aa=aa
    else
      /etc/init.d/postgresql start
    fi
    if /etc/init.d/apache2 status &> /dev/null ;then
      local bb=aa
    else
      /etc/init.d/apache2 start
    fi
    if /etc/init.d/foreman-proxy status &> /dev/null ;then
      local cc=aa
    else
      /etc/init.d/foreman-proxy start
    fi
    [[ $aa == 'aa' && $bb == 'aa' && $cc == 'aa' ]] && return 0
  done
}

MainFunc(){
  McoConfCheck
  ConfCheck
  runService
  read
}

MainFunc
