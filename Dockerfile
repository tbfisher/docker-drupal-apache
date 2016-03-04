# http://phusion.github.io/baseimage-docker/
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
FROM phusion/baseimage:0.9.18

MAINTAINER Brian Fisher <tbfisher@gmail.com>

RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# PHP
RUN add-apt-repository ppa:ondrej/php && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        php-cli             \
        php-common          \
        php-curl            \
        php-dev             \
        php-fpm             \
        php-gd              \
        php-imagick         \
        php-imap            \
        php-intl            \
        php-ldap            \
        php-mcrypt          \
        php-memcache        \
        php-mysql           \
        php-redis           \
        php-sqlite3         \
        php-tidy            \
        php-uploadprogress  \
        php-xml
        # php-xhprof

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        git                 \
        mysql-client

# Xdebug
ENV XDEBUG_VERSION='XDEBUG_2_4_0'
RUN git clone -b $XDEBUG_VERSION --depth 1 https://github.com/xdebug/xdebug.git /usr/local/src/xdebug
RUN cd /usr/local/src/xdebug && \
    phpize      && \
    ./configure && \
    make clean  && \
    make        && \
    make install
COPY ./conf/php/mods-available/xdebug.ini /etc/php/7.0/mods-available/xdebug.ini

# Apache
RUN add-apt-repository 'deb http://us.archive.ubuntu.com/ubuntu/ trusty multiverse' && \
    add-apt-repository 'deb http://us.archive.ubuntu.com/ubuntu/ trusty-updates multiverse' && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        apache2                 \
        libapache2-mod-fastcgi  \
        ssl-cert
RUN service apache2 stop
RUN a2enmod \
    headers     \
    rewrite
RUN a2dissite 000-default
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

# SSH
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        openssh-server
RUN dpkg-reconfigure openssh-server

# sSMTP
# note php is configured to use ssmtp, which is configured to send to mail:1025,
# which is standard configuration for a mailhog/mailhog image with hostname mail.
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        ssmtp

# Configure
RUN mkdir /var/www_files && \
    chgrp www-data /var/www_files && \
    chmod 775 /var/www_files
COPY ./conf/php/fpm/php.ini /etc/php/7.0/fpm/php.ini
COPY ./conf/php/fpm/pool.d/www.conf /etc/php/7.0/fpm/pool.d/www.conf
COPY ./conf/php/cli/php.ini /etc/php/7.0/cli/php.ini
COPY ./conf/apache2/apache2.conf /etc/apache2/apache2.conf
COPY ./conf/apache2/conf-available/php5-fpm.conf /etc/apache2/conf-available/php5-fpm.conf
COPY ./conf/apache2/sites-available /etc/apache2/sites-available
COPY ./conf/ssh/sshd_config /etc/ssh/sshd_config
COPY ./conf/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf
RUN phpenmod \
    # fpm    \
    mcrypt \
    xdebug
    # xhprof
RUN a2enmod actions
RUN a2enconf php5-fpm
RUN a2ensite default default-ssl

# Use baseimage-docker's init system.
ADD init/ /etc/my_init.d/
ADD services/ /etc/service/
RUN chmod -v +x /etc/service/*/run
RUN chmod -v +x /etc/my_init.d/*.sh

EXPOSE 80 443 22

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
