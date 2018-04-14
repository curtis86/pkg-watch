# pkg-watch

## A. Summary

Want to get an email notification when an important yum update is available?

**pkg-watch** monitors a defined list of yum packages, and then sends an email notification when a monitored package update is available.

## B. Dependencies

 * yum-based OS (ie. RHEL or CentOS)
 * mail

## C. Supported Systems

**pkg-watch** has been tested on CentOS Linux 7 and RHEL 7, and should work on any other modern yum-based Linux distro.

### Installation

1. Clone this repo to your preferred directory (eg: `/opt/`)

```
cd /opt
git clone https://github.com/curtis86/pkg-watch
```

2. Follow the usage instructions below!

### Usage

1) Define a list of packages that you wish to monitor in `config/packages`

2) Define a list of contact email address that you would like to notify on package updates in `config/contacts`

3) Schedule `pkg-watch update` to run as a cronjob at your preferred interval (I run mine every 60 minutes), ie:

`0 * * * * $USER $PKG_WATCH_PATH`

> Please set `$USER` to the actual user that you want **pkg-watch** to run as, and set `$PKG_WATCH_PATH` to your actual full path of **pkg-watch**

4) The default yum cache refresh timeout can be overridden - please see `config/pkg-watch.conf-sample`

An example of some important packages to monitor can be:

```
kernel
httpd
mod_ssl
openssl
openssh-server
openssh-clients
```


## Notes

**pkg-watch** can run as an unprivileged user! I always recommend PoLP (principle of least privilege) wherever possible, so please run this as an unprivileged user.

**pkg-watch** lets you define your own yum metadata cache expiry - please be mindful in setting to something considerate of your local yum mirror.

## Disclaimer

I'm not a programmer, but I do like to make things! Please use this at your own risk.

## License

The MIT License (MIT)

Copyright (c) 2018 Curtis K

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
