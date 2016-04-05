# docker-foreman

#### Table of Contents

1. [简介](#简介)
2. [功能说明](#功能说明)
3. [使用说明](#使用说明)
4. [参数说明](#参数说明)
5. [其它说明](#其它说明)


## 简介

此镜像目前主要用于提供一个可以直接拿来使用的`foreman/puppet`

## 功能说明

* 此镜像包含直接可用的foreman(目前作者主要用以管理puppet)
* 此镜像包含直接可用的puppet server
* 此镜像包含直接可用的mcollective client,开启puppet run需要进入容器手工配置
* 此镜像版本号1.11.1,等同于foreman官方版本

## 使用说明

### 启动一个容器提供puppet server服务,要求如下:

1. 证书名/主机名配置为: puppet.bw-y.com
2. 将容器内的下列端口(`80/443/8140/8443`)映射到宿主机的对应端口: `80/443/8140/8443`

### 根据上述要求,命令如下

```
docker run -itd --name=puppet --hostname=puppet.bw-y.com -p 80:80 -p 443:443 -p 8140:8140 -p 8443:8443 index.alauda.cn/hypersroot/foreman:1.11.0
```

## 参数说明

### `--hostname`
[必选项] 由于puppet/foreman需要依赖一个可以解析的主机名用以配置证书相关,因此,在启动docker时,此参数务必加上,此参数会将配置的域名自动解析到容器对应的ip  默认值: 空

### `MCO_VHOST`
[可选项] 用于在MCollective的(`/etc/mcollective/client.cfg`)中设置RabbitMQ的vhost的配置. 默认值: /mcollective

### `MCO_HOST`
[可选项] 用于在MCollective的(`/etc/mcollective/client.cfg`)中设置MQ的地址. 此镜像不提供RabbitMQ服务.  默认值: 127.0.0.1(无效)

### `MCO_PORT`
[可选项] 用于在MCollective的(`/etc/mcollective/client.cfg`)中设置MQ的端口. 默认值: 61613

### `MCO_PASS`
[可选项] 用于在MCollective的客户配置(`/etc/mcollective/client.cfg`). 默认值: mcopassword

### `PSK_PASS`
[可选项] 用于在MCollective的(`/etc/mcollective/client.cfg`)中设置`plugin.psk`的密码字段. 默认值: mcopskstr

## 其它说明

* 启动成功后,在宿主机执行docker logs container_name,最后一行中,会显示设置的随机密码, 也可以计入容后手工执行`foreman-rake permissions:reset`重置密码
* 首次启动时,由于要做相关初始化操作,需等待3~5分钟左右.
* 若要迁移现有生成环境的foreman/puppet,大致操作如下:
```
1. 复制现有目录: /etc/puppet ; /var/lib/puppet/
2. 停止服务 /etc/init.d/apache2 stop ; /etc/init.d/foreman-proxy stop
3. 备份数据库. su -l postgres -c "/usr/bin/pg_dumpall|/bin/gzip > db.sql.gz"
4. 获取此docker镜像, 启动一个同域名的容器, 例: docker run -itd --name=puppet --hostname=your.puppetmaster.com -p 80:80 -p 443:443 -p 8140:8140 -p 8443:8443 -v /local-old/etc/puppet:/etc/puppet -v /local-old/puppet/lib:/var/lib/puppet index.alauda.cn/hypersroot/foreman:1.11.0
5. 第四步骤正常结束时,新的服务应该都已经正常工作,只是数据库和puppet类未导入.
6. 复制数据文件并导入:
  # docker cp /your/db.sql.gz puppet:/tmp/
  # docker exec -it puppet bash
  # /etc/init.d/foreman-proxy stop && /etc/init.d/apache2 stop 
  # su -l postgres -c 'psql -U postgres -c "drop database foreman"'
  # su -l postgres -c "/bin/gunzip -c /tmp/db.sql.gz |psql"
  # /etc/init.d/foreman-proxy start && /etc/init.d/apache2 start
```
* 由于rabbitmq并未在镜像中集成,因此,下面列出一份如何快速部署一个可被foreman/puppet-run使用的rabbitmq,当然,还是使用docker
```
1. 启动一个带管理页面的rabbitmq容器
  # docker run -itd --name mq -e RABBITMQ_DEFAULT_USER=admin -e RABBITMQ_DEFAULT_PASS=admin -e RABBITMQ_DEFAULT_VHOST=/ -p 61613:61613 -p 15672:15672 index.alauda.cn/library/rabbitmq:3.6.0-management

2. 进入容器,开启stomp插件
  # docker exec -it mq bash
  # rabbitmq-plugins enable rabbitmq_stomp
3. 打开浏览器: http://your_host_ip:15672  [admin/admin]
  a. 创建用户: mcollective ,其标签为空
  b. 创建vhost: /mcollective
  c. 关联vhost: / 和 /mcollective 到admin用户
  d. 关联vhost: / 和 /mcollective 到mcollective用户
  e. 创建exchanges:  "name": "mcollective_broadcast", "vhost": "/mcollective", "type": "topic"  ; 其它选项默认
  d. 创建exchanges:  "name": "mcollective_directed", "vhost": "/mcollective", "type": "direct"  ; 其它选项默认
```
