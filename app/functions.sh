[[ -z "${VHOST_DIR:-}" ]] && \
 declare -r VHOST_DIR=/etc/nginx/vhost.d
[[ -z "${START_HEADER:-}" ]] && \
 declare -r START_HEADER='## Start of configuration add by letsencrypt container'
[[ -z "${END_HEADER:-}" ]] && \
 declare -r END_HEADER='## End of configuration add by letsencrypt container'

add_location_configuration() {
    local domain="${1:-}"
    [[ -z "$domain" || ! -f "${VHOST_DIR}/${domain}" ]] && domain=default
    [[ -f "${VHOST_DIR}/${domain}" && \
       -n $(sed -n "/$START_HEADER/,/$END_HEADER/p" "${VHOST_DIR}/${domain}") ]] && return 0
    echo "$START_HEADER" > "${VHOST_DIR}/${domain}".new
    cat /app/nginx_location.conf >> "${VHOST_DIR}/${domain}".new
    echo "$END_HEADER" >> "${VHOST_DIR}/${domain}".new
    [[ -f "${VHOST_DIR}/${domain}" ]] && cat "${VHOST_DIR}/${domain}" >> "${VHOST_DIR}/${domain}".new
    mv -f "${VHOST_DIR}/${domain}".new "${VHOST_DIR}/${domain}"
    return 1
}

remove_all_location_configurations() {
    local old_shopt_options=$(shopt -p) # Backup shopt options
    shopt -s nullglob
    for file in "${VHOST_DIR}"/*; do
        [[ -n $(sed -n "/$START_HEADER/,/$END_HEADER/p" "$file") ]] && \
         sed -i "/$START_HEADER/,/$END_HEADER/d" "$file"
    done
    eval "$old_shopt_options" # Restore shopt options
}

##Add a basic nginx server if need to generate Let's Encrypt certs without real host.
add_basic_nginx_host() {
    local dom="${1:-}"
    sed "s/DOMAIN/$dom/g" /app/nginx_basic_host.conf > /etc/nginx/conf.d/basic_host_$dom.conf
}

remove_basic_nginx_host() {
    local dom="${1:-}"
    rm -f /etc/nginx/conf.d/basic_host_$dom.conf
}

##Setup new certs
setup_certs() {
#Create cert link  and add dhparam key
local dom="${1:-}"
local certname="${2:-}"
if [  -e /etc/letsencrypt/live/$certname/privkey.pem ] && [ -e /etc/letsencrypt/live/$certname/fullchain.pem ]; then
    ln -sf /etc/letsencrypt/live/$certname/privkey.pem /etc/nginx/certs/$dom.key
    ln -sf /etc/letsencrypt/live/$certname/fullchain.pem /etc/nginx/certs/$dom.crt
    ln -sf /etc/letsencrypt/dhparam.pem /etc/nginx/certs/$dom.dhparam.pem
fi

}

##Generate Kubernetes Secret
generate_secrets() {
#Create secrets in Kubernetes to use by other pods
local certname="${1:-}"
local k8s_secret_ns="${2:-}"
local k8s_secret_name="${3:-}"

if [  -e /etc/letsencrypt/live/$certname/privkey.pem ] && [ -e /etc/letsencrypt/live/$certname/fullchain.pem ]; then
    kubectl delete secret tls -n $k8s_secret_ns $k8s_secret_name --ignore-not-found=true
    kubectl create secret tls -n $k8s_secret_ns $k8s_secret_name --cert=/etc/letsencrypt/live/$certname/fullchain.pem --key=/etc/letsencrypt/live/$certname/privkey.pem
fi

}


## Nginx
reload_nginx() {
#Delete file to avoid looping problem
rm -f /etc/nginx/conf.d/default.conf
#Rerun kube-template-kap to recreate a new nginx config file 
kube-template-kap --guess-kube-api-settings --once -t /app/nginx.tmpl:/etc/nginx/conf.d/default.conf
}

# Convert argument to lowercase (bash 4 only)
function lc() {
	echo "${@,,}"
}


create_link() {
    local readonly target=${1?missing target argument}
    local readonly source=${2?missing source argument}
    [[ -f "$target" ]] && return 1
    ln -sf "$source" "$target"
}

create_links() {
    local readonly base_domain=${1?missing base_domain argument}
    local readonly domain=${2?missing base_domain argument}
    if [[ ! -f "/etc/nginx/certs/$base_domain"/fullchain.pem || \
          ! -f "/etc/nginx/certs/$base_domain"/key.pem ]]; then
        return 1
    fi
    local return_code=1
    create_link "/etc/nginx/certs/$domain".crt "./$base_domain"/fullchain.pem
    return_code=$(( $return_code & $? ))
    create_link "/etc/nginx/certs/$domain".key "./$base_domain"/key.pem
    return_code=$(( $return_code & $? ))
    if [[ -f "/etc/nginx/certs/dhparam.pem" ]]; then
        create_link "/etc/nginx/certs/$domain".dhparam.pem ./dhparam.pem
        return_code=$(( $return_code & $? ))
    fi
    return $return_code
}
