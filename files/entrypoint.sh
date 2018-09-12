#!/bin/sh
set -e

BACKUPPC_UUID="${BACKUPPC_UUID:-1000}"
BACKUPPC_GUID="${BACKUPPC_GUID:-1000}"
BACKUPPC_USERNAME=`getent passwd "$BACKUPPC_UUID" | cut -d: -f1`
BACKUPPC_GROUPNAME=`getent group "$BACKUPPC_GUID" | cut -d: -f1`

if [ -f /firstrun ]; then
	echo 'First run of the container. BackupPC will be installed.'
	echo 'If exist, configuration and data will be reused and upgraded as needed.'

	# Configure timezone if needed
	if [ -n "$TZ" ]; then
		cp /usr/share/zoneinfo/$TZ /etc/localtime 
	fi

	# Create backuppc user/group if needed
	if [ -z "$BACKUPPC_GROUPNAME" ]; then
		groupadd -r -g "$BACKUPPC_GUID" backuppc
		BACKUPPC_GROUPNAME="backuppc"
	fi
	if [ -z "$BACKUPPC_USERNAME" ]; then
		useradd -r -d /home/backuppc -g "$BACKUPPC_GUID" -u "$BACKUPPC_UUID" -M -N backuppc
		BACKUPPC_USERNAME="backuppc"
	else
		usermod -d /home/backuppc "$BACKUPPC_USERNAME"
	fi
	chown "$BACKUPPC_USERNAME":"$BACKUPPC_GROUPNAME" /home/backuppc

	# Generate cryptographic key
	if [ ! -f /home/backuppc/.ssh/id_rsa ]; then
		su "$BACKUPPC_USERNAME" -s /bin/sh -c "ssh-keygen -t rsa -N '' -f /home/backuppc/.ssh/id_rsa"
	fi

	# Extract BackupPC
	cd /root
	tar xf BackupPC-$BACKUPPC_VERSION.tar.gz
	cd /root/BackupPC-$BACKUPPC_VERSION

	# Configure WEB UI access
	configure_admin=""
	if [ ! -f /etc/backuppc/htpasswd ]; then
		htpasswd -b -c /etc/backuppc/htpasswd "${BACKUPPC_WEB_USER:-backuppc}" "${BACKUPPC_WEB_PASSWD:-password}"
		configure_admin="--config-override CgiAdminUsers='${BACKUPPC_WEB_USER:-backuppc}'"
	elif [ -n "$BACKUPPC_WEB_USER" -a -n "$BACKUPPC_WEB_PASSWD" ]; then
		touch /etc/backuppc/htpasswd
		htpasswd -b /etc/backuppc/htpasswd "${BACKUPPC_WEB_USER}" "${BACKUPPC_WEB_PASSWD}"
		configure_admin="--config-override CgiAdminUsers='$BACKUPPC_WEB_USER'"
	fi

	# Install BackupPC (existing configuration will be reused and upgraded)
	perl configure.pl \
		--batch \
		--config-dir /etc/backuppc \
		--cgi-dir /var/www/cgi-bin/BackupPC \
		--data-dir /data/backuppc \
		--log-dir /data/backuppc/log \
		--hostname localhost \
		--html-dir /var/www/html/BackupPC \
		--html-dir-url /BackupPC \
		--install-dir /usr/local/BackupPC \
		--backuppc-user "$BACKUPPC_USERNAME" \
		$configure_admin

	# Prepare lighttpd
	if [ "$USE_SSL" = true ]; then
		# Generate certificate file as needed
		cd /etc/lighttpd
		openssl genrsa -des3 -passout pass:x -out server.pass.key 2048
		openssl rsa -passin pass:x -in server.pass.key -out server.key
		openssl req -new -key server.key -out server.csr \
			-subj "/C=UK/ST=Warwickshire/L=Leamington/O=OrgName/OU=IT Department/CN=example.com"
		openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
		cat server.key server.crt > server.pem
		chown "$BACKUPPC_USERNAME":"$BACKUPPC_GROUPNAME" server.pem
		chmod 0600 server.pem
		rm -f server.pass.key server.key server.csr server.crt
		# Reconfigure lighttpd to use ssl
		echo "ssl.engine = \"enable\"" >> /etc/lighttpd/lighttpd.conf
		echo "ssl.pemfile = \"/etc/lighttpd/server.pem\"" >> /etc/lighttpd/lighttpd.conf
	fi
	touch /var/log/lighttpd/error.log && chown -R "$BACKUPPC_USERNAME":"$BACKUPPC_GROUPNAME" /var/log/lighttpd

	# Configure standard mail delivery parameters (may be overriden by backuppc user-wide config)
	echo "account default" > /etc/msmtprc
	echo "host ${SMTP_HOST:-mail.example.org}" >> /etc/msmtprc
	echo "auto_from on" >> /etc/msmtprc
	if [ "${SMTP_MAIL_DOMAIN:-}" != "" ]; then
		echo "maildomain ${SMTP_MAIL_DOMAIN}" >> /etc/msmtprc
	fi

	# Clean
	rm -rf /root/BackupPC-$BACKUPPC_VERSION.tar.gz /root/BackupPC-$BACKUPPC_VERSION /firstrun
fi

export BACKUPPC_UUID
export BACKUPPC_GUID
export BACKUPPC_USERNAME
export BACKUPPC_GROUPNAME

# Executable bzip2 seems to have been moved into /usr/bin in latest Alpine version. Fix that.
ln -s /usr/bin/bzip2 /bin/bzip2

# Exec given CMD in Dockerfile
cd /home/backuppc
exec "$@"
