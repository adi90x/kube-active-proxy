FROM nginx:alpine
MAINTAINER Adrien M amaurel90@gmail.com

ENV DEBUG=false KAP_DEBUG="info" 
ARG VERSION_KUBE_GEN="artifacts/master"

RUN apk add --no-cache nano ca-certificates unzip wget certbot bash openssl

# Install Forego & kube-Gen-KAP
ADD https://github.com/jwilder/forego/releases/download/v0.16.1/forego /usr/local/bin/forego

#RUN wget "https://gitlab.com/adi90x/kube-gen-rap/builds/$VERSION_KUBE_GEN/download?job=compile-go" -O /tmp/kube-gen-KAP.zip \
#	&& unzip /tmp/kube-gen-KAP.zip -d /usr/local/bin \
#	&& chmod +x /usr/local/bin/kube-gen \
#	&& chmod u+x /usr/local/bin/forego \
#	&& rm -f /tmp/kube-gen-KAP.zip
	
#Copying all templates and script	
COPY /app/ /app/
WORKDIR /app/

# Seting up repertories & Configure Nginx and apply fix for very long server names
RUN chmod +x /app/letsencrypt.sh \
    && mkdir -p /etc/nginx/certs /etc/nginx/vhost.d /etc/nginx/conf.d /usr/share/nginx/html /etc/letsencrypt \
    && echo "daemon off;" >> /etc/nginx/nginx.conf \
    && sed -i 's/^http {/&\n    server_names_hash_bucket_size 128;/g' /etc/nginx/nginx.conf \
    && chmod u+x /app/remove 

# install forego, kube-gen, and kubectl
ENV KUBE_GEN_VERSION 0.3.0

ADD https://storage.googleapis.com/kubernetes-release/release/v1.3.4/bin/linux/amd64/kubectl /usr/local/bin

RUN wget https://bin.equinox.io/c/ekMN3bCZFUn/forego-stable-linux-amd64.tgz \
  && tar -C /usr/local/bin -xzvf forego-stable-linux-amd64.tgz \
  && rm forego-stable-linux-amd64.tgz \
  && wget https://github.com/kylemcc/kube-gen/releases/download/$KUBE_GEN_VERSION/kube-gen-linux-amd64-$KUBE_GEN_VERSION.tar.gz \
  && tar -C /usr/local/bin -xvzf kube-gen-linux-amd64-$KUBE_GEN_VERSION.tar.gz \
  && rm kube-gen-linux-amd64-$KUBE_GEN_VERSION.tar.gz \
  && chmod +x /usr/local/bin/forego \
  && chmod +x /usr/local/bin/kubectl \
  && chmod +x /usr/local/bin/kube-gen


ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh" ]
CMD ["forego", "start", "-r"]
