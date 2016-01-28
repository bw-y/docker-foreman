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

* 此镜像软件包安装部分,已经直接在基础镜像安装完成(基于library/ubuntu:14.04.3手工安装后commit)
* 此镜像仅在基础镜像之上做部分配置修改,使其可以方便的被复用
* 此镜像包含直接可用的foreman(目前作者主要用以管理puppet)
* 此镜像包含直接可用的puppet server(由foreman-installer依赖安装)
* 此镜像包含直接可用的mcollective client,已经配置foreman开启puppet run使用mcollecive
* 此镜像版本号1.10.1,等同于foreman官方版本

## 使用说明

### 启动一个容器提供puppet server服务,要求如下:

1. 证书名/主机名配置为: puppet.bw-y.com
2. 将容器内的下列端口(`80/443/8140/8443`)映射到宿主机的对应端口: `80/443/8140/8443`

### 根据上述要求,命令如下

```
docker run -itd --name=puppet --hostname=puppet.bw-y.com -p 80:80 -p 443:443 -p 8140:8140 -p 8443:8443 index.alauda.cn/hypersroot/foreman:1.10.1
```

## 参数说明

### `--hostname`
[必选项] 由于puppet/foreman需要依赖一个可以解析的主机名用以配置证书相关,因此,在启动docker时,此参数务必加上,此参数会将配置的域名自动解析到容器对应的ip  默认值: 空

### `INIT`
[可选项] 是否初始化foreman/puppet/postgresql,有效值: on(初始化), off(不初始化),首次初始化后,会在创建一个初始化完成的文件用以标识,以便在下次启动时不在执行. 初始化文件位置: /etc/foreman/init-finished  默认值: off

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

* 设置--hostname=puppet.bw-y.com时, foreman页面的默认登陆用户名密码: admin/admin, 当--hostname=其它任意fqdn时,等待docker启动成功后,在宿主机执行docker logs container_name,最后一行中,会显示设置的随机密码
* 首次启动时,由于主机名的关系,证书和相关配置需要重新生成,此时,容器虽已经启动,但相关服务并未配置完成; 主要时间开销在于首次启动容器时,根据参数重置配置的操作,笔者使用了脚本修改了部分配置后,重新执行foreman-installer导致,因此,首次完全启动成功,可能需要2分钟左右,具体的执行进度,可直接使用命令进入容器`docker exec -it [container_name] bash`后使用ps aux或top命令,查看foreman-installer在内存中是否已经执行完成即可. 再次使用时,由于puppet配置和foreman的数据库配置文件均已存在,则会非常迅速. 脚本见: `entrypoint.sh`
* 迁移现有的同版本,非docker方式的foreman/puppet时;需要把几个原先的目录依次放到指定目录,然后映射到容器,还需要备份原先的foreman的数据库,然后等容器初始化完成后,进入容器,下载刚才备份的数据库文件,然后删除foreman库,最后导入之前备份的数据库文件.需要提取的目录分别为: puppet配置文件目录 -> /etc/puppet ; puppet 库,证书等父目录 -> /var/lib/puppet ; 数据库操作需要直接使用postgresql的备份和恢复,使用foreman官方文档的中foreman-rake操作,笔者尝试多次,并未成功. 所有文件权限,需检查旧的文件的权限,在docker容器启动后,检查权限是否正常,否则会导致无法预知的错误,尤其是/var/lib/puppet目录下的文件,推荐直接chown -R puppet. /var/lib/puppet
* 由于rabbitmq并未在镜像中集成,因此,下面列出一份如何快速部署一个可被foreman/puppet-run使用的rabbitmq,当然,还是使用docker

```
1. 启动一个带管理页面的rabbitmq容器
  # docker run -itd --name mq -e RABBITMQ_DEFAULT_USER=admin -e RABBITMQ_DEFAULT_PASS=admin -e RABBITMQ_DEFAULT_VHOST=/ -p 61613:61613 -p 15672:15672 index.alauda.cn/library/rabbitmq:3.6.0-managemen

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
