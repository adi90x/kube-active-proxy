#Use alpine as base
FROM nginx:alpine

MAINTAINER Adrien M amaurel90@gmail.com

#Recup la valeur used for multiarch building
ARG TARGETARCH="amd64"

#Use also build arg
ARG VERSION_KUBE_GEN="artifacts/master"
ARG KAP_VERSION=master
ENV DEBUG=false KAP_DEBUG="0" KAP_VERSION=$KAP_VERSION

RUN apk add --no-cache nano ca-certificates unzip wget certbot bash openssl supervisor

# Install Kube-Gen-KAP
RUN wget "https://gitlab.com/adi90x/kube-template-kap/builds/$VERSION_KUBE_GEN/download?job=compile-go-$TARGETARCH" -O /tmp/kube-template-kap.zip \
        && unzip /tmp/kube-template-kap.zip -d /usr/local/bin \
	&& chmod u+x /usr/local/bin/kube-template-kap \
	&& rm -f /tmp/kube-template-kap.zip

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
CMD ["supervisord", "-c", "/app/supervisord.conf"]
