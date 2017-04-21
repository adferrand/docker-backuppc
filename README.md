# adferrand/backuppc [![](https://images.microbadger.com/badges/version/adferrand/backuppc:4.1.1.svg)](https://microbadger.com/images/adferrand/backuppc:4.1.1 "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/adferrand/backuppc:4.1.1.svg)](https://microbadger.com/images/adferrand/backuppc:4.1.1 "Get your own image badge on microbadger.com")

* [Introduction](#introduction)
* [Container functionalities](#container-functionalities)
* [Basic usage](#basic-usage)
* [Data persistency](#data-persistency)
	* [POSIX rights](#posix-rights)
* [UI SSL encryption](#ui-ssl-encryption)
	* [Self-signed certificate](#self-signed-certificate)
	* [Advanced SSL use](#advanced-ssl-use)
* [SMTP configuration for notification delivery](#smtp-configuration-for-notification-delivery)
	* [Relay notifications to a local SMTP](#relay-notifications-to-a-local-smtp)
	* [Advanced SMTP configuration](#advanced-smtp-configuration)
* [Upgrading](#upgrading)
	* [Dockerising an existing BackupPC v3.x](#dockerising-an-existing-backuppc-v3x)
* [Shell access](#shell-access)

# Introduction

![BackupPC Logo](http://backuppc.sourceforge.net/images/icons/BackupPC/mid/logo.gif)
BackupPC is a free self-hosted backup software which allow to make backup of remote hosts through various ways like rsync, smb or tar. It supports full and incremental backups, and reconstruct automatically a usable verbatim from any backup version. Started with version 4, BackupPC uses a new way to store backups using a reverse delta approach and no hardlinks.

See [BackupPC documentation](http://backuppc.sourceforge.net/BackupPC-4.1.1.html) for further details and how to use it.

# Container functionalities

This docker is designed to provide a ready-to-go and maintainable BackupPC instance for your backups.

* Provides a full-featured BackupPC version 4.1.1 ready to work. In particular, all backup protocols embedded by BackupPC are supported.
* BackupPC Admin web UI is exposed on 8080 port by an embedded lighttpd server. Available protocols are HTTP or HTTPS through a self-signed SSL certificate.
* Existing BackupPC configuration & pool are self-upgraded at first run of a newly created container instance. It allows for instance dockerisation of a pre-existing BackupPC v3.X instance.
* Container image is constructed on top of an Alpine distribution to reduce the footprint. Image size is below 80MB.

# Basic usage

For testing purpose, you can create a new BackupPC instance with following command.

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    adferrand/backuppc:4.1.1
```

Docker image will be downloaded if needed, and started. After starting, browse http://YOUR_SERVER_IP:8080 to access the BackupPC web Admin UI. A user/password will be asked: they are backuppc/password. You can then test your BackupPC instance.

Please note that the basic usage is not suitable for production use. BackupPC configuration and pool are persisted as anonymous data containers (see [Data persistency](#data-persistency)) with a weak control over it. Moreover BackupPC web Admin UI is accessed from the unsecured HTTP protocol, exposing your user/password and data you could retrieve from the UI (see [UI SSL encryption](#ui-ssl-encryption)).

# Data persistency

As we are taking about backups, you certainly want to control the data persistency of your docker instance.

It declares three volumes :

* `/etc/backuppc`: stores the BackupPC configuration, in particular config.pl and hosts configuration.
* `/home/backuppc`: home of the backuppc user, running your BackucPC instance, and contains in particular a .ssh directory with the SSH keys used to make backups through SSH protocol (see [SSH Keys](#ssh-keys)).
* `/data/backuppc`: contains the BackupPC pool, so your backups themselves.

It is advised to mount these volumes on the host to persist your backups. Assuming a host directory `/var/docker-data/backuppc{etc,home,data}`, mounted on a big filesystem, you can do for instance :

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    --volume /var/docker-data/backuppc/etc:/etc/backuppc \
    --volume /var/docker-data/backuppc/home:/home/backuppc \
    --volume /var/docker-data/backuppc/data:/data/backuppc \
    adferrand/backuppc:4.1.1
```

All  your backuppc configuration, backup and keys will survive the container destroy/re-creation.

## POSIX rights

The mounted host directory used for data persistency need to be accessible by the host user corresponding to the backuppc user created in container instance. By default, this backuppc user is of `UUID 1000` and `GUID 1000`, which should correspond to the first non-root user create on your host.

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
    adferrand/backuppc:4.1.1   
```

# UI SSL encryption

By default, BackupPC web Admin UI is exposed by the non secured HTTP protocol. Two advised ways to secure this are exposed.

## Self-signed certificate

Set the environment variable `USE_SSL (default: false)` to `true`, and the embedded lighttpd server will expose the UI by HTTPS protocol, using a self-signed certificate generated during first run of the container instance.

```bash
docker run \
    --name backuppc \
    --publish 443:8080 \
    --env 'USE_SSL=true'
```

Then you can access the UI through the secured URL https://YOUR_SERVER_IP/. Of course, as the SSL certificate is self-signed, your browser will alert you about this unsecured certificate.

## Advanced SSL use

Instead of providing a very advanced SSL configuration in this Docker, and reinvent the wheel, it is adviced to run your backuppc instance without SSL and without exposing the 8080 port, and launch a second container with a secured SSL reverse-proxy pointing to the BackupPC instance.

You will be able to make routing based on DNS, use certificates signed by Let's Encrypt and so on. See [nginx-proxy](https://github.com/jwilder/nginx-proxy) + [letsencrypt-nginx-proxy-companion](https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion) or [traefik](https://hub.docker.com/_/traefik/) for more information.

# SMTP configuration for notification delivery

BackupPC can send notifications by mail to inform users about backups state. This docker include the MSMTP utility, which basically rely all mails to a pre-existing SMTP server.

Two configuration approaches are available.

## Relay notifications to a local SMTP

If you are using BackupPC to backup your IT architecture, it is likely that you have alreay a SMTP server configured on your host or local network. Or you can instantiate a dockerised full-featured SMTP server (like [namshi/smtp](https://github.com/namshi/docker-smtp)) on the same network than the backuppc container.

In both cases, the SMTP server should be accessible to the backuppc container through YOUR_SMTP_FQDN on port 25. Set the environment variable `SMTP_HOST` (default: mail.example.org) to YOUR_SMTP_FQDN before creating the BackupPC container, and all mails emitted by BackupPC will be relayed on this SMTP server. 

You should also set the _optional_ environment variable `SMTP_MAIL_DOMAIN (default empty)` to the domain you manage, in order to resolve automatically the right part of the email sender to this domain if it is not specified by BackupPC. Indeed by default, sender mail of BackupPC notifications is only 'backuppc', without right part: these emails are likely to be refused by most SMTP servers.

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    --env SMTP_HOST=smtp.my-domain.org \
    --env SMTP_MAIL_DOMAIN=my-domain.org \
    adferrand/backuppc:4.1.1
```

## Advanced SMTP configuration

In more complex scenarios, like sending notifications through a TLS-secured SMTP server with authentication (eg. Google SMTP), you can use any advanced configuration supported by MSMTP. To do so, mount or copy a user-wide SMTP configuration file `.msmtp` in the volume `/home/backuppc`. This configuration will be used for any email sended by BackupPC.

See [MSMTP documentation](http://msmtp.sourceforge.net/doc/msmtp.html), in particular its [configuration examples](http://msmtp.sourceforge.net/doc/msmtp.html#Examples), to see how to build the configuration which suits your needs.

# Upgrading

To update the BackupPC version of this container:
* pull the new image version of this Docker,
* recreate the container. 

At first start, `configure.pl` script of BackupPC will be called. It will detect your existing configuration (under `/etc/backuppc`), your existing backup pool (under `/data/backuppc`), and will proceed any changes needed to match the new BackupPC version requirement.

## Dockerising an existing BackupPC v3.x

This sub-section is under Upgrading section because the process is very similar to a container upgrade.

Because configure.pl script is called on first run of your container instance, you can dockerise and upgrade to v4.X a pre-existing BackupPC v3.x installation.

Do to so, let's assume that your BackupPC v3.x installed on your host:
* has its configuration in `/etc/backuppc`
* has its backup pool in `/var/lib/backuppc`
* has the user home running your BackupPC (typically backuppc) in `/home/backuppc`

Check UUID/GUID of your backuppc user on host. If they are not 1000/1000, you will need to put environment variables to customize theses values in the container instance (see [POSIX rights](#posix-rights)).

Then launch a container instance, mounting your existing BackupPC installation assets in the relevant volumes.

```bash
docker run \
    --name backuppc \
    --publish 80:8080 \
    --volume /etc/backuppc:/etc/backuppc \
    --volume /home/backuppc:/home/backuppc \
    --volume /var/lib/backuppc:/data/backuppc \
    adferrand/backuppc:4.1.1  
```

The configure.pl script will detect a v3.x version under /etc/backuppc, and will run appropriate upgrade operations (in particular enabling legacy v3.x pool to access it from a BackupPC v4.x).

# Shell access

For debugging and maintenance purpose, you may need to start a shell in your running container. With a Docker of version 1.3.0 or higher, you can do:

```bash
docker exec -it backuppc /bin/sh
```

You will obtain a shell with the standard tools of an Alpine distribution.
