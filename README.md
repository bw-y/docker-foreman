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
* 此镜像包含直接可用的activemq,配置直接puppetlab的activemq的模板文档
* 此镜像版本号1.9.2.1中的1.9.2为foreman官方版本,末位.1为笔者构建的docker镜像版本

## 使用说明

###　启动一个容器提供puppet server服务,要求如下:
1. 证书名/主机名配置为: puppet.bw-y.com
2. 配置Mcollective和ActiveMQ的密码为: StlJT1Qk6cO6D2Aq
3. 配置Mcollective的psk密码为: lqtQ8Ci38HRSAXvY5fRVy7PZ
4. 启动ActiveMQ/apache2/foreman-proxy提供服务
5. 将容器内的puppet配置目录(`/etc/puppet`)映射到本地目录: `/opt/docker/puppet_conf`
6. 将容器内的puppet证书目录(`/var/lib/puppet/ssl`)映射到本地目录: `/opt/docker/puppet_ssl`
7. 将容器内的foreman数据库目录(`/var/lib/postgresql/9.3/main`)映射到本地目录: `/opt/docker/foreman_db`
8. 将容器内的下列端口(`80/443/8140/8443/61613`)映射到宿主机的对应端口: `80/443/8140/8443/61613`

### 根据上述要求,命令如下

```
docker run -itd --name=puppet --hostname=puppet.bw-y.com -e MCO_PASS=StlJT1Qk6cO6D2Aq -e PSK_PASS=lqtQ8Ci38HRSAXvY5fRVy7PZ -v /opt/docker/puppet_conf:/etc/puppet -v /opt/docker/puppet_ssl:/var/lib/puppet/ssl -v /opt/docker/foreman_db:/var/lib/postgresql/9.3/main -p 80:80 -p 443:443 -p 8140:8140 -p 8443:8443 -p 61613:61613 index.alauda.cn/hypersroot/docker-foreman:1.9.2.1
```

## 参数说明

### `--hostname`
[必选项] 由于puppet/foreman需要依赖一个可以解析的主机名用以配置证书相关,因此,在启动docker时,此参数务必加上,此参数会将配置的域名自动解析到容器对应的ip.  默认值: 空

### `MCO_HOST`
[可选项] 用于在Mcollective的(`/etc/mcollective/client.cfg`)中设置MQ的地址. `当此地址不等于127.0.0.1或localhost时,容器不启动ActiveMQ`. 默认值: 127.0.0.1

### `MCO_PORT`
[可选项] 用于在Mcollective的(`/etc/mcollective/client.cfg`)中设置MQ的端口. 默认值: 61613

### `MCO_PASS`
[可选项] 用于在Mcollective的客户配置(`/etc/mcollective/client.cfg`)和ActiveMQ的Server端配置(`/etc/activemq/activemq.xml`)所配置的密码. 默认值: mcopassword

### `PSK_PASS`
[可选项] 用于在Mcollective的(`/etc/mcollective/client.cfg`)中设置`plugin.psk`的密码字段. 默认值: mcopskstr

## 其它说明
* foreman页面的默认登陆信息: admin/bw-y.com
* 首次启动时,由于主机名的关系,证书和相关配置需要重新生成,此时,容器虽已经启动,但相关服务并未配置完成; 主要时间开销在于首次启动容器时,根据参数重置配置的操作,笔者使用了脚本修改了部分配置后,重新执行foreman-installer导致,因此,首次完全启动成功,可能需要2分钟左右,具体的执行进度,可直接使用命令进入容器`docker exec -it [container_name] bash`后使用ps aux或top命令,查看foreman-installer在内存中是否已经执行完成即可. 再次使用时,由于puppet配置和foreman的数据库配置文件均已存在,则会非常迅速. 脚本见: `entrypoint.sh`

