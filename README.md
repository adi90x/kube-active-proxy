![nginx latest](https://img.shields.io/badge/nginx-latest-brightgreen.svg)[![build status](https://gitlab.com/adi90x/kube-active-proxy/badges/master/build.svg)](https://gitlab.com/adi90x/kube-active-proxy/commits/master)  ![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)   [![Docker Pulls](https://img.shields.io/docker/pulls/adi90x/kube-active-proxy.svg)](https://hub.docker.com/r/adi90x/kube-active-proxy/)  [![Docker Automated buil](https://img.shields.io/docker/automated/adi90x/kube-active-proxy.svg)](https://hub.docker.com/r/adi90x/kube-active-proxy/)


## Kube Active Proxy

Kube Active Proxy is an all-in-one reverse proxy for [Kubernetes](https://kubernetes.io/), supporting Letsencrypt out of the box !

Kube Active Proxy is a copy of my [Rancher-Active-Proxy](https://gitlab.com/adi90x/rancher-active-proxy) application.

Kube Active Proxy is based on the excellent idea of [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy).

Kube Active Proxy replace docker-gen by kube-template-kap [adi90x/kube-template-kap](https://github.com/adi90x/kube-template-kap) ( a fork of the also excellent [3cky/kube-template](https://github.com/3cky/kube-template) adding some more function )

Kube Active Proxy use annotation on pod or services to setup nginx proxy.

I would recommend to use latest image from DockerHub or you can use tag versions. Keep in mind that branch are mostly development features and could not work as expected.

### TODO

-- Easy Setup with Helm

### Usage

Minimal Params To run it:

    $ kubectl -f apply kube-active-proxy.yaml

This will create a daemonset with an host selector based on the following label: `kap/front="true"` - Add this label to any node to start using it as a KAP frontend.
This will also create a Service Account for Kube-Active-Proxy with access to Services and Pods in the namespace set.

Then start any pods or service you want proxied with an annotation : `kap/host=subdomain.youdomain.com`

    $ metadata:
        annotations:
           kap/host: foo.bar.com

The containers being proxied must [expose](https://docs.docker.com/engine/reference/run/#expose-incoming-ports) the port to be proxied, either by using the `EXPOSE` directive in their `Dockerfile` or by using the `--expose` flag to `docker run` or `docker create`.

Provided your DNS is setup to forward foo.bar.com to the a host running `kube-active-proxy`, the request will be routed to a container with the `kap/host` label set.

At the moment, all namespaces that SA has access will be check for any label. ( TODO : Add a way to limit to some specific namespaces)

#### Summary of available labels for proxied pods/services.


|       Label                |            Description         |
| ---------------------------|------------------------------- |
| `kap/host`                 | Virtual host to use ( several value could be separate by `,` )
| `kap/port`                 | Port of the container to use ( only needed if several port are exposed ). Default `Expose Port` or `80`
| `kap/proto`                | Protocol used to contact container ( http,https,uwsgi ). Default : `http`
| `kap/timeout`              | Timeout for reading from this container ( in seconds ). Default : nginx default (60s)
| `kap/cert_name`            | Certificate name to use for the virtual host. Default `kap/host`
| `kap/https_method`         | Https method (redirect, noredirect, nohttps). Default : `redirect`
| `kap/le_host`              | Certificate to create/renew with Letsencrypt
| `kap/le_email`             | Email to use for Letsencrypt
| `kap/le_test  `            | Set to true to use stagging letsencrypt server
| `kap/le_bypass`            | Set to true to create a special bypass to use LE
| `kap/http_listen_ports`    | External Port you want kube-Active-Proxy to listen to http for this server ( Default : `80` )
| `kap/https_listen_ports`   | External Port you want kube-Active-Proxy to listen to https for this server ( Default : `443` )
| `kap/server_tokens`    	   | Enable to specify the server_token value per container
| `kap/client_max_body_size` | Enable to specify the client_max_body_size directive per container
| `kap/kap_name`             | If `kap_name` is specified for a kap instance only container with label value matching `kap_name` value will be publish

#### Summary of environment variable available for Kube Active Proxy.

|       Label        |            Description         |
| ------------------ | ------------------------------ |
| `DEBUG`            | Set to `true` to enable more output. Default : `False`
| `CRON`             | Cron like expression to define when certs are renew. Default : `0 2 * * *`
| `DEFAULT_HOST`     | Default Nginx host.
| `DEFAULT_EMAIL`    | Default Email for Letsencrypt.
| `KAP_LE_TEST`      | If set to `true` all LE request will be against stagging API ( usefull for test )
| `KAP_DEBUG` 		   | Define kube-Gen-kap verbosity (Valid values: "debug", "info", "warn", and "error"). Default: `info`
| `DEFAULT_PORT` 	   | Default port use for containers ( Default : `80` )
| `SPECIFIC_HOST` 	 | Limit kap to only containers of a specific host name
| `KAP_NAME` 	       | If specify kap will only publish service with `kap/kap_name = kap_NAME`
| `ACME_INTERNAL` 	 | Enable passing ACME request to another RAP instance

#### Quick Summary of interesting volume to mount.

|       Path            |            Description         |
| --------------------- | ------------------------------ |
| `/etc/letsencrypt`    | Folder with all certificates used for https and Letsencrypt parameters
| `/etc/nginx/htpasswd` | Basic Authentication Support ( file should be `kap/host`)
| `/etc/nginx/vhost.d`  | Specifc vhost configuration ( file should be `kap/host`) . Location configuration should end with `_location`

#### Let's Encrypt support out of box

Kube Active Proxy is using `certbot` from Let's Encrypt in order to automatically get SSL certificates for containers.

In order to enable that feature you need to add `kap/le_host` label to the container ( you probably want it to be equal to `kap/host`)

And you should either start Kube Active Proxy with environment variable `DEFAULT_EMAIL` or specify `kap/le_email` as a container label.

If you are developing I recommend to add `kap/le_test=true` to the container in order to use Let's Encrypt staging environment and to not exceed limits.

#### SAN certificates

Kube Active Proxy support SAN certifcates ( one certificate for several domains ).

To create a SAN certificate you need to separate hostnames with ";" ( instead of "," for separate domains)

`kap/le_host=admin.foo.com;api.foo.com;mail.foo.com`

This will create a single certificate matching : admin.foo.com, api.foo.com, mail.foo.com .
The certificate created will be named `admin.foo.com` but symlink will be create to match all domains.


### Multiple Ports

If your container exposes multiple ports, Kube Active Proxy will use `kap/port` label, then use the exposed port if there is only one port exposed, or default to `DEFAULT_PORT` environmental variable ( which is set by default to `80` ).
Or you can try your hand at the [Advanced `kap/host` syntax](#advanced-kaphost-syntax).

### Special ByPass for Let's Encrypt

If your container uses its own letsencrypt process to get some certificates
Set `kap/le_bypass` to `true` to add a location to the http server block to forward `/.well-known/acme-certificate/` to upstream through http instead of redirecting it to https

### Advanced `kap/host` syntax

Using the Advanced `kap/host` syntax you can specify multiple host names to each go to their own backend port.
Basically this provides support for `kap/host`, `kap/port`, and `kap/proto` all in one field.

For example, given the following:

```
kap/host=api.example.com=>http:80,api-admin.example.com=>http:8001,secure.example.com=>https:8443
```

This would yield 3 different server/upstream configurations...

 1. Requests for api.example.com would route to this container's port 80 via http
 2. Requests for api-admin.example.com would route to this containers port 8001 via http
 3. Requests for secure.example.com would route to this containers port 8443 via https


### Multiple Listening Port

If needed you can use kube-Active-Proxy to listen for different ports.

`docker run -d -p 8081:8081 -p 81:81  adi90x/kube-active-proxy`

In this case, you can specify on which port Kube Active Proxy should listen for a specific hostname :

`docker run -d -l kap/host=foo.bar.com -l kap/http_listen_ports="81,8081" -l kap/port="53" containerexposing/port53`

In this situation Kube Active Proxy will listen for request matching `kap/host` on both port `81` and `8081` of your host
and route those request to port `53` of your container.

Likewise, `kap/https_listen_ports` will work for https requests.

If you are not using port `80` and `443` at all you won't be able to use Let's Encrypt Automatic certificates.

### Specific Host Name

Using environmental value `SPECIFIC_HOST` you can limit Kube Active Proxy to containers running on a single host.

Just start Kube Active Proxy like that : `docker run -d -p 80:80 -e SPECIFIC_HOST=Hostnameofthehost adi90x/kube-active-proxy`

### Remove Script

Kube Active Proxy provides an easy script to revoke/delete a certificate.

You can run it : `docker run adi90x/kube-active-proxy /app/remove DomainCertToRemove`

Script is adding '*' at the end of the command therefore `/app/remove foo` will delete `foo.bar.com , foo.bar.org, foo.bar2.com ..`

_Special attention_: If you are using it with SAN certificates you need to be careful and run it for each domain in the SAN certificate.

Do not forget to delete the label on the container before using that script or it will be recreated on next update.

If you are starting it with kube do not forget to set Auto Restart : Never (Start Once)

### Per-host server configuration

If you want to 100% personalize your server section on a per-`kap/host` basis, add your server configuration in a file under `/etc/nginx/vhost.d`
The file should use the suffix `_server`.

For example, if you have a virtual host named `app.example.com` and you have configured a proxy_cache `my-cache` in another custom file, you could tell it to use a proxy cache as follows:

    $ docker run -d -p 80:80 -p 443:443 -v /path/to/vhost.d:/etc/nginx/vhost.d:ro adi90x/kube-active-proxy

You should therefore have a file `app.example.com_server` in the `/etc/nginx/vhost.d` folder that contains the whole server block you want to use :

```
server {
        server_name app.example.com
        listen 80;
        access_log /var/log/nginx/access.log vhost;

        location / {
                proxy_pass http://app.example.com;
        }
}

```

If you are using multiple hostnames for a single container (e.g. `kap/host=example.com,www.example.com`), the virtual host configuration file must exist for each hostname.
If you would like to use the same configuration for multiple virtual host names, you can use a symlink.

### Per-host server default configuration

If you want most of your virtual hosts to use a default single `server` block configuration and then override it on a few specific ones, add a `/etc/nginx/vhost.d/default_server` file.
This file will be used on any virtual host which does not have a `/etc/nginx/vhost.d/{kap/host}_server` file associated with it.

### Limit kap to some containers

If you want a kap instance to only publish some specific containers/services, you can start the kap container with environment variable `kap_NAME = example`
In that situation, all containers to be published by this instance of kap should have a label `kap/kap_name = example`
If a container should be published by several kap instances just use a label matching regex like `kap/kap_name = internal,external` to be published by kap instance named `internal` or `external`

***

The below part is mostly taken from jwilder/nginx-proxy [README](https://github.com/jwilder/nginx-proxy/blob/master/README.md) and modified to reflect Kube Active Proxy

### Multiple Hosts

If you need to support multiple virtual hosts for a container, you can separate each entry with commas.  For example, `foo.bar.com,baz.bar.com,bar.com` and each host will be setup the same.

### Wildcard Hosts

You can also use wildcards at the beginning and the end of host name, like `*.bar.com` or `foo.bar.*`. Or even a regular expression, which can be very useful in conjunction with a wildcard DNS service like [xip.io](http://xip.io), using `~^foo\.bar\..*\.xip\.io` will match `foo.bar.127.0.0.1.xip.io`, `foo.bar.10.0.2.2.xip.io` and all other given IPs. More information about this topic can be found in the nginx documentation about [`server_names`](http://nginx.org/en/docs/http/server_names.html).

### SSL Backends

If you would like the reverse proxy to connect to your backend using HTTPS instead of HTTP
set `kap/proto=https` on the backend container.

### uWSGI Backends

If you would like to connect to uWSGI backend, set `kap/proto=uwsgi` on the backend container.
Your backend container should than listen on a port rather than a socket and expose that port.

### Default Host

To set the default host for nginx use the env var `DEFAULT_HOST=foo.bar.com` for example :

    $ docker run -d -p 80:80 -e DEFAULT_HOST=foo.bar.com adi90x/kube-active-proxy

### SSL Support

SSL is supported using single host, wildcard and SNI certificates using naming conventions for certificates
or optionally specifying a cert name (for SNI) as an environment variable.

To enable SSL:

    $ docker run -d -p 80:80 -p 443:443 -v /path/to/certs:/etc/nginx/certs  adi90x/kube-active-proxy

The contents of `/path/to/certs` should contain the certificates and private keys for any virtual
hosts in use.  The certificate and keys should be named after the virtual host with a `.crt` and
`.key` extension.  For example, a container with label `kap/host=foo.bar.com` should have a
`foo.bar.com.crt` and `foo.bar.com.key` file in the certs directory.

If you are running the container in a virtualized environment (Hyper-V, VirtualBox, etc...),
`/path/to/certs` must exist in that environment or be made accessible to that environment.
By default, Docker is not able to mount directories on the host machine to containers running in a virtual machine.

### Diffie-Hellman Groups

If you have Diffie-Hellman groups enabled, the files should be named after the virtual host with a
`dhparam` suffix and `.pem` extension. For example, a container with `kap/host=foo.bar.com`
should have a `foo.bar.com.dhparam.pem` file in the certs directory.

### Wildcard Certificates

Wildcard certificates and keys should be named after the domain name with a `.crt` and `.key` extension.
For example `kap/host=foo.bar.com` would use cert name `bar.com.crt` and `bar.com.key`.

### SNI

If your certificate(s) supports multiple domain names, you can start a container with `kap/cert_name=<name>`
to identify the certificate to be used.  For example, a certificate for `*.foo.com` and `*.bar.com`
could be named `shared.crt` and `shared.key`.  A container running with `kap/host=foo.bar.com`
and `kap/cert_name=shared` will then use this shared cert.

### How SSL Support Works

The SSL cipher configuration is based on [mozilla nginx intermediate profile](https://wiki.mozilla.org/Security/Server_Side_TLS#Nginx) which
should provide compatibility with clients back to Firefox 1, Chrome 1, IE 7, Opera 5, Safari 1,
Windows XP IE8, Android 2.3, Java 7.  The configuration also enables HSTS, and SSL
session caches.

The default behavior for the proxy when port 80 and 443 are exposed is as follows:

* If a container has a usable cert, port 80 will redirect to 443 for that container so that HTTPS
is always preferred when available.
* If the container does not have a usable cert, a 503 will be returned.

Note that in the latter case, a browser may get an connection error as no certificate is available
to establish a connection.  A self-signed or generic cert named `default.crt` and `default.key`
will allow a client browser to make a SSL connection (likely w/ a warning) and subsequently receive
a 503.

To serve traffic in both SSL and non-SSL modes without redirecting to SSL, you can include the
label  `kap/https_method=noredirect` (the default is `kap/https_method=redirect`).  You can also
disable the non-SSL site entirely with `kap/https_method=nohttp`. `kap/https_method` must be specified
on each container for which you want to override the default behavior.  If `kap/https_method=noredirect` is
used, Strict Transport Security (HSTS) is disabled to prevent HTTPS users from being redirected by the
client.  If you cannot get to the HTTP site after changing this setting, your browser has probably cached
the HSTS policy and is automatically redirecting you back to HTTPS.  You will need to clear your browser's
HSTS cache or use an incognito window / different browser.

### Basic Authentication Support

In order to be able to secure your virtual host, you have to create a file named as its equivalent `kap/host` label on directory
/etc/nginx/htpasswd/`kap/host`

```
$ docker run -d -p 80:80 -p 443:443 \
    -v /path/to/htpasswd:/etc/nginx/htpasswd \
    -v /path/to/certs:/etc/nginx/certs \
    adi90x/kube-active-proxy
```

You'll need apache2-utils on the machine where you plan to create the htpasswd file.
Or you can use an nginx container to create the file ( using OpenSSL as explained in [Nginx Readme](http://wiki.nginx.org/Faq#How_do_I_generate_an_.htpasswd_file_without_having_Apache_tools_installed.3F) )

`docker run -it nginx printf "Username_to_use:$(openssl passwd -crypt Password_to_use)\n" >> /path/to/htpasswd/{kap/host}`

A default htpasswd can be used to secure all hosts using this proxy. Good for development environments to keep prying eyes out. To use, create the htpasswd file named 'default' here: `/etc/nginx/htpasswd/default`.

### Custom Nginx Configuration

If you need to configure Nginx beyond what is possible using environment variables, you can provide custom configuration files on either a proxy-wide or per-`kap/host` basis.

### Replacing default proxy settings

If you want to replace the default proxy settings for the nginx container, add a configuration file at `/etc/nginx/proxy.conf`. A file with the default settings would
look like this:

```Nginx
# HTTP 1.1 support
proxy_http_version 1.1;
proxy_buffering off;
proxy_set_header Host $http_host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $proxy_connection;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $proxy_x_forwarded_proto;
proxy_set_header X-Forwarded-Port $proxy_x_forwarded_port;

# Mitigate httpoxy attack (see README for details)
proxy_set_header Proxy "";
```

***NOTE***: If you provide this file it will replace the defaults; you may want to check the nginx.tmpl file to make sure you have all of the needed options.

***NOTE***: The default configuration blocks the `Proxy` HTTP request header from being sent to downstream servers.  This prevents attackers from using the so-called [httpoxy attack](http://httpoxy.org).  There is no legitimate reason for a client to send this header, and there are many vulnerable languages / platforms (`CVE-2016-5385`, `CVE-2016-5386`, `CVE-2016-5387`, `CVE-2016-5388`, `CVE-2016-1000109`, `CVE-2016-1000110`, `CERT-VU#797896`).

### Proxy-wide

To add settings on a proxy-wide basis, add your configuration file under `/etc/nginx/conf.d` using a name ending in `.conf`.

This can be done in a derived image by creating the file in a `RUN` command or by `COPY`ing the file into `conf.d`:

```Dockerfile
FROM adi90x/kube-active-proxy
RUN { \
      echo 'server_tokens off;'; \
      echo 'client_max_body_size 100m;'; \
    } > /etc/nginx/conf.d/my_proxy.conf
```

Or it can be done by mounting in your custom configuration in your `docker run` command:

    $ docker run -d -p 80:80 -p 443:443 -v /path/to/my_proxy.conf:/etc/nginx/conf.d/my_proxy.conf:ro adi90x/kube-active-proxy

### Per-VIRTUAL_HOST

To add settings on a per-`kap/host` basis, add your configuration file under `/etc/nginx/vhost.d`. Unlike in the proxy-wide case, which allows multiple config files with any name ending in `.conf`, the per-`kap/host` file must be named exactly after the `kap/host`.

In order to allow virtual hosts to be dynamically configured as backends are added and removed, it makes the most sense to mount an external directory as `/etc/nginx/vhost.d` as opposed to using derived images or mounting individual configuration files.

For example, if you have a virtual host named `app.example.com`, you could provide a custom configuration for that host as follows:

    $ docker run -d -p 80:80 -p 443:443 -v /path/to/vhost.d:/etc/nginx/vhost.d:ro adi90x/kube-active-proxy
    $ { echo 'server_tokens off;'; echo 'client_max_body_size 100m;'; } > /path/to/vhost.d/app.example.com

If you are using multiple hostnames for a single container (e.g. `kap/host=example.com,www.example.com`), the virtual host configuration file must exist for each hostname. If you would like to use the same configuration for multiple virtual host names, you can use a symlink:

    $ { echo 'server_tokens off;'; echo 'client_max_body_size 100m;'; } > /path/to/vhost.d/www.example.com
    $ ln -s /path/to/vhost.d/www.example.com /path/to/vhost.d/example.com

### Per-VIRTUAL_HOST default configuration

If you want most of your virtual hosts to use a default single configuration and then override on a few specific ones, add those settings to the `/etc/nginx/vhost.d/default` file. This file
will be used on any virtual host which does not have a `/etc/nginx/vhost.d/{kap/host}` file associated with it.

### Per-VIRTUAL_HOST location configuration

To add settings to the "location" block on a per-`kap/host` basis, add your configuration file under `/etc/nginx/vhost.d`
just like the previous section except with the suffix `_location`.

For example, if you have a virtual host named `app.example.com` and you have configured a proxy_cache `my-cache` in another custom file, you could tell it to use a proxy cache as follows:

    $ docker run -d -p 80:80 -p 443:443 -v /path/to/vhost.d:/etc/nginx/vhost.d:ro adi90x/kube-active-proxy
    $ { echo 'proxy_cache my-cache;'; echo 'proxy_cache_valid  200 302  60m;'; echo 'proxy_cache_valid  404 1m;' } > /path/to/vhost.d/app.example.com_location

If you are using multiple hostnames for a single container (e.g. `kap/host=example.com,www.example.com`), the virtual host configuration file must exist for each hostname. If you would like to use the same configuration for multiple virtual host names, you can use a symlink:

    $ { echo 'proxy_cache my-cache;'; echo 'proxy_cache_valid  200 302  60m;'; echo 'proxy_cache_valid  404 1m;' } > /path/to/vhost.d/app.example.com_location
    $ ln -s /path/to/vhost.d/www.example.com /path/to/vhost.d/example.com

### Per-VIRTUAL_HOST location default configuration

If you want most of your virtual hosts to use a default single `location` block configuration and then override on a few specific ones, add those settings to the `/etc/nginx/vhost.d/default_location` file. This file
will be used on any virtual host which does not have a `/etc/nginx/vhost.d/{kap/host}` file associated with it.

## Contributing

Do not hesitate to send issues or pull requests !

Automated Gitlab CI is used to build Kube Active Proxy therefore send any pull request/issues to [Kube Active Proxy on Gitlab.com](https://gitlab.com/adi90x/kube-active-proxy/)
