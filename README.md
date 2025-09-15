# 说明

本项目主要用于快速部署prometheus、alertmanager、grafana、dingtalk、consul等监控报警服务。

### docker-compose安装

```
打开URL找到你需要的版本
https://github.com/docker/compose/releases/

复制下载链接并下载，如下
wget https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-x86_64

移动到bin目录下，并给运行权限
mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 启动服务

```
# 启动容器
docker-compose -f monitor-compose.yml up -d
# 访问 
http://IP+port
```

### 修改配置

```
主要文件说明：
prometheus.yml            #prometheus配置文件
alertmanager.yml          #alertmanager配置文件
config.yml                #dingtalk钉钉配置文件
grafana.ini               #grafana配置文件
default.tmpl              #alertmanager报警模板
monitor-compose.yml       #docker-compose file文件 
monitor-compose-nginx.yml #docker-compose file文件，带nginx 

修改prometheus配置文件，添加监控任务，如：
- job_name: 'node-exporter'
    static_configs:
    - targets: ['10.10.100.221:9100','10.10.100.222:9100','10.10.100.223:9100']
    
    
修改alertmanager配置文件，添加监控报警的接收者，如：
...
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 600s
  repeat_interval: 1h
  receiver: 'wechat'  #设置默认的报警接收者
receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/'   #可以自定义配置。比如自研的报警平台。
- name: 'DingDing'
  webhook_configs:
  - url: 'http://dingtalk:8086/dingtalk/webhook1/send' #钉钉dingtalk
    send_resolved: true
- name: 'wechat'                    #企业微信
  wechat_configs:
  - send_resolved: true
    corp_id: 'wwd123456789'    #企业微信ID
    to_party: '3'                    #部门ID
    to_user: 'username|tom|hanmeimei'     #用户名
    agent_id: '1000004'              #应用ID
    api_secret: 'ncvhKhQ38LyF123456'  #应用api_secret
    message: '{{ template "marathon.message" . }}'             #报警模板
...

#修改dingtalk配置文件，添加钉钉，修改access_token和secret为自己群机器人相应的参数。
targets:
  webhook1:
    url: https://oapi.dingtalk.com/robot/send?access_token=93c2bd1480657fdb7a0ecd74d8959955c8aec373c
    # secret for signature
    secret: SEC2f655ad23c3c23965f649bc53ce39d9a6759de1ab299a
```



### 使用nginx反向代理

```
# 使用nginx反向代理
docker-compose -f monitor-compose-nginx.yml up -d

#linux下生成web密码验证文件，用于登录验证。
echo monitor:`openssl passwd -crypt 123456` > .htpasswd

在compose.yml添加nginx
version: '3.2'
services:
  nginx:
    image: sxlsteven/alpine:nginx1.0.0
    container_name: nginx
    user: root
    privileged: true
    #network_mode: "host"
    restart: always
    ports:
      - 80:80
      - 9090:9090
      - 9093:9093
      - 3000:3000
    links:
      - prometheus
      - alertmanager
      - grafana
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/proxy.conf:/etc/nginx/conf.d/proxy.conf:ro
      - ./nginx/.htpasswd:/etc/nginx/basic_auth/.htpasswd:ro

第一种方法：只需要修改nginx, 经过测试是可以的。访问时直接IP+port.  proxy.conf的内容如下：

# this is required to proxy Grafana Live WebSocket connections.
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}
server {
      listen 3000;
      server_name  _;
     
      location / {
        proxy_pass http://grafana:3000;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
  
    # Proxy Grafana Live WebSocket connections.
      location /api/live/ {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $http_host;
        proxy_pass http://grafana:3000;
      }
}

server {
      listen 9090;
      server_name  _;
     
      location / {
        proxy_pass http://prometheus:9090;
        auth_basic "auth for monitor";
        auth_basic_user_file /etc/nginx/basic_auth/.htpasswd;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
server {
      listen 9093;
      server_name  _;
     
      location / {
        proxy_pass http://alertmanager:9093;
        auth_basic "auth for monitor";
        auth_basic_user_file /etc/nginx/basic_auth/.htpasswd;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
      listen 8500;
      server_name  _;
     
      location / {
        proxy_pass http://consul:8500;
        # auth_basic "auth for monitor";
        # auth_basic_user_file /etc/nginx/basic_auth/.htpasswd;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    } 
}

第二种方法：使用域名访问，访问时： 域名+相应的url。 另外还需要修改prometheus/alertmanager/grafana的启动命令和配置文件才能访问到。可以参考官网介绍，下面有链接。 访问时直接绑定host或者添加DNS解析记录。

# this is required to proxy Grafana Live WebSocket connections.
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}
server {
      listen 80;
      server_name  monitor.abc.com;
     
      location /grafana/ {
        rewrite  ^/grafana/(.*)  /$1 break;
        proxy_pass http://grafana:3000;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }


      location /grafana/api/live/ {
        rewrite  ^/grafana/(.*)  /$1 break;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $http_host;
        proxy_pass http://grafana:3000;
  }
      location /prometheus {
        #rewrite  ^/prometheus/(.*)$  /$1 break;
        proxy_pass http://prometheus:9090;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
      location /alertmanager/ {
        #rewrite  ^/alertmanager/(.*)$  /$1 break;
        proxy_pass http://alertmanager:9093/;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}


如grafana
# vim /etc/grafana/grafana.ini
root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana
serve_from_sub_path = true

如prometheus，在启动的时候设置web.external-url。
--web.external-url=prometheus

如alertmanager，在启动的时候设置web.external-url，注意这个和prometheus不太一样，需要写完整的域名，否则启动异常。
--web.external-url=http://monitor.abc.com/alertmanager

注意： prometheus相关的程序几乎都带有这个参数--web.external-url，根据需要添加

--web.external-url： 专门用于设置通过反向代理访问。 设置Prometheus外部可访问的URL，用于生成与普罗米修斯本身的相对和绝对联系。如果URL有路径部分，它将被用于所有HTTP端点的前缀。

参考链接：
https://grafana.com/tutorials/run-grafana-behind-a-proxy/
https://www.cnblogs.com/caoweixiong/p/12155712.html

```



### 其它 

```
docker-compose.yml文件更新之后，直接重新docker-compose -f monitor-compose.yml up -d即可。
对修改的服务会进行重建，对于没有修改的会输出dingtalk is up-to-date

看如下日志输出：
[root@bigops-server monitor]# docker-compose -f monitor-compose.yml up -d
dingtalk is up-to-date
grafana is up-to-date
alertmanager is up-to-date
Recreating prometheus ... done


```

### docker容器镜像加速
```
可以直接使用docker目录下的daemon.json

```

