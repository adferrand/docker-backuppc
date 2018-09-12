#!/bin/sh

# Ensure directory and necessary sockets exists
mkdir -p /var/circus
touch /var/circus/endpoint /var/circus/pubsub /var/circus/stats

# Launch circus
/usr/bin/circusd /etc/circus.ini
