#!/bin/bash
set -e

ssl=
if [ "$RABBITMQ_SSL_CERT_FILE" -a "$RABBITMQ_SSL_KEY_FILE" -a "$RABBITMQ_SSL_CA_FILE" ]; then
	ssl=1
fi

# If long & short hostnames are not the same, use long hostnames
if [ "$(hostname)" != "$(hostname -s)" ]; then
	export RABBITMQ_USE_LONGNAME=true
fi

if [ "$RABBITMQ_ERLANG_COOKIE" ]; then
	cookieFile='/var/lib/rabbitmq/.erlang.cookie'
	if [ -e "$cookieFile" ]; then
		if [ "$(cat "$cookieFile" 2>/dev/null)" != "$RABBITMQ_ERLANG_COOKIE" ]; then
			echo >&2
			echo >&2 "warning: $cookieFile contents do not match RABBITMQ_ERLANG_COOKIE"
			echo >&2
		fi
	else
		echo "$RABBITMQ_ERLANG_COOKIE" > "$cookieFile"
		chmod 600 "$cookieFile"
		chown rabbitmq "$cookieFile"
	fi
fi

if [ "$1" = 'rabbitmq-server' ]; then
	configs=(
		# https://www.rabbitmq.com/configure.html
		default_pass
		default_user
		default_vhost
		ssl_ca_file
		ssl_cert_file
		ssl_key_file
	)

	haveConfig=
	for conf in "${configs[@]}"; do
		var="RABBITMQ_${conf^^}"
		val="${!var}"
		if [ "$val" ]; then
			haveConfig=1
			break
		fi
	done

	if [ "$haveConfig" ]; then
		cat > /etc/rabbitmq/rabbitmq.config <<-'EOH'
			[
			  {rabbit,
			    [
		EOH

		if [ "$ssl" ]; then
			cat >> /etc/rabbitmq/rabbitmq.config <<-EOS
			      { tcp_listeners, [ ] },
			      { ssl_listeners, [ 5671 ] },
			      { ssl_options,  [
			        { certfile,   "$RABBITMQ_SSL_CERT_FILE" },
			        { keyfile,    "$RABBITMQ_SSL_KEY_FILE" },
			        { cacertfile, "$RABBITMQ_SSL_CA_FILE" },
			        { verify,   verify_peer },
			        { fail_if_no_peer_cert, true } ] },
			EOS
		else
			cat >> /etc/rabbitmq/rabbitmq.config <<-EOS
			      { tcp_listeners, [ 5672 ] },
			      { ssl_listeners, [ ] },
			EOS
		fi

		for conf in "${configs[@]}"; do
			[ "${conf#ssl_}" = "$conf" ] || continue
			var="RABBITMQ_${conf^^}"
			val="${!var}"
			[ "$val" ] || continue
			cat >> /etc/rabbitmq/rabbitmq.config <<-EOC
			      {$conf, <<"$val">>},
			EOC
		done
		cat >> /etc/rabbitmq/rabbitmq.config <<-'EOF'
			      {loopback_users, []}
		EOF

		# If management plugin is installed, then generate config consider this
		if [ "$(rabbitmq-plugins list -m -e rabbitmq_management)" ]; then
			cat >> /etc/rabbitmq/rabbitmq.config <<-'EOF'
				    ]
				  },
				  { rabbitmq_management, [
				      { listener, [
			EOF

			if [ "$ssl" ]; then
				cat >> /etc/rabbitmq/rabbitmq.config <<-EOS
				      { port, 15671 },
				      { ssl, true },
				      { ssl_opts, [
				          { certfile,   "$RABBITMQ_SSL_CERT_FILE" },
				          { keyfile,    "$RABBITMQ_SSL_KEY_FILE" },
				          { cacertfile, "$RABBITMQ_SSL_CA_FILE" },
				      { verify,   verify_none },
				      { fail_if_no_peer_cert, false } ] } ] }
				EOS
			else
				cat >> /etc/rabbitmq/rabbitmq.config <<-EOS
				        { port, 15672 },
				        { ssl, false }
				        ]
				      }
				EOS
			fi
		fi

		cat >> /etc/rabbitmq/rabbitmq.config <<-'EOF'
			    ]
			  }
			].
		EOF
	fi

	if [ "$ssl" ]; then
		# Create combined cert
		cat "$RABBITMQ_SSL_CERT_FILE" "$RABBITMQ_SSL_KEY_FILE" > /tmp/combined.pem
		chmod 0400 /tmp/combined.pem
		chown rabbitmq /tmp/combined.pem

		# More ENV vars for make clustering happiness
		# we don't handle clustering in this script, but these args should ensure
		# clustered SSL-enabled members will talk nicely
		export ERL_SSL_PATH="$(erl -eval 'io:format("~p", [code:lib_dir(ssl, ebin)]),halt().' -noshell)"
		export RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS="-pa '$ERL_SSL_PATH' -proto_dist inet_tls -ssl_dist_opt server_certfile /tmp/combined.pem -ssl_dist_opt server_secure_renegotiate true client_secure_renegotiate true"
		export RABBITMQ_CTL_ERL_ARGS="$RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS"
	fi

	chown -R rabbitmq /var/lib/rabbitmq
	set -- gosu rabbitmq "$@"
	if [ -z "$CLUSTER_WITH" -o "$CLUSTER_WITH" = "$(hostname)" ]; then
		echo "Running as single server"

		RABBITMQ_LOGS="/var/log/rabbitmq/rabbit@${HOSTNAME}.log"
		if [ -e "$RABBITMQ_LOGS" ]; then
			rm /var/log/rabbitmq/rabbit@$(hostname).log
		fi

		/usr/sbin/rabbitmq-server &

		while true; do if grep -q -i "Server startup complete" $RABBITMQ_LOGS; then break; else sleep 0.5; fi; done
		if [ "$(rabbitmqctl list_vhosts | grep a_vhost)" != "a_vhost" ]; then
			echo "Add user, vhost to rabbitmq"
			rabbitmqctl add_vhost a_vhost
			rabbitmqctl add_user rabbituser rabbituser
			rabbitmqctl set_permissions -p rabbituser rabbituser ".*" ".*" ".*"
		fi
	else
		echo "Running as clustered server"

		/usr/sbin/rabbitmq-server -detached

		runFile="/var/lib/rabbitmq/mnesia/rabbit@$(hostname)"
		echo $runFile
		if [ ! -e "$runFile" ]; then
			rabbitmqctl stop_app
			echo "Joining cluster $CLUSTER_WITH"
			if [ -z "$RAM_NODE" ]; then
	                        rabbitmqctl join_cluster rabbit@$CLUSTER_WITH
	                else
	                        rabbitmqctl join_cluster --ram rabbit@$CLUSTER_WITH
	                fi

			rabbitmqctl start_app
		else
			sleep 2s
		fi
	fi

	cat /filebeat.yml | sed "s/LOGSTASH_STRING/$LOGSTASH_STRING/" | sed "s/RABBITHOSTNAME/$(hostname)/" > /filebeat.yml.tmp
	cat /filebeat.yml.tmp > /filebeat.yml
	rm /filebeat.yml.tmp
	/filebeat -c /filebeat.yml &

	tail -f /var/log/rabbitmq/rabbit\@$HOSTNAME.log
fi

exec "$@"
