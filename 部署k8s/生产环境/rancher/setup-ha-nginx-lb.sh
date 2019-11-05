#!/bin/bash

#sh setup-ha-nginx-lb.sh 8888 "192.168.0.1:8080 192.168.0.2:8080 192.168.0.3:8080"

NGINX_PORT=${1:-"8888"}
#如果是多个服务，请使用空格进行分割，如"192.168.0.1:8080 192.168.0.2:8080"
RANCHER_SERVER=${2:-"127.0.0.1:8080"}

set -o errexit
set -o nounset
set -o pipefail

if [ ! -d "/etc/nginx" ]; then
    mkdir /etc/nginx
fi

if [ -f "/etc/nginx/nginx.conf" ]; then
    rm -rf /etc/nginx/nginx.conf
fi

NGINX_RANCHER_SERVER=""

for server in $RANCHER_SERVER;do
    NGINX_RANCHER_SERVER=$NGINX_RANCHER_SERVER"server "$server";";
done

cat > /etc/nginx/nginx.conf <<EOF
#user  nobody;
worker_processes  4;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;
#pid /usr/local/nginx/nginx.pid;

events {
    #use epoll;
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    fastcgi_intercept_errors on;
    charset  utf-8;
    server_names_hash_bucket_size 128;
    client_header_buffer_size 4k;
    large_client_header_buffers 4 32k;
    client_max_body_size 300m;
    sendfile on;
    tcp_nopush     on;
    keepalive_timeout 60;
    tcp_nodelay on;
    client_body_buffer_size  512k;
    proxy_connect_timeout    5;
    proxy_read_timeout       60;
    proxy_send_timeout       5;
    proxy_buffer_size        16k;
    proxy_buffers            4 64k;
    proxy_busy_buffers_size 128k;
    proxy_temp_file_write_size 128k;
    gzip on;
    gzip_min_length  1k;
    gzip_buffers     4 16k;
    gzip_http_version 1.1;
    gzip_comp_level 2;
    gzip_types       text/plain application/x-javascript text/css application/xml application/json;
    gzip_vary on;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';


    upstream rancher {
        $NGINX_RANCHER_SERVER
    }

    map \$http_upgrade \$connection_upgrade {
        default Upgrade;
        ''      close;
    }

    server {
        listen $NGINX_PORT;
        server_name rancher-server-nginx;

        location / {
            proxy_set_header Host \$host;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Port \$server_port;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_pass http://rancher;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            # This allows the ability for the execute shell window to remain open for up to 15 minutes. Without this parameter, the default is 1 minute and will automatically close.
            proxy_read_timeout 10s;
        }
    }

}
EOF


docker run -d --restart always \
    --name rancher-nginx-lb \
    -p $NGINX_PORT:$NGINX_PORT \
    -v /etc/nginx/nginx.conf:/etc/nginx/nginx.conf \
    -d nginx
