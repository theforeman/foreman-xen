# Foreman XEN Plugin

This plugin enables provisioning and managing XEN Server in Foreman.

This is a fork of the original that has or will have a few changes that my workplace required:
* Provision para-virtual images directly rather than using HVM and then converting. - Done
* Allow snapshots to be taken of machines via the Web UI.

The implementation is rather hacky and right now would probably break other providers that are installed, so I won't
be pushing any more upstream changes. Though I've had good results using CentOS and I would imagine it would work fine
with Redhat as well.

## Installation

Please see the Foreman manual for appropriate instructions:

* [Foreman: How to Install a Plugin](http://theforeman.org/manuals/latest/index.html#6.1InstallaPlugin)

The gem name is "foreman_xen".

## Compatibility

| Foreman Version | Plugin Version |
| ---------------:| --------------:|
| >=  1.5         | 0.0.3          |

## Latest code

You can get the develop branch of the plugin by specifying your Gemfile in this way:

    gem 'foreman_xen', :git => "https://github.com/theforeman/foreman-xen.git"

    or

    gem 'foreman_xen', :git => "https://github.com/HeWhoWas/foreman-xen.git"

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
