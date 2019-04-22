#Arg used for multi-arch building
ARG IMAGE_ARCH=amd64

#Add a specific build to import Qemu https://yen3.github.io/posts/2017/build_multi_arch_docker_image/
FROM yen3/binfmt-register:0.1 as builder

#Use 9-alpine as base to be in line with cloud9
FROM ${IMAGE_ARCH}/nginx:alpine

# Import Qemu from builder container
COPY --from=builder /qemu/qemu-aarch64-static /usr/local/bin/qemu-aarch64-static

MAINTAINER Adrien M amaurel90@gmail.com

ENV DEBUG=false KAP_DEBUG="0" 
ARG VERSION_KUBE_GEN="artifacts/master"
ARG IMAGE_ARCH_LITE="amd64"

RUN apk add --no-cache nano ca-certificates unzip wget certbot bash openssl

# Install Forego & Kubectl & Kube-Gen-KAP
ADD https://storage.googleapis.com/kubernetes-release/release/v1.3.4/bin/linux/$IMAGE_ARCH_LITE/kubectl /usr/local/bin/kubectl

RUN wget "https://gitlab.com/adi90x/kube-template-kap/builds/$VERSION_KUBE_GEN/download?job=compile-go-$IMAGE_ARCH" -O /tmp/kube-template-kap.zip \
	&& wget "https://bin.equinox.io/c/ekMN3bCZFUn/forego-stable-linux-$IMAGE_ARCH_LITE.tgz" -O /tmp/forego.tgz \
        && tar xvf /tmp/forego.tgz -C /usr/local/bin \
	&& unzip /tmp/kube-template-kap.zip -d /usr/local/bin \
	&& chmod u+x /usr/local/bin/kube-template-kap \
	&& chmod u+x /usr/local/bin/forego \
	&& chmod u+x /usr/local/bin/kubectl \
	&& rm -f /tmp/kube-template-kap.zip \
	&& rm -f /tmp/forego.zip
	
#Copying all templates and script	
COPY /app/ /app/
WORKDIR /app/

# Seting up repertories & Configure Nginx and apply fix for very long server names
RUN chmod +x /app/letsencrypt.sh \
    && mkdir -p /etc/nginx/certs /etc/nginx/vhost.d /etc/nginx/conf.d /usr/share/nginx/html /etc/letsencrypt \
    && echo "daemon off;" >> /etc/nginx/nginx.conf \
    && sed -i 's/^http {/&\n    server_names_hash_bucket_size 128;/g' /etc/nginx/nginx.conf \
    && chmod u+x /app/remove 

#Remove useless Qemu
RUN rm -f /usr/local/bin/qemu-aarch64-static

ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh" ]
CMD ["forego", "start", "-r"]
