FROM index.alauda.cn/hypersroot/foreman-base:1.9.2

MAINTAINER "bw.y" <baowei.y@gmail.com>

COPY entrypoint.sh /entrypoint.sh

RUN chmod 755 /entrypoint.sh 

ENTRYPOINT ["/entrypoint.sh"]
