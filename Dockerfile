FROM bitnami/minideb:stretch

LABEL maintainer="Adrien Ferrand <ferrand.ad@gmail.com>"

ENV BACKUPPC_VERSION 4.2.1
ENV BACKUPPC_XS_VERSION 0.57
ENV RSYNC_BPC_VERSION 3.0.9.12
ENV PAR2_VERSION v0.8.0

RUN apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
# Install backuppc build dependencies
gcc g++ autoconf automake make git patch libexpat1-dev curl wget ca-certificates \
# Install backuppc runtime dependencies
supervisor rsync samba-client samba-common-bin openssh-client openssl rrdtool msmtp iputils-ping bzip2 lighttpd apache2-utils libexpat1 libperl-version-perl libfile-listing-perl libcgi-pm-perl \
# Compile and install BackupPC:XS
&& git clone https://github.com/backuppc/backuppc-xs.git /root/backuppc-xs --branch $BACKUPPC_XS_VERSION \
&& cd /root/backuppc-xs \
&& perl Makefile.PL && make && make test && make install \
# Compile and install Rsync (BPC version)
&& git clone https://github.com/backuppc/rsync-bpc.git /root/rsync-bpc --branch $RSYNC_BPC_VERSION \
&& cd /root/rsync-bpc && ./configure && make reconfigure && make && make install \
# Compile and install PAR2
&& git clone https://github.com/Parchive/par2cmdline.git /root/par2cmdline --branch $PAR2_VERSION \
&& cd /root/par2cmdline && ./automake.sh && ./configure && make && make check && make install \
# Configure MSMTP for mail delivery (initially sendmail is a sym link to busybox)
&& rm -f /usr/sbin/sendmail \
&& ln -s /usr/bin/msmtp /usr/sbin/sendmail \
# Disable strict host key checking
&& sed -i -e 's/^# Host \*/Host */g' /etc/ssh/ssh_config \
&& sed -i -e 's/^#   StrictHostKeyChecking ask/    StrictHostKeyChecking no/g' /etc/ssh/ssh_config \
# Get BackupPC, it will be installed at runtime to allow dynamic upgrade of existing config/pool
&& curl -o /root/BackupPC-$BACKUPPC_VERSION.tar.gz -L https://github.com/backuppc/backuppc/releases/download/$BACKUPPC_VERSION/BackupPC-$BACKUPPC_VERSION.tar.gz \
# Prepare backuppc home
&& mkdir -p /home/backuppc \
# Mark the docker as not runned yet, to allow entrypoint to do its stuff
&& touch /firstrun \
# Clean
&& rm -rf /root/backuppc-xs /root/rsync-bpc /root/par2cmdline \
&& apt-get remove --purge --auto-remove -y gcc g++ autoconf automake make git patch libexpat1-dev curl wget ca-certificates \
&& apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY files/lighttpd.conf /etc/lighttpd/lighttpd.conf
COPY files/entrypoint.sh /entrypoint.sh
COPY files/supervisord.conf /etc/supervisord.conf

EXPOSE 8080

VOLUME ["/etc/backuppc", "/home/backuppc", "/data/backuppc"]

ENTRYPOINT ["/entrypoint.sh"]

WORKDIR ["/home/backuppc"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
