FROM nginx:alpine
MAINTAINER Adrien M amaurel90@gmail.com

ENV DEBUG=false KAP_DEBUG="info" 
ARG VERSION_kube_GEN="artifacts/master"

RUN apk add --no-cache nano ca-certificates unzip wget certbot bash openssl

# Install Forego & kube-Gen-KAP
ADD https://github.com/jwilder/forego/releases/download/v0.16.1/forego /usr/local/bin/forego

RUN wget "https://gitlab.com/adi90x/rancher-gen-rap/builds/$VERSION_kube_GEN/download?job=compile-go" -O /tmp/kube-gen-KAP.zip \
	&& unzip /tmp/kube-gen-KAP.zip -d /usr/local/bin \
	&& chmod +x /usr/local/bin/kube-gen \
	&& chmod u+x /usr/local/bin/forego \
	&& rm -f /tmp/kube-gen-KAP.zip
	
#Copying all templates and script	
COPY /app/ /app/
WORKDIR /app/

# Seting up repertories & Configure Nginx and apply fix for very long server names
RUN chmod +x /app/letsencrypt.sh \
    && mkdir -p /etc/nginx/certs /etc/nginx/vhost.d /etc/nginx/conf.d /usr/share/nginx/html /etc/letsencrypt \
    && echo "daemon off;" >> /etc/nginx/nginx.conf \
    && sed -i 's/^http {/&\n    server_names_hash_bucket_size 128;/g' /etc/nginx/nginx.conf \
    && chmod u+x /app/remove 

ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh" ]
CMD ["forego", "start", "-r"]
