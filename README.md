# &nbsp;![BackupPC logo](https://raw.githubusercontent.com/mjechow/docker-backuppc/master/images/logo_200px.png) mjechow/docker-backuppc

[![Build status](https://github.com/mjechow/docker-backuppc/actions/workflows/main.yml/badge.svg)](https://github.com/mjechow/docker-backuppc/actions)

> **Fork of [adferrand/docker-backuppc](https://github.com/adferrand/docker-backuppc).**
> Rebased on a current Alpine, with build fixes for modern toolchains and a
> backported XSS security fix. See [Fork changes](#fork-changes) for the diff.
>
> Image: `ghcr.io/mjechow/docker-backuppc:4` (or pin to `4.4.0-13`).

## Fork changes

This fork preserves the original architecture, configuration surface, and
behaviour of `adferrand/docker-backuppc`. The deltas against upstream `4.4.0-12`:

* Base image bumped from `alpine:3.18.4` to `alpine:3.23.4` (fixes
  CVE-2024-38475 in `apache2-utils` (KEV), CVE-2024-6387 (regreSSHion) and
  the XZ backdoor CVE-2024-3094).
* `rsync-bpc` pinned to upstream commit
  [`1ad3f70`](https://github.com/backuppc/rsync-bpc/commit/1ad3f70) (GCC
  14/15 build fixes; the `3.1.3.0` release tag from 2020 no longer compiles
  on modern toolchains and upstream has not cut a new release). Optional
  features added on master after `3.1.3.0` (md2man, openssl, xxhash, zstd,
  lz4) are explicitly disabled because BackupPC does not use them.
* Backports the XSS fix in `lib/BackupPC/CGI/View.pm` for the `num` query
  parameter from BackupPC master
  ([commit `58b0bb4`](https://github.com/backuppc/backuppc/commit/58b0bb4)).
  Originally fixed in 2012, accidentally dropped in 3.3.0 (2013), re-applied
  upstream Nov 2025 for the unreleased 4.4.1.
* Compile steps parallelised with `make -j"$(nproc)"`.
* Published to GHCR (`ghcr.io/mjechow/docker-backuppc`) instead of Docker Hub.

### Known open findings

Grype reports two High-severity findings in Python packages pulled in
transitively by the `supervisor` runtime dependency:

| Package | Installed | Fixed in | Advisory |
| --- | --- | --- | --- |
| `jaraco-context` | 5.3.0 | 6.1.0 | GHSA-58pv-8j8x-9vj2 |
| `wheel` | 0.45.1 | 0.46.2 | GHSA-8rrh-rw8j-w5fx |

Both have EPSS < 0.1% and risk score < 0.1. The fix depends on Alpine
updating their Python package set in 3.23.x. No action is possible from
this image until that upstream update ships; the image will be rebuilt when
it does.

## Table of contents

* [Container functionalities](#container-functionalities)
* [About BackupPC](#about-backuppc)
* [Basic usage](#basic-usage)
* [Data persistency](#data-persistency)
	* [POSIX rights](#posix-rights)
* [UI authentication/authorization](#ui-authenticationauthorization)
    * [File authentication](#file-authentication)
	* [Active Directory/LDAP](#active-directory--ldap)
    * [Advanced configuration](#advanced-configuration)
* [UI SSL encryption](#ui-ssl-encryption)
	* [Self-signed certificate](#self-signed-certificate)
	* [Advanced SSL use](#advanced-ssl-use)
* [SMTP configuration for notification delivery](#smtp-configuration-for-notification-delivery)
	* [Relay notifications to a local SMTP](#relay-notifications-to-a-local-smtp)
	* [Advanced SMTP configuration](#advanced-smtp-configuration)
* [Upgrading](#upgrading)
* [Cutting a release](#cutting-a-release)
* [Miscellaneous](#miscellaneous)
    * [Hostname](#hostname)
    * [Timezone](#timezone)
    * [Shell access](#shell-access)
    * [Legacy version](#legacy-version)

## Container functionalities

This docker is designed to provide a ready-to-go and maintainable BackupPC instance for your backups.

* Provides a full-featured and functional BackupPC version 4.x/3.x. In particular, all backup protocols handled by BackupPC are supported.
* BackupPC Admin Web UI is exposed on 8080 port by an embedded lighttpd server. Available protocols are HTTP or HTTPS through a self-signed SSL certificate.
* Existing BackupPC configuration & pool are self-upgraded at first run of a newly created container instance. It allows for instance dockerisation of a pre-existing BackupPC v3.x instance.
* Container image is constructed on top of an Alpine distribution to reduce the footprint.

## About BackupPC

![BackupPC Logo](https://backuppc.github.io/backuppc/images/logos/logo320.png)
BackupPC is a free self-hosted backup software able to backup remote hosts through various ways like rsync, smb or tar. It supports full and incremental backups, and reconstruct automatically a usable verbatim from any backup version. Started with version 4, BackupPC uses a new way to store backups by a reverse delta approach and no hardlinks.

See [BackupPC documentation](https://backuppc.github.io/backuppc/BackupPC.html) for further details and how to use it.

## Basic usage

For testing purpose, you can create a new BackupPC instance with following command.
**Please note that the basic usage is not suitable for production use.**

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    ghcr.io/mjechow/docker-backuppc
```

Latest BackupPC 4.x docker image will be downloaded if needed, and started. 
After starting, browse http://YOUR_SERVER_IP:8080 to access the BackupPC Admin Web UI. 

The default credentials are:
- **username:** backuppc
- **password:** password

Then you can test your BackupPC instance.

BackupPC configuration and pool are persisted as anonymous data containers (see [Data persistency](#data-persistency)) with a weak control over it. Moreover BackupPC Admin Web UI is accessed from the unsecured HTTP protocol, exposing your user/password and data you could retrieve from the UI (see [UI SSL encryption](#ui-ssl-encryption)).

## Data persistency

As we are talking about backups, you certainly want to control the data persistency of your docker instance.

It declares three volumes :

* `/etc/backuppc`: stores the BackupPC configuration, in particular config.pl and hosts configuration.
* `/home/backuppc`: home of the backuppc user, running your BackucPC instance, and contains in particular a .ssh directory with the SSH keys used to make backups through SSH protocol (see [SSH Keys](#ssh-keys)).
* `/data/backuppc`: contains the BackupPC pool, so your backups themselves, and the logs.

It is advised to mount these volumes on the host in order to persist your backups. Assuming a host directory `/var/docker-data/backuppc{etc,home,data}`, mounted on a big filesystem, you can do for instance :

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    --volume /var/docker-data/backuppc/etc:/etc/backuppc \
    --volume /var/docker-data/backuppc/home:/home/backuppc \
    --volume /var/docker-data/backuppc/data:/data/backuppc \
    ghcr.io/mjechow/docker-backuppc
```

All your backuppc configuration, backup and keys will survive the container destroy/re-creation.

### POSIX rights

The mounted host directory used for data persistency needs to be accessible by the host user corresponding to the backuppc user created in container instance. By default, this backuppc user is of `UUID 1000` and `GUID 1000`, which should correspond to the first non-root user create on your host.

If you want to use an host user of different UUID/GUID, you can specify the container instance to use these customized values during creation with environment variables: respectively `BACKUPPC_UUID (default: 1000)` and `BACKUPPC_GUID (default: 1000)`.

For example:

```bash
# With user myUser (UUID 1200) and group myGroup (GUID 1300)
chown -R myUser:myGroup /var/docker-data/backuppc
docker run \
    --name backuppc \
    --publish 80:8080 \
    --volume /var/docker-data/backuppc/etc:/etc/backuppc \
    --volume /var/docker-data/backuppc/home:/home/backuppc \
    --volume /var/docker-data/backuppc/data:/data/backuppc \
    --env 'BACKUPPC_UUID=1200' \
    --env 'BACKUPPC_GUID=1300' \
    ghcr.io/mjechow/docker-backuppc  
```

## UI authentication/authorization

BackupPC can use different methods to authenticate and authorize users to access the BackupPC Admin Web UI. The method
used is controlled by the value of the `AUTH_METHOD (default file)` environment variable.

At this time there are two methods:
* Credentials are defined in a httpasswd-like file. This is the default one.
* Credentials are stored in a LDAP database or an Active Directory instance, and `docker-backuppc` connects to it to
  validate the accesses.

In all cases the authentication process is done through the HTTP Basic Auth. If BackupPC is served through the unsecured HTTP protocol, credentials are exposed in plain text. See [UI SSL encryption](#ui-ssl-encryption) to secure the authentication data.

### File authentication

This method is enabled with `AUTH_METHOD=file`.

Out of the box with this authentication method enabled, a single user with admin rights is created during the first start of
the container. Its username is *backuppc* and its password is *password*. The credentials are stored in the file `/etc/backuppc/htpasswd` to allow the embedded lighttpd server to handle Basic Authentication, and the Backuppc config variable `$Conf{CgiAdminUsers}` is setted to this username to instruct BackupPC to give it admin rights. 

You can modify the admin user credentials by setting the environment variables `BACKUPPC_WEB_USER (default backuppc)` and `BACKUPPC_WEB_PASSWD (default password)` when creating the container.

The admin user credentials can be modified on an existing container by modifying the relevant environment variables, then re-creating the container. However please note that if you modify the username, you will need to manually remove the old username from the file `/etc/backuppc/htpasswd` in the container after its re-creation.

### Active Directory / LDAP

This method is enabled with `AUTH_METHOD=ldap`.

You can also authorize against an Active Directory / LDAP. The following Parameter are required to use this authorize method:

| ENV Parameter | Description | Example |
| --- | --- | --- |
| `LDAP_HOSTNAME` | LDAP Hostname / IP with Port | ad.example.com:389 |
| `LDAP_BASE_DN` | LDAP Base DN | DC=example,DC=com | 
| `LDAP_FILTER` | LDAP Filter | (\&(objectClass=user)(sAMAccountName=$))' |
| `LDAP_BIND_DN` | LDAP Bind DN | cn=backuppc,cn=users,DC==example,DC=com |
| `LDAP_BIND_PW` | LDAP Password | SuperSecretPassword |
| `LDAP_BACKUPPC_ADMIN` | LDAP user with with backuppc admin rights | backuppcadmin |

### Advanced configuration

One may need more advanced authentication/authorization on Backuppc Web UI, for instance several *normal* users allowing operations on backups, and an *admin* user to parameterize BackupPC.

In theses cases, authentication and admin granting must be configured manually.
* If `file` authentication method is used, you should use Apache `htpasswd` utility to fill content of the file `/etc/backuppc/htpasswd`. You can also disable the default admin user creation by unsetting environment variables `BACKUPPC_WEB_USER` and `BACKUPPC_WEB_PASSWD`, and reconfigure admin rights in `config.pl`.
* All authenticated users are considered as *normal* users if not telling otherwise. Add a username in the `$Conf{CgiAdminUsers}` variable of `/etc/backuppc/config.pl` file to grant this user admin rights, or use `LDAP_BACKUPPC_ADMIN` with the `ldap` authentication method.

For instance, with two *normal* users `user1` and `user2` + one *admin* user `admin`, using the `file` authentication method, you can do the following steps on the host. It is assumed that `/etc/backuppc` is mounted on `/var/docker-data/backuppc/etc` on the host and Apache `htpasswd` utility is installed on it.

```bash
htpasswd -b -c /var/docker-data/backuppc/etc/htpasswd admin admin_password
htpasswd -b /var/docker-data/backuppc/etc/htpasswd user1 user1_password
htpasswd -b /var/docker-data/backuppc/etc/htpasswd user2 user2_password
sed -ie "s/^\$Conf{CgiAdminUsers}\s*=\s*'\w*'/\$Conf{CgiAdminUsers} = 'admin'/g" \
    /var/docker-data/backuppc/etc/config.pl

docker run \
    --name backuppc \
    --publish 80:8080 \
    --volume /var/docker-data/backuppc/etc:/etc/backuppc \
    --volume /var/docker-data/backuppc/home:/home/backuppc \
    --volume /var/docker-data/backuppc/data:/data/backuppc \
    ghcr.io/mjechow/docker-backuppc  
```

## UI SSL encryption

By default, BackupPC Admin Web UI is exposed on the non secured HTTP protocol. Two advised ways to secure this are proposed.

### Self-signed certificate

Set the environment variable `USE_SSL (default: false)` to `true`, and the embedded lighttpd server will expose the UI by HTTPS protocol, using a self-signed certificate generated during first run of the container instance.

```bash
docker run \
    --name backuppc \
    --publish 443:8080 \
    --env 'USE_SSL=true'
```

Then you can access the UI through the secured URL https://YOUR_SERVER_IP/. Of course, as the SSL certificate is self-signed, your browser will alert you about this unsecured certificate.

_NB: You can also use your own SSL certificate: merge together the private key and the certificate into a `server.pem` file (eg. `cat server.key server.crt > server.pem`), and mount `certificate.pem` on the container path `/etc/lighttpd/server.pem` (eg. `--volume /you/path/to/certificate.pem:/etc/lighttpd/server.pem`)._

### Advanced SSL use

Instead of providing a very advanced SSL configuration in this Docker, and reinvent the wheel, it is advised to run your backuppc instance without SSL and without exposing the 8080 port, and launch a second container with a secured SSL reverse-proxy pointing to the BackupPC instance.

You will be able to make routing based on DNS, use certificates signed by Let's Encrypt and so on. See [nginx-proxy](https://github.com/jwilder/nginx-proxy) + [letsencrypt-nginx-proxy-companion](https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion) or [traefik](https://hub.docker.com/_/traefik/) for more information.

## SMTP configuration for notification delivery

BackupPC can send notifications by mail to inform users about backups state. This docker include the MSMTP utility, which basically relays all mails to a pre-existing SMTP server.

Two configuration approaches are available.

### Relay notifications to a local SMTP

If you are using BackupPC to backup your IT architecture, it is likely that you have already a SMTP server configured on your host or local network. Or you can instantiate a dockerised full-featured SMTP server (like [namshi/smtp](https://github.com/namshi/docker-smtp)) on the same network than the backuppc container.

In both cases, the SMTP server should be accessible to the backuppc container through YOUR_SMTP_FQDN on port 25. Set the environment variable `SMTP_HOST` (default: mail.example.org) to YOUR_SMTP_FQDN before creating the BackupPC container, and all mails emitted by BackupPC will be relayed on this SMTP server. 

You should also set the _optional_ environment variable `SMTP_MAIL_DOMAIN (default empty)` to the domain you manage, in order to resolve automatically the right part of the email sender to this domain if it is not specified by BackupPC. Indeed by default, sender mail of BackupPC notifications is only 'backuppc', without right part: these emails are likely to be refused by most SMTP servers.

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    --env SMTP_HOST=smtp.my-domain.org \
    --env SMTP_MAIL_DOMAIN=my-domain.org \
    ghcr.io/mjechow/docker-backuppc
```

### Advanced SMTP configuration

In more complex scenarios, like sending notifications through a TLS-secured SMTP server with authentication (eg. Google SMTP), you can use any advanced configuration supported by MSMTP. To do so, mount your custom `msmtprc` configuration file on the Docker path `/etc/msmtprc`. This configuration will be used for any email sent by BackupPC.

See [MSMTP documentation](http://msmtp.sourceforge.net/doc/msmtp.html), in particular its [configuration examples](http://msmtp.sourceforge.net/doc/msmtp.html#Examples), to see how to build the configuration which suits your needs.

## Upgrading

To update the BackupPC version of this container:
* pull the new image version of this Docker,
* recreate the container. 

At first start, `configure.pl` script of BackupPC will be called. It will detect your existing configuration (under `/etc/backuppc`), your existing backup pool (under `/data/backuppc`), and will proceed any changes needed to match the new BackupPC version requirement.

## Cutting a release

1. Update `CHANGELOG.md`: rename `## master - CURRENT` to `## <version> - DD/MM/YYYY` and add a new `## master - CURRENT` section at the top.
2. Commit and merge to master via pull request.
3. Tag the merged commit and push the tag:

```bash
git tag <version>
git push origin <version>
```

The tag push triggers the CI release workflow, which builds the multi-arch image, pushes it to GHCR, and creates the GitHub release with the changelog body extracted automatically.

## Miscellaneous

### Hostname

The backuppc host name will default to the container's hostname. You can modify this by setting `--hostname` in your `docker run` command like so:

```bash
docker run \
    --name backuppc \
    --hostname backuppc.example.org \
    --publish 80:8080 \
    ghcr.io/mjechow/docker-backuppc
```

### Metrics

Metrics are available on a dedicated endpoint. For example, if the URL to access the BackupPC Admin Web UI is `http://YOUR_SERVER_IP:8080`, then use:
* `http://YOUR_SERVER_IP:8080/BackupPC_Admin?action=metrics&format=json` to get the metrics in JSON format
* `http://YOUR_SERVER_IP:8080/BackupPC_Admin?action=metrics&format=rss` to get the metrics in RSS format
* `http://YOUR_SERVER_IP:8080/BackupPC_Admin?action=metrics&format=prometheus` to get the metrics in Prometheus format

### Timezone

By default the timezone of this docker is set to UTC. To modify it, you can specify a tzdata-compatible timezone in the environment variable `TZ`.

```bash
# For Paris time (including daylight)
docker run \
    --name backuppc \
    --publish 80:8080 \
    --env TZ=Europe/Paris \
    ghcr.io/mjechow/docker-backuppc
```

Alternatively, depending on the host OS, you can sync the container timezone to its host by mounting the host file `/etc/localtime` to the container path `/etc/localtime`.

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    --mount /etc/localtime:/etc/localtime:ro \
    ghcr.io/mjechow/docker-backuppc
```

### Shell access

For debugging and maintenance purpose, you may need to start a shell in your running container. With a Docker of version 1.3.0 or higher, you can do:

```bash
docker exec -it backuppc /bin/sh
```

You will obtain a shell with the standard tools of an Alpine distribution.

### Legacy version

This fork only ships BackupPC 4.x. If you need the legacy 3.x image, use
`adferrand/backuppc:3` from upstream — that branch is not maintained here.
