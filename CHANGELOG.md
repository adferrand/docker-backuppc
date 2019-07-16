# Changelog

## Unreleased

## [4.3.1] - 17/07/2019
### Added
* Proper Docker signal handling (eg. SIGINT) by making Circus be the PID 1
* Support TLS in msmtp (thanks to @belaytzev in adferrand/docker-backuppc#22)

### Changed
* Update to BackupPC 4.3.1
* Update to rsync-bpc 3.1.2.1
* Update perl lib BackupPC::XS to 0.59

## [4.3.0-6] - 18/03/2019
### Added
* Install DejaVu font for a better look and readability of generated RRD graphs in BackupPC UI (#21 from @jkroepke)

## [4.3.0-5] - 10/03/2019
### Changed
* Use a passphrase of 4 characters (instead of 1) when generating self-signed certificates (`USE_SSL=true`) to be accepted by newest versions of OpenSSL.

## [4.3.0-4] - 09/03/2019
### Changed
* Update Alpine base image to 3.9

## [4.3.0-3] - 06/12/2018
### Added
* Hostname in BackupPC instance is now in sync with the container hostname, and can be set using `--hostname` at container start (#12 @Alveel)
* Add basic integration tests during the CI

### Changed
* Update perl lib BackupPC::XS to 0.58
* Update rsync-bpc to 3.1.2.0

## [4.3.0-2] - 27/11/2018
### Changed
* Bugfix: fallback to rsync-bpc to 3.0.9.12 and BackupPC::XS 0.57 because upstream is broken
* Versions 4.3.0-1 and 4.3.0 are also patched with this bugfix

## [4.3.0-1] - 26/11/2018
### Added
* Allow to use a pre-existing `server.pem` file mounted into the container to serve the BackupPC UI over https

## [4.3.0] - 26/11/2018
### Changed
* Update BackupPC to 4.2.0
* Update perl lib BackupPC::XS to 0.58
* Update rsync-bpc to 3.0.9.13

## [4.2.1-3] - 26/11/2018
### Added
* Add support for ACL to rsync-bpc (from @JoelLinn in #9)

## [4.2.1-2] - 09/10/2018
### Added
* Set up a complete CI/CD system for this Docker, using CircleCI: docker is now automatically packaged, tested and deployed to Docker Hub

### Changed
* Hotfix for BZIP2 binary, due to latest Alpine layout modifications, is now applied when the container is created, removing the error `n: /bin/bzip2: File exists` when container is restarted.

## [4.2.1-1] - 12/09/2018
### Added
* Add and configure circus, an alternative to supervisor, compatible with Python 3, with better control over environment variables propagation, and network sockets supervision (not used yet here)
* Mandatory perl modules for Backuppc are now installed as pre-compiled binaries from Alpine repos

### Changed
* Circus replaces Supervisor and manages now lighttpd + backuppc daemons
* Update Alpine base image to 3.8
* Update python from 2.7 to 3.6
* Improve build artifacts cleaning, image sized down from 78MB to 65MB

### Removed
* Remove supervisor and its configuration
* Remove build logic used to compile the mandatory perl modules

## [4.2.1] - 14/05/2018
### Changed
* Update BackupPC to 4.2.1

## [4.2.0] - 22/04/2018
### Changed
* Update BackupPC to 4.2.0

## [4.1.5-2] - 02/02/2018
### Changed
* Update Alpine base image to 3.7
* Update rsync-bpc to 3.0.9.12

## [4.1.5-1] - 28/12/2017
### Changed
* Update rsync-bpc to 3.0.9.11
* Update par2cmdline to 0.8.0

## [4.1.5] - 04/12/2017
### Changed
* Update BackupPC to 4.1.5
* Update perl lib BackupPC::XS to 0.57
* Update rsync-bpc to 3.0.9.9

## [4.1.4] - 29/11/2017
### Changed
* Update BackupPC to 4.1.4

## [4.1.3-10] - 15/11/2017
### Added
* Extends possibilities of `BACKUPPC_UUID`/`BACKUPPC_GUID`: previously existing `UUID`/`GUID` (like 100) in container could not be reused without error. This version now handles it: any `UUID`/`GUID` can be used.
* Extended supervisord logging capabilities over backuppc and lighttpd instances.

## [4.1.3-9] - 01/10/2017
### Added
* Add missing runtime libraries mandatory for par2

### Changed
* Update par2cmdline to 0.7.4

## [4.1.3-8] - 02/09/2017
### Changed
* TimeZone: fix inverted check of TZ, from PR #5 of @merikz

## [4.1.3-7] - 13/08/2017
### Changed
* Correct MIME types provided by the lighttpd server (issue #4 by @vb4life)
* Update par2cmdline to 0.7.3

## [4.1.3-6] - 02/08/2017
### Changed
* Add env variable driven timezone

## [4.1.3-5] - 23/07/2017
### Changed
* Disabling strict hostkey checking. As per the comment this should be the intended behavior.

## [4.1.3-4] - 26/06/2017
### Added
* Persist log dirs files in /data/backuppc

## [4.1.3-3] - 12/06/2017
### Changed
* Update perl lib BackupPC::XS to 0.56
* Update rsync-bpc to 3.0.9.8

## [4.1.3-2] - 08/06/2017
### Added
* Persist htpasswd config for admin access

## [4.1.3-1] - 07/06/2017
### Changed
* Update Alpine base image to 3.6

## [4.1.3] - 06/06/2017
### Changed
* Update BackupPC to 4.1.3
* Update perl lib BackupPC::XS to 0.55
* Update par2cmdline to 0.7.2

## [4.1.2-1] - 26/05/2017
### Changed
* Update perl lib BackupPC::XS to 0.54
* Update rsync-bpc to 3.0.9.7
* Disable strict host key checking

## [4.1.2] - 21/05/2017
### Changed
* Update BackupPC to 4.1.2

## [4.1.1] - 22/04/2017
### Changed
* Update BackupPC to 4.1.1

## [4.1.0] - 22/04/2017
### Changed
* Update BackupPC to 4.1.0

## [4.0.0] - 22/04/2017
### Added
* Create this docker and its core principles.