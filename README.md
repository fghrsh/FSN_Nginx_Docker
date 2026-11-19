# FSN VeryNginx Docker
VeryNginx Docker / FGHRSH Service Node Infrastructure

### 特性

- 启用 Strict-SNI<sup>1</sup>，保护源站 IP 不被 SSL 暴露
- 基于 Nginx 1.31.9 编译，集成 VeryNginx 脚本
- 支持 HTTP/2、HTTP/3、Brotli、Zstd、Headers More 等

> <sup>1</sup> 如遇 CDN 回源 503 错误，请修改 `nginx.conf`: `strict_sni off;`
　
## 使用

### 举个栗子

- Hello World
  - `/data/wwwroot/example.com` - 网站根目录
  - `/data/wwwlogs/example.com-xxx.log` - 网站日志记录
  - `/root/docker_data/nginx/ssl/example.com.crt(key)` - 存放证书
  - `/root/docker_data/nginx/vhosts/example.com.conf` - 网站配置文件

```shell
docker run -d --restart always \
 -p 80:80 -p 443:443 --name nginx \
 -v /data/wwwroot:/data/wwwroot \
 -v /data/wwwlogs:/data/wwwlogs \
 -v /root/docker_data/nginx/ssl:/etc/nginx/ssl:ro \
 -v /root/docker_data/nginx/vhosts:/etc/nginx/vhosts:ro \
 fghrsh/fsn_nginx:verynginx
 ```

- Advanced Setting
  - `mkdir -p /root/docker_data/nginx/` - 创建存放配置的目录，可自行修改
  - `curl -fSL https://raw.githubusercontent.com/fghrsh/FSN_Nginx_Docker/verynginx/conf/nginx.conf > /root/docker_data/nginx/nginx.conf`
  - `curl -fSL https://raw.githubusercontent.com/fghrsh/FSN_Nginx_Docker/verynginx/verynginx/configs/config.json > /root/docker_data/nginx/verynginx.json`
  - `setfacl -m u:82:rw /root/docker_data/nginx/verynginx.json`
  - `vim /root/docker_data/nginx/nginx.conf` - 编辑 nginx.conf

```shell
docker run -d --restart always \
 -p 80:80 -p 443:443 --name nginx \
 -v /data/wwwroot:/data/wwwroot \
 -v /data/wwwlogs:/data/wwwlogs \
 -v /etc/localtime:/etc/localtime:ro \
 -v /root/docker_data/nginx/ssl:/etc/nginx/ssl:ro \
 -v /root/docker_data/nginx/vhosts:/etc/nginx/vhosts:ro \
 -v /root/docker_data/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
 -v /root/docker_data/nginx/verynginx.json:/opt/verynginx/configs/config.json \
 --network fsn fghrsh/fsn_nginx:verynginx
 ```
 
 - 参数说明
   - `/etc/localtime` - 用于同步 宿主机 时区设置
   - `docker network create fsn` - 创建 fsn 网络，用于容器间连接
   - `docker run --network fsn` - 接入 fsn 网络（视情况修改，不需要可去除

### nginx.vhost.default.conf

```
server {
    listen 80;
    listen 443 ssl http2;
    
    # this line shoud be include in every server block
    include /opt/verynginx/nginx_conf/in_server_block.conf;
    
    server_name example.com;
    root /data/wwwroot/example.com;
    index index.html index.htm index.php;
    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    
    location ~ \.php$ {
        fastcgi_pass   php-example:9000;
        fastcgi_index  index.php;
        fastcgi_param  DOCUMENT_ROOT   /data/wwwroot/example.com;
        fastcgi_param  SCRIPT_FILENAME /data/wwwroot/example.com$fastcgi_script_name;
        include fastcgi.conf;
    }
    
    access_log /data/wwwlogs/example.com-access.log main;
    error_log /data/wwwlogs/example.com-error.log crit;
}
```

　
## Thanks
> (๑´ㅁ`) 都看到这了，点个 Star 吧 ~

- [VeryNginx / @alexazhou / LGPL-3.0][1]  
- docker nginx / [@nginxinc][2], [@lwl12][3], [@metowolf][4]  

  [1]: https://github.com/alexazhou/VeryNginx "VeryNginx is a very powerful and friendly nginx."
  [2]: https://github.com/nginxinc/docker-nginx "Official NGINX Dockerfiles"
  [3]: https://github.com/lwl12/LFS-Docker-Nginx "LWL Gen3 Server Infrastructure - Nginx"
  [4]: https://github.com/metowolf/docker-nginx "LEMP (Linux + Nginx + MySQL + PHP)"
