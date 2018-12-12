# Foreman XEN Plugin

[![Build Status](https://api.travis-ci.org/theforeman/foreman-xen.svg)](https://travis-ci.org/theforeman/foreman-xen)
[![Code Climate](https://codeclimate.com/github/theforeman/foreman-xen/badges/gpa.svg)](https://codeclimate.com/github/theforeman/foreman-xen)

This plugin enables managing of XEN Server as a Compute Resource in Foreman.

## Installation

Packages are available for Debian based distribtions as **ruby-foreman-xen** and for Red Hat based distributions as **ruby193-rubygem-foreman_xen** The gem name is **foreman_xen**.

Please see the Foreman manual for further instructions:

* [Foreman: How to Install a Plugin](http://theforeman.org/plugins/#2.Installation)

## Image based provisioning

In order to use the cloud-init functionality users need to:

- install the `genisoimage` package
- mount a "NFS ISO Library" (as XenServer calls it) which is attached to the Xen pool to a location writable by the foreman user.
- set this mount point / path as ISO library mountpoint in the compute resource

foreman_xen then creates a network configuration file, renders the user_data template, puts them in an ISO, copies this ISO to the attached ISO-library and attaches it to the created VM, where cloud-init can use the data provided to initialize the VM.

## Compatibility

| Foreman Version | Plugin Version       |
| --------------- | ---------------------|
| >=1.5, <1.8     | 0.0.x (unmaintained) |
| >=1.8.1, <1.10  | 0.1.x (unmaintained) |
| >=1.10, <1.11   | 0.2.x (unmaintained) |
| >=1.11, <1.13   | 0.3.x (unmaintained) |
| >=1.13, <1.14   | 0.4.x (unmaintained) |
| >=1.14, <1.17   | 0.5.x (unmaintained) |
| >=1.17, <1.18   | 0.6.x (unmaintained) |
| >=1.18          | 0.7.x                |

## Support

http://projects.theforeman.org/projects/xen/issues

# Copyright

Copyright (c) 2014 ooVoo LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
