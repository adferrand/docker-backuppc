FROM docker.io/alpine:3.24.1

LABEL maintainer="Adrien Ferrand <ferrand.ad@gmail.com>"
LABEL org.opencontainers.image.source="https://github.com/adferrand/docker-backuppc"
LABEL org.opencontainers.image.description="BackupPC on Alpine Linux with rsync-bpc, XS, and msmtp"

ARG BACKUPPC_VERSION="4.4.1rc1"
ARG BACKUPPC_XS_VERSION="0.63rc4"
ARG RSYNC_BPC_COMMIT="3.1.3.2"

ENV BACKUPPC_VERSION="${BACKUPPC_VERSION}"
ENV BACKUPPC_XS_VERSION="${BACKUPPC_XS_VERSION}"
ENV RSYNC_BPC_COMMIT="${RSYNC_BPC_COMMIT}"

# Install backuppc runtime dependencies
# hadolint ignore=DL3018,DL3003
RUN apk --no-cache --update add \
        rsync tar bash shadow ca-certificates \
        supervisor \
        perl perl-archive-zip perl-xml-rss perl-cgi perl-file-listing perl-json-xs \
        expat samba-client iputils openssh openssl rrdtool ttf-dejavu \
        msmtp lighttpd lighttpd-mod_auth apache2-utils tzdata libstdc++ libgomp \
        zlib gzip pigz \
 && apk --no-cache --update -X http://dl-cdn.alpinelinux.org/alpine/edge/community add par2cmdline \
# Install backuppc build dependencies
 && apk --no-cache --update --virtual build-dependencies add \
        gcc g++ autoconf automake make git perl-dev perl-app-cpanminus acl-dev curl zlib-dev \
# Compile and install BackupPC:XS
 && git clone https://github.com/backuppc/backuppc-xs.git /tmp/backuppc-xs --branch "${BACKUPPC_XS_VERSION}" \
 && cd /tmp/backuppc-xs \
 # Next line is a patch to avoid a compilation failure due to missing mapping of C types `int64` and `uint32`.
 # Safe guard done by checking that ivsize=8 to ensure that `T_IV` Perl type is effectively coded on 64 bits in this runtime.
 # TODO: Fix upstream and remove this patch.
 && printf 'int64\t\tT_IV\nuint32\t\tT_UV\n' >> typemap && perl -MConfig -e 'exit($Config{ivsize} == 8 ? 0 : 1)' \
 && autoreconf --install && perl Makefile.PL && cp Makefile Makefile.real \
 && make -j"$(nproc)" && make -f Makefile.real pure_install && make test \
# Compile and install Rsync (BPC version)
# Disable optional features added on master after 3.1.3.0 (md2man, openssl crypto,
# xxhash, zstd, lz4) — BackupPC does not use them and they pull extra build deps.
 && git clone https://github.com/backuppc/rsync-bpc.git /tmp/rsync-bpc --branch "${RSYNC_BPC_COMMIT}" \
 && cd /tmp/rsync-bpc \
 && ./configure --disable-md2man --disable-openssl --disable-xxhash --disable-zstd --disable-lz4 \
 && make reconfigure && make -j"$(nproc)" && make install \
# Install SCGI Perl module from CPAN
 && cpanm --notest SCGI \
# Clean
 && rm -rf /tmp/backuppc-xs /tmp/rsync-bpc \
 && apk del build-dependencies

# Configure MSMTP for mail delivery (initially sendmail is a sym link to busybox)
RUN rm -f /usr/sbin/sendmail \
 && ln -s /usr/bin/msmtp /usr/sbin/sendmail \
# Disable strict host key checking
 && sed -i -e 's/^# Host \*/Host */g' /etc/ssh/ssh_config \
 && sed -i -e 's/^#   StrictHostKeyChecking ask/    StrictHostKeyChecking no/g' /etc/ssh/ssh_config \
# Prepare backuppc home
 && mkdir -p /home/backuppc \
# Mark the docker as not run yet, to allow entrypoint to do its stuff
 && touch /firstrun

# Fetch BackupPC dist, it will be installed at runtime to allow dynamic upgrade of the intial config/pool
# RUN curl -o "/root/BackupPC-${BACKUPPC_VERSION}.tar.gz" -L "https://github.com/backuppc/backuppc/releases/download/${BACKUPPC_VERSION}/BackupPC-${BACKUPPC_VERSION}.tar.gz"

# Alternative to commented curl call above, until the BackupPC dist tarball is effectively distributed by upstream
# TODO: Fix upstream and revert to fetching the tarball.
# hadolint ignore=DL3018,DL3003
RUN apk add --no-cache --update --virtual backuppc-build git perl-time-parsedate \
 && git clone https://github.com/backuppc/backuppc.git /tmp/backuppc --branch "${BACKUPPC_VERSION}" \
 && cd /tmp/backuppc \
 && ./makeDist --version "${BACKUPPC_VERSION}" \
 && mv "dist/BackupPC-${BACKUPPC_VERSION}.tar.gz" "/root/BackupPC-${BACKUPPC_VERSION}.tar.gz" \
 && rm -rf /tmp/backuppc \
 && apk del backuppc-build

COPY files/lighttpd.conf /etc/lighttpd/lighttpd.conf
COPY files/auth.conf /etc/lighttpd/auth.conf
COPY files/auth-ldap.conf /etc/lighttpd/auth-ldap.conf
COPY files/entrypoint.sh /entrypoint.sh
COPY files/supervisord.conf /etc/supervisord.conf

EXPOSE 8080

WORKDIR /home/backuppc

VOLUME ["/etc/backuppc", "/home/backuppc", "/data/backuppc"]

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
