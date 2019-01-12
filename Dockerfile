FROM nginx:alpine
MAINTAINER Adrien M amaurel90@gmail.com

ENV DEBUG=false KAP_DEBUG="0" 
ARG VERSION_KUBE_GEN="artifacts/master"

RUN apk add --no-cache nano ca-certificates unzip wget certbot bash openssl

# Install Forego & Kubectl & Kube-Gen-KAP
ADD https://github.com/jwilder/forego/releases/download/v0.16.1/forego /usr/local/bin/forego
ADD https://storage.googleapis.com/kubernetes-release/release/v1.3.4/bin/linux/amd64/kubectl /usr/local/bin/kubectl

RUN wget "https://gitlab.com/adi90x/kube-template-kap/builds/$VERSION_KUBE_GEN/download?job=compile-go" -O /tmp/kube-template-kap.zip \
	&& unzip /tmp/kube-template-kap.zip -d /usr/local/bin \
	&& chmod +x /usr/local/bin/kube-gen \
	&& chmod u+x /usr/local/bin/forego \
	&& chmod u+x /usr/local/bin/kubectl \
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
CMD ["forego", "start", "-r"]
