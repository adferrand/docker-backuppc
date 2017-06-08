#!/bin/sh
set -e

if [ -f /firstrun ]; then
	echo 'First run of the container. BackupPC will be installed.'
	echo 'If exist, configuration and data will be reused and upgraded as needed.'

	# Create backuppc user
	addgroup -S -g ${BACKUPPC_GUID:-1000} backuppc
	adduser -D -S -h /home/backuppc -G backuppc -u ${BACKUPPC_UUID:-1000} backuppc
	chown backuppc:backuppc /home/backuppc

	# Generate cryptographic key
	if [ ! -f /home/backuppc/.ssh/id_rsa ]; then
		su backuppc -s /bin/sh -c "ssh-keygen -t rsa -N '' -f /home/backuppc/.ssh/id_rsa"
	fi

	# Extract BackupPC
	cd /root
	tar xf BackupPC-$BACKUPPC_VERSION.tar.gz
	cd /root/BackupPC-$BACKUPPC_VERSION

	# Install BackupPC (existing configuration will be reused and upgraded)
	perl configure.pl \
		--batch \
		--config-dir /etc/backuppc \
		--cgi-dir /var/www/cgi-bin/BackupPC \
		--data-dir /data/backuppc \
		--hostname localhost \
		--html-dir /var/www/html/BackupPC \
		--html-dir-url /BackupPC \
		--install-dir /usr/local/BackupPC \
		--config-override CgiAdminUsers="'${BACKUPPC_WEB_USER:-backuppc}'"

	# Configure WEB UI access
	if [ ! -f /etc/backuppc/htpasswd ]; then
		htpasswd -b -c /etc/backuppc/htpasswd ${BACKUPPC_WEB_USER:-backuppc} ${BACKUPPC_WEB_PASSWD:-password}
	fi

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
		chown backuppc:backuppc server.pem
		chmod 0600 server.pem
		rm -f server.pass.key server.key server.csr server.crt
		# Reconfigure lighttpd to use ssl
		echo "ssl.engine = \"enable\"" >> /etc/lighttpd/lighttpd.conf
		echo "ssl.pemfile = \"/etc/lighttpd/server.pem\"" >> /etc/lighttpd/lighttpd.conf
	fi
	touch /var/log/lighttpd/error.log && chown -R backuppc:backuppc /var/log/lighttpd

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

# Exec given CMD in Dockerfile
exec "$@"
