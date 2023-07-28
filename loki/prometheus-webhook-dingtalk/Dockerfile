FROM alpine:latest
LABEL Author="steven" \
      Email="sxl_youcun@qq.com" \
      Dingtalk_Version="v2.1.0"

WORKDIR /usr/local/dingtalk

ADD dingtalk/* ./

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
    && apk update \
    && apk --no-cache add  wget curl tzdata \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    echo "export LC_ALL=en_US.UTF-8"  >>  /etc/profile

EXPOSE 8086

CMD ["--web.listen-address=0.0.0.0:8086","--config.file=config.yml","--web.enable-ui","--web.enable-lifecycle"]

ENTRYPOINT ["/usr/local/dingtalk/prometheus-webhook-dingtalk"]
