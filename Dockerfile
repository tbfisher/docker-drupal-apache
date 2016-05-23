# http://phusion.github.io/baseimage-docker/
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
FROM phusion/baseimage:0.9.18

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
        php-mbstring        \
        php-mcrypt          \
        php-memcache        \
        php-mysql           \
        php-redis           \
        php-sqlite3         \
        php-tidy            \
        php-uploadprogress  \
        php-xdebug          \
        php-xml
        # php-xhprof

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        git                 \
        mysql-client

# Apache
RUN add-apt-repository 'deb http://us.archive.ubuntu.com/ubuntu/ trusty multiverse' && \
    add-apt-repository 'deb http://us.archive.ubuntu.com/ubuntu/ trusty-updates multiverse' && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        apache2                 \
        libapache2-mod-fastcgi  \
        ssl-cert
RUN service apache2 stop
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

# Configure
RUN cp /etc/php/7.0/fpm/php.ini /etc/php/7.0/fpm/php.ini.bak
COPY ./conf/php/fpm/php.dev.ini /etc/php/7.0/fpm/php.ini
RUN cp /etc/php/7.0/fpm/pool.d/www.conf /etc/php/7.0/fpm/pool.d/www.conf.bak
COPY ./conf/php/fpm/pool.d/www.conf /etc/php/7.0/fpm/pool.d/www.conf
RUN cp /etc/php/7.0/cli/php.ini /etc/php/7.0/cli/php.ini.bak
COPY ./conf/php/cli/php.dev.ini /etc/php/7.0/cli/php.ini
RUN cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak
COPY ./conf/apache2/apache2.conf /etc/apache2/apache2.conf
RUN cp /etc/apache2/conf-available/php7.0-fpm.conf /etc/apache2/conf-available/php7.0-fpm.conf.bak
COPY ./conf/apache2/conf-available/php7.0-fpm.conf /etc/apache2/conf-available/php7.0-fpm.conf
RUN cp -r /etc/apache2/sites-available /etc/apache2/sites-available.bak
COPY ./conf/apache2/sites-available /etc/apache2/sites-available
RUN cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
COPY ./conf/ssh/sshd_config /etc/ssh/sshd_config
RUN cp /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.bak
COPY ./conf/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf
RUN phpenmod    \
    mcrypt      \
    xdebug
    # xhprof
RUN a2enmod     \
    actions     \
    headers     \
    rewrite     \
    ssl
RUN a2enconf php7.0-fpm
RUN a2ensite default default-ssl

# Configure directories for drupal.
RUN mkdir /var/www_files && \
    mkdir -p /var/www_files/public && \
    mkdir -p /var/www_files/private && \
    chown -R www-data:www-data /var/www_files
VOLUME /var/www_files
# Virtualhost is configured to serve from /var/www/web.
RUN mkdir /var/www/web && \
    echo '<?php phpinfo();' > /var/www/web/index.php && \
    chgrp www-data /var/www_files && \
    chmod 775 /var/www_files

# Use baseimage-docker's init system.
ADD init/ /etc/my_init.d/
RUN chmod -v +x /etc/my_init.d/*.sh
ADD services/ /etc/service/
RUN chmod -v +x /etc/service/*/run

EXPOSE 80 443 22

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
