#!/bin/bash
set -e

: ${MCO_HOST:=127.0.0.1}
: ${MCO_VHOST:=/mcollective}
: ${MCO_PORT:=61613}
: ${MCO_USER:=mcollective}
: ${MCO_PASS:=mcopassword}
: ${PSK_PASS:=mcopskr}
: ${INIT:=off}

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

log_file="/root/run.log"
init_tag="/etc/foreman/init-finished"

mcoSet(){
  [[ -f $init_tag ]] && return 0
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
plugin.rabbitmq.vhost = ${MQ_VHOST}
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
plugin.rabbitmq.vhost = ${MQ_VHOST}
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

confSet(){
  [[ -f $init_tag ]] && return 0
  local hn=$(hostname -f) ; local dn=$(facter domain)
  local old_hn=$(grep server_certname /etc/foreman/foreman-installer-answers.yaml|awk '{print $NF}')
  local old_dn=$(grep srv_domain /etc/foreman/foreman-installer-answers.yaml|awk '{print $NF}')

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
  
  local puppet_dir="/etc/puppet"
  local db_dir="/var/lib/postgresql/9.3/main"
  if [[ ! -f "$puppet_dir/node.rb" ]];then
    rsync -a "$puppet_dir".bak/ $puppet_dir/
  fi
  
  if [[ ! -f "$db_dir/PG_VERSION" ]];then
    rsync -a "$db_dir".bak/ $db_dir/
  fi
}


checkChown(){
  local files_dir=/usr/local/puppet_files
  [ -d $files_dir ] && chown -R puppet:root $files_dir
  chown -R puppet:root /etc/puppet 
  chown foreman-proxy:puppet /etc/puppet/autosign.conf
  chown -R postgres:postgres /var/lib/postgresql
}

runService(){
  /etc/init.d/postgresql start
  /etc/init.d/foreman-proxy start
  /etc/init.d/apache2 start
  /etc/init.d/mcollective start
  [ ! -f $init_tag ] && touch $init_tag
  return 0
}

dbSet(){
  /etc/init.d/postgresql start
  su -l postgres -c 'psql -U postgres -c "drop database foreman"'
  su -l postgres -c 'psql -U postgres -c "create database foreman"'
  foreman-rake db:migrate
  foreman-rake db:seed
}

reInstall(){
  foreman-installer &> /dev/null
}

checkHost(){
  local hn=$(hostname -f)
  local old_hn=$(grep server_certname /etc/foreman/foreman-installer-answers.yaml|awk '{print $NF}')
  [[ ${INIT} == 'on' && $hn != $old_hn ]] && return 0
  [[ $hn != $old_hn ]] && echo "hostname:($hn), find old hostname:($old_hn) with foreman-installer-answers.yaml" >> $log_file
  return 1
}

MainFunc(){
  mcoSet
  if checkHost ;then
    confSet
    dbSet
    reInstall
    foreman-rake permissions:reset > $init_tag
  fi
  checkChown
  runService
  cat $init_tag
  read
}

MainFunc
