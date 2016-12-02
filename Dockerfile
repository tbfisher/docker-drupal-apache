# http://phusion.github.io/baseimage-docker/
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
FROM phusion/baseimage:0.9.19

MAINTAINER Brian Fisher <tbfisher@gmail.com>

RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Upgrade OS
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold"

# PHP
RUN add-apt-repository ppa:ondrej/php && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        php-pear          \
        php7.1-cli        \
        php7.1-common     \
        php7.1-curl       \
        php7.1-dev        \
        php7.1-fpm        \
        php7.1-gd         \
        php7.1-imagick    \
        php7.1-imap       \
        php7.1-intl       \
        php7.1-json       \
        php7.1-ldap       \
        php7.1-mbstring   \
        php7.1-mcrypt     \
        php7.1-memcache   \
        php7.1-mysql      \
        php7.1-opcache    \
        php7.1-readline   \
        # php7.1-redis      \
        php7.1-sqlite     \
        php7.1-tidy       \
        # php7.1-xdebug     \
        php7.1-xml        \
        php7.1-zip
        # php7.1-xhprof

# Xdebug
ENV XDEBUG_VERSION='XDEBUG_2_5_0RC1'
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        git
RUN git clone -b $XDEBUG_VERSION --depth 1 https://github.com/xdebug/xdebug.git /usr/local/src/xdebug
RUN cd /usr/local/src/xdebug && \
    phpize      && \
    ./configure && \
    make clean  && \
    make        && \
    make install
COPY ./conf/php/mods-available/xdebug.ini /etc/php/7.1/mods-available/xdebug.ini

# Apache
RUN add-apt-repository 'deb http://us.archive.ubuntu.com/ubuntu/ trusty multiverse' && \
    add-apt-repository 'deb http://us.archive.ubuntu.com/ubuntu/ trusty-updates multiverse' && \
    add-apt-repository 'deb http://security.ubuntu.com/ubuntu  trusty-security main multiverse' && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        apache2                 \
        libapache2-mod-fastcgi
RUN a2enmod     \
    alias       \
    actions     \
    fastcgi     \
    headers     \
    rewrite
RUN a2dissite 000-default
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

# SSH (for remote drush)
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

# Drush, console
RUN cd /usr/local/bin/ && \
    curl http://files.drush.org/drush.phar -L -o drush && \
    chmod +x drush
COPY ./conf/drush/drush-remote.sh /usr/local/bin/drush-remote
RUN chmod +x /usr/local/bin/drush-remote
RUN cd /usr/local/bin/ && \
    curl https://drupalconsole.com/installer -L -o drupal && \
    chmod +x drupal

# Required for drush, convenience utilities, etc.
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        git                 \
        mysql-client        \
        screen

# Configure PHP
RUN mkdir /run/php
RUN cp /etc/php/7.1/fpm/php.ini /etc/php/7.1/fpm/php.ini.bak
COPY ./conf/php/fpm/php.ini-development /etc/php/7.1/fpm/php.ini
# COPY /conf/php/fpm/php.ini-production /etc/php/7.1/fpm/php.ini
RUN cp /etc/php/7.1/fpm/pool.d/www.conf /etc/php/7.1/fpm/pool.d/www.conf.bak
COPY /conf/php/fpm/pool.d/www.conf /etc/php/7.1/fpm/pool.d/www.conf
RUN cp /etc/php/7.1/cli/php.ini /etc/php/7.1/cli/php.ini.bak
COPY /conf/php/cli/php.ini-development /etc/php/7.1/cli/php.ini
# COPY /conf/php/cli/php.ini-production /etc/php/7.1/cli/php.ini
# Prevent php warnings
RUN sed -ir 's@^#@//@' /etc/php/7.1/mods-available/*
RUN phpenmod \
    mcrypt \
    xdebug
    # xhprof

# Configure Apache
RUN cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak
COPY ./conf/apache2/apache2.conf /etc/apache2/apache2.conf
RUN cp /etc/apache2/conf-available/php7.1-fpm.conf /etc/apache2/conf-available/php7.1-fpm.conf.bak
COPY ./conf/apache2/conf-available/php7.1-fpm.conf /etc/apache2/conf-available/php7.1-fpm.conf
RUN cp -r /etc/apache2/sites-available /etc/apache2/sites-available.bak
COPY ./conf/apache2/sites-available /etc/apache2/sites-available
RUN a2enconf php7.1-fpm
RUN a2ensite default

# Configure sshd
RUN cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
COPY ./conf/ssh/sshd_config /etc/ssh/sshd_config
RUN cp /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.bak
COPY ./conf/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf

# Configure directories for drupal.
RUN mkdir /var/www_files && \
    mkdir -p /var/www_files/public && \
    mkdir -p /var/www_files/private && \
    chown -R www-data:www-data /var/www_files
VOLUME /var/www_files
# Virtualhost is configured to serve from /var/www/web.
RUN mkdir -p /var/www/web && \
    echo '<?php phpinfo();' > /var/www/web/index.php && \
    chgrp www-data /var/www_files && \
    chmod 775 /var/www_files

# https://github.com/phusion/baseimage-docker/pull/339
# https://github.com/phusion/baseimage-docker/pull/341
RUN sed -i 's/syslog/adm/g' /etc/logrotate.conf

# Use baseimage-docker's init system.
ADD init/ /etc/my_init.d/
RUN chmod -v +x /etc/my_init.d/*.sh
ADD services/ /etc/service/
RUN chmod -v +x /etc/service/*/run

EXPOSE 80 22

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
