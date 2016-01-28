FROM index.alauda.cn/hypersroot/foreman-base:1.10.1

MAINTAINER "bw.y" <baowei.y@gmail.com>

ENV LANG "en_US.UTF-8"
ENV LANGUAGE "en_US:en"

COPY entrypoint.sh /entrypoint.sh

RUN chmod 755 /entrypoint.sh 

EXPOSE 80
EXPOSE 443
EXPOSE 8140
EXPOSE 8443

ENTRYPOINT ["/entrypoint.sh"]
