# &nbsp;![](https://raw.githubusercontent.com/adferrand/docker-backuppc/master/images/logo_200px.png) adferrand/backuppc
![](https://img.shields.io/badge/tags-4%20latest-lightgrey.svg) [![](https://images.microbadger.com/badges/version/adferrand/backuppc.svg) ![](https://images.microbadger.com/badges/image/adferrand/backuppc.svg)](https://microbadger.com/images/adferrand/backuppc) [![CircleCI](https://circleci.com/gh/adferrand/docker-backuppc/tree/master.svg?style=shield)](https://circleci.com/gh/adferrand/docker-backuppc/tree/master)

* [Container functionalities](#container-functionalities)
* [About BackupPC](#about-backuppc)
* [Basic usage](#basic-usage)
* [Data persistency](#data-persistency)
	* [POSIX rights](#posix-rights)
* [UI authentication/authorization](#ui-authenticationauthorization)
	* [Advanced UI authentication/authorization](#advanced-ui-authenticationauthorization)
* [UI SSL encryption](#ui-ssl-encryption)
	* [Self-signed certificate](#self-signed-certificate)
	* [Advanced SSL use](#advanced-ssl-use)
* [SMTP configuration for notification delivery](#smtp-configuration-for-notification-delivery)
	* [Relay notifications to a local SMTP](#relay-notifications-to-a-local-smtp)
	* [Advanced SMTP configuration](#advanced-smtp-configuration)
* [Upgrading](#upgrading)
	* [Dockerising an existing BackupPC v3.x](#dockerising-an-existing-backuppc-v3x)
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
* Container image is constructed on top of an Alpine distribution to reduce the footprint. Image size is below 80MB.

## About BackupPC

![BackupPC Logo](https://backuppc.github.io/backuppc/images/logos/logo320.png)
BackupPC is a free self-hosted backup software able to backup remote hosts through various ways like rsync, smb or tar. It supports full and incremental backups, and reconstruct automatically a usable verbatim from any backup version. Started with version 4, BackupPC uses a new way to store backups by a reverse delta approach and no hardlinks.

See [BackupPC documentation](http://backuppc.sourceforge.net/BackupPC-4.1.1.html) for further details and how to use it.

## Basic usage

For testing purpose, you can create a new BackupPC instance with following command.
**Please note that the basic usage is not suitable for production use.**

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    adferrand/backuppc
```

Latest BackupPC 4.x docker image will be downloaded if needed, and started. 
After starting, browse http://YOUR_SERVER_IP:8080 to access the BackupPC web Admin UI. 

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
    adferrand/backuppc
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
    adferrand/backuppc  
```

## UI authentication/authorization

By default, a single user with admin rights is created during the first start of the container. Its username is *backuppc* and its password is *password*. The credentials are stored in the file `/etc/backuppc/htpasswd` to allow the embedded lighttpd server to handle Basic Authentication, and the Backuppc config variable `$Conf{CgiAdminUsers}` is setted to this username to instruct BackupPC to give it admin rights. 

You can modify the admin user credentials by setting the environment variables `BACKUPPC_WEB_USER (default backuppc)` and `BACKUPPC_WEB_PASSWD (default password)` when creating the container.

The admin user credentials can be modified on an existing container by modifying the relevant environment variables, then re-creating the container. However please note that if you modify the username, you will need to manually remove the old username from the file `/etc/backuppc/htpasswd` in the container after its re-creation.

### Advanced UI authentication/authorization

One may need more advanced authentication/authorization on Backuppc Web UI, for instance several *normal* users allowing operations on backups, and an *admin* user to parameterize BackupPC.

In theses cases, authentication and admin granting must be configured manually.
* Authentication is configured by providing credentials in the file `/etc/backuppc/htpasswd` of the container. You should use Apache `htpasswd` utility to fill it.
* All authenticated users are considered as *normal* users if not telling otherwise. Add a username in the `$Conf{CgiAdminUsers}` variable of `/etc/backuppc/config.pl` file to grant this user admin rights.
* Then default admin user creation is not needed : unset environment variables `BACKUPPC_WEB_USER` and `BACKUPPC_WEB_PASSWD` to avoid adding an additional user in the `htpasswd` file, and reconfigure admin rights in `config.pl`.

For instance, with two *normal* users `user1` and `user2` + one *admin* user `admin`, you can do the following steps on the host. It is assumed that `/etc/backuppc` is mounted on `/var/docker-data/backuppc/etc` on the host and Apache `htpasswd` utility is installed on it.

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
    adferrand/backuppc  
```

Please note that Basic Authentication is still done unencrypted on HTTP port. See [UI SSL encryption](#ui-ssl-encryption) to secure the authentication.

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
    adferrand/backuppc
```

### Advanced SMTP configuration

In more complex scenarios, like sending notifications through a TLS-secured SMTP server with authentication (eg. Google SMTP), you can use any advanced configuration supported by MSMTP. To do so, mount or copy a user-wide SMTP configuration file `.msmtprc` in the volume `/home/backuppc`. This configuration will be used for any email sended by BackupPC.

See [MSMTP documentation](http://msmtp.sourceforge.net/doc/msmtp.html), in particular its [configuration examples](http://msmtp.sourceforge.net/doc/msmtp.html#Examples), to see how to build the configuration which suits your needs.

## Upgrading

To update the BackupPC version of this container:
* pull the new image version of this Docker,
* recreate the container. 

At first start, `configure.pl` script of BackupPC will be called. It will detect your existing configuration (under `/etc/backuppc`), your existing backup pool (under `/data/backuppc`), and will proceed any changes needed to match the new BackupPC version requirement.

### Dockerising an existing BackupPC v3.x

This sub-section is under Upgrading section because the process is very similar to a container upgrade.

Because configure.pl script is called on first run of your container instance, you can dockerise and upgrade to v4.X a pre-existing BackupPC v3.x installation.

To do so, let's assume that your BackupPC v3.x installed on your host:
* has its configuration in `/etc/backuppc`
* has its backup pool in `/var/lib/backuppc`
* has the user home running your BackupPC (typically backuppc) in `/home/backuppc`
* has its log files in `/var/log/backuppc`

Check UUID/GUID of your backuppc user on host. If they are not 1000/1000, you will need to put environment variables to customize theses values in the container instance (see [POSIX rights](#posix-rights)).

Then launch a container instance, mounting your existing BackupPC installation assets in the relevant volumes.

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    --volume /etc/backuppc:/etc/backuppc \
    --volume /home/backuppc:/home/backuppc \
    --volume /var/lib/backuppc:/data/backuppc \
    --volume /var/log/backuppc:/data/backuppc/log \
    adferrand/backuppc  
```

The configure.pl script will detect a v3.x version under /etc/backuppc, and will run appropriate upgrade operations (in particular enabling legacy v3.x pool to access it from a BackupPC v4.x).

## Miscellaneous

### Hostname

The backuppc host name will default to the container's hostname. You can modify this by setting `--hostname` in your `docker run` command like so:

```bash
docker run \
    --name backuppc \
    --hostname backuppc.example.org \
    --publish 80:8080 \
    adferrand/backuppc
```

### Timezone

By default the timezone of this docker is set to UTC. To modify it, you can specify a tzdata-compatible timezone in the environment variable `TZ`.

```bash
# For Paris time (including daylight)
docker run \
    --name backuppc \
    --publish 80:8080 \
    --env TZ=Europe/Paris \
    adferrand/backuppc
```

Alternatively, depending on the host OS, you can sync the container timezone to its host by mounting the host file `/etc/localtime` to the container path `/etc/localtime`.

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    --mount /etc/localtime:/etc/localtime:ro \
    adferrand/backuppc
```

### Shell access

For debugging and maintenance purpose, you may need to start a shell in your running container. With a Docker of version 1.3.0 or higher, you can do:

```bash
docker exec -it backuppc /bin/sh
```

You will obtain a shell with the standard tools of an Alpine distribution.

### Legacy version

Legacy version of BackupPC (v3.x) is available on the legacy tag `3`, or with explicit version tag (eg. `3.3.2`).

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    adferrand/backuppc:3
```
