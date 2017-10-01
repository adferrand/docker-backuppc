FROM alpine:3.6

LABEL maintainer="Adrien Ferrand <ferrand.ad@gmail.com>"

ENV BACKUPPC_VERSION 4.1.3
ENV BACKUPPC_XS_VERSION 0.56
ENV RSYNC_BPC_VERSION 3.0.9.8
ENV PAR2_VERSION v0.7.4

RUN apk --no-cache add \
# Install backuppc build dependencies
gcc g++ autoconf automake make git patch perl perl-dev perl-cgi expat expat-dev curl wget \
# Install backuppc runtime dependencies
supervisor rsync samba-client iputils openssh openssl rrdtool msmtp lighttpd lighttpd-mod_auth gzip apache2-utils tzdata libstdc++ libgomp libgcc \
# Compile and install needed perl modules
&& cpan App::cpanminus \
&& cpanm -n Archive::Zip XML::RSS File::Listing \

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
&& apk --no-cache del gcc g++ autoconf automake make git patch perl-dev expat-dev curl wget

COPY files/lighttpd.conf /etc/lighttpd/lighttpd.conf
COPY files/entrypoint.sh /entrypoint.sh
COPY files/supervisord.conf /etc/supervisord.conf

EXPOSE 8080

VOLUME ["/etc/backuppc", "/home/backuppc", "/data/backuppc"]

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
