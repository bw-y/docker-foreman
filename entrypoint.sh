#!/bin/bash
set -e

: ${MCO_HOST:=127.0.0.1}
: ${MCO_VHOST:=/mcollective}
: ${MCO_PORT:=61613}
: ${MCO_USER:=mcollective}
: ${MCO_PASS:=mcopassword}
: ${PSK_PASS:=mcopskr}
: ${WEB_PASS:=admin}

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

init_tag="/etc/foreman/init-finished"

mcoSet(){
  cat << CLIENT > /etc/mcollective/client.cfg
main_collective = mcollective
collectives = mcollective
libdir = /usr/share/mcollective/plugins
logger_type = console
loglevel = warn

# Plugins
securityprovider = psk
plugin.psk = ${PSK_PASS}

direct_addressing = 1
connector = rabbitmq
plugin.rabbitmq.vhost = ${MCO_VHOST}
plugin.rabbitmq.pool.size = 1
plugin.rabbitmq.pool.1.host = ${MCO_HOST}
plugin.rabbitmq.pool.1.port = ${MCO_PORT}
plugin.rabbitmq.pool.1.user = ${MCO_USER}
plugin.rabbitmq.pool.1.password = ${MCO_PASS}
plugin.rabbitmq.heartbeat_interval = 30
plugin.rabbitmq.initial_reconnect_delay = 0.01
plugin.rabbitmq.max_reconnect_delay = 30.0
plugin.rabbitmq.use_exponential_back_off = true
plugin.rabbitmq.back_off_multiplier = 2
plugin.rabbitmq.max_reconnect_attempts = 0
plugin.rabbitmq.randomize = false
plugin.rabbitmq.timeout = -1

# Facts
factsource = yaml
plugin.yaml = /etc/mcollective/facts.yaml
CLIENT
  cat << SERVER > /etc/mcollective/server.cfg
main_collective = mcollective
collectives = mcollective
libdir = /usr/share/mcollective/plugins
logfile = /var/log/mcollective.log
loglevel = info
daemonize = 1

# Plugins
securityprovider = psk
plugin.psk = ${PSK_PASS}

direct_addressing = 1
connector = rabbitmq
plugin.rabbitmq.vhost = ${MCO_VHOST}
plugin.rabbitmq.pool.size = 1
plugin.rabbitmq.pool.1.host = ${MCO_HOST}
plugin.rabbitmq.pool.1.port = ${MCO_PORT}
plugin.rabbitmq.pool.1.user = ${MCO_USER}
plugin.rabbitmq.pool.1.password = ${MCO_PASS}
plugin.rabbitmq.heartbeat_interval = 30
plugin.rabbitmq.initial_reconnect_delay = 0.01
plugin.rabbitmq.max_reconnect_delay = 30.0
plugin.rabbitmq.use_exponential_back_off = true
plugin.rabbitmq.back_off_multiplier = 2
plugin.rabbitmq.max_reconnect_attempts = 0
plugin.rabbitmq.randomize = false
plugin.rabbitmq.timeout = -1

# Facts
factsource = yaml
plugin.yaml = /etc/mcollective/facts.yaml
SERVER
}

checkChown(){
  local files_dir=/usr/local/puppet_files
  [ -e $files_dir ] && chown -R puppet:root $files_dir
  [ -e /etc/puppet ] && chown -R puppet:root /etc/puppet 
  [ -e /var/lib/puppet ] && chown -R puppet:puppet /var/lib/puppet
  [ -e /etc/puppet/autosign.conf ] && chown foreman-proxy:puppet /etc/puppet/autosign.conf
  [ -e /var/lib/postgresql ] && chown -R postgres:postgres /var/lib/postgresql
}

runService(){
  /etc/init.d/postgresql start &> /dev/null
  /etc/init.d/foreman-proxy start &> /dev/null
  /etc/init.d/apache2 start &> /dev/null
  /etc/init.d/mcollective start &> /dev/null
  return 0
}

dbSet(){
  /etc/init.d/postgresql start
  su -l postgres -c 'psql -U postgres -c "create database foreman"'
}

initTag(){
  echo "user: admin, password: ${WEB_PASS}" > $init_tag
}

firstRun(){
  if [[ ! -f $init_tag ]];then
    mcoSet
    dbSet
    foreman-installer --enable-foreman-plugin-puppetdb --enable-foreman-compute-libvirt --puppet-show-diff=true --foreman-puppetrun=true --foreman-proxy-puppetrun-provider=mcollective --foreman-admin-password=${WEB_PASS} &> /dev/null && initTag
    cat $init_tag
  fi
}

firstRun
checkChown
runService
read
