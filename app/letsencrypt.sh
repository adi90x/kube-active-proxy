#!/bin/bash

source /app/functions.sh

update_certs() {

    [[ ! -s /app/letsencrypt.conf ]] && return

    # Load relevant container settings
    unset LETSENCRYPT_CONTAINERS
    source /app/letsencrypt.conf

    [[ ! -n "$LETSENCRYPT_CONTAINERS" ]] && return

    for cid in "${LETSENCRYPT_CONTAINERS[@]}"; do

	# Derive host and email variable names
        host_varname="LETSENCRYPT_${cid}_HOST"

        # Array variable indirection hack: http://stackoverflow.com/a/25880676/350221
        hosts_array=$host_varname[@]
        email_varname="LETSENCRYPT_${cid}_EMAIL"
        test_certificate_varname="LETSENCRYPT_${cid}_TEST"
        k8s_secret_ns="LETSENCRYPT_${cid}_K8S_SECRET_NS"
        k8s_secret_name="LETSENCRYPT_${cid}_K8S_SECRET_NAME"


        if [[ $(lc "${!test_certificate_varname:-}") == true ]] || [ "$KAP_LE_TEST" == true ]; then
            acme_server="https://acme-staging-v02.api.letsencrypt.org/directory"
        else
            acme_server="https://acme-v02.api.letsencrypt.org/directory"
        fi

        sleep 3
        echo "Sleep 3s before Using Acme server $acme_server"

        debug=""
        [[ $DEBUG == true ]] && debug+=" -v"

        hosts_array_expanded=("${!hosts_array}")

        # First domain will be our base domain
        base_domain="${hosts_array_expanded[0]}"

		#Check if cert switch from staging to real and vice versa
		if [[ -f "/etc/letsencrypt/renewal/$base_domain.conf" ]]; then
			actual_server=$(grep server /etc/letsencrypt/renewal/$base_domain.conf | cut -f3 -d ' ')
			if [[ $acme_server == $actual_server ]]; then
				force_renewal=""
			else
				force_renewal="--break-my-certs --force-renewal"
				sed -i  's|'"$actual_server"'|'"$acme_server"'|g' "/etc/letsencrypt/renewal/$base_domain.conf"
			fi
		fi

	    # Split domain by ';'  create all config needed and create domain parameter for certbot 
	   listdomain=${base_domain//;/$'\n'}
	   for dom in $listdomain; do
		# Add location configuration for the domain
		if grep -q "server_name $dom;" /etc/nginx/conf.d/default.conf
		#If host don't already exist we will have to create a basic nginx config to respond to LE challenge
		then
     			add_location_configuration "$dom"
		else
			add_basic_nginx_host "$dom"
			add_location_configuration "$dom"
		fi

		# Create a domain parameter for certbot
		domainparam="$domainparam -d $dom "
	   done

		#Reload Nginx once location added
		reload_nginx

		echo "Creating/renewal $base_domain certificates... (${hosts_array_expanded[*]})"

		certbot certonly -t --agree-tos $debug $force_renewal \
			-m ${!email_varname} -n  $domainparam \
			--server $acme_server --expand \
			--webroot -w /usr/share/nginx/html

		echo " "
		#Setting the cert for all domain it was created for !
		domarray=( $listdomain )
		certname=${domarray[0]}
		for dom in $listdomain; do
		  setup_certs $dom $certname
		done
		#Only one certificate was created so only one secret maybe push to k8s API
		if [[ ${!k8s_secret_ns} != "false" ]]; then
		    generate_secrets $certname ${!k8s_secret_ns} ${!k8s_secret_name}
		fi
		domainparam=""
    done

    reload_nginx
    exit 0
}

update_certs

