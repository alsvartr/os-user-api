## OS-USER-API
Simple API server for delivering OpenStack cinder block storage usage data to third party apps.

Currently supported cinder backends: SharedLVMDriver and Ceph (planned).

It uses ruby, net-ssh for getting LVM data from compute nodes and TCPServer.

## Features

* usage data for cinder volume types and zones

* periodic updates

* syslog logging

* JSON API itself

## Installation

via rubygems:

* gem install json, gem install net-ssh, gem install daemons

via package manager:

* apt-get install ruby-net-ssh ruby-json ruby-daemons

* yum install rubygem-net-ssh rubygem-json rubygem-daemons

## Usage:

* through systemd unit or init.d script

* "./start.rb run" in foreground
