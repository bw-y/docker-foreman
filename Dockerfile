FROM index.alauda.cn/hypersroot/foreman:base

MAINTAINER "bw.y" <baowei.y@gmail.com>

COPY entrypoint.sh /entrypoint.sh

RUN chmod 755 /entrypoint.sh 

ENTRYPOINT ["/entrypoint.sh"]
