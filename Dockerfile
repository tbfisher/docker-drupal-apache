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
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        php-pear        \
        php5-cli        \
        php5-common     \
        php5-curl       \
        php5-dev        \
        php5-fpm        \
        php5-gd         \
        php5-imagick    \
        php5-imap       \
        php5-intl       \
        php5-json       \
        php5-ldap       \
        php5-mcrypt     \
        php5-memcache   \
        php5-mysql      \
        php5-redis      \
        php5-sqlite     \
        php5-tidy       \
        php5-xdebug     \
        php5-xhprof
RUN service php5-fpm stop

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        git

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
RUN php5enmod -s apache2 \
    mcrypt \
    xhprof \
    xdebug
RUN a2dissite 000-default
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

# SSH (for remote drush)
RUN rm -f /etc/service/sshd/down

# sSMTP
# note php is configured to use ssmtp, which is configured to send to mail:1025,
# which is standard configuration for a mailhog/mailhog image with hostname mail.
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        ssmtp

# Configure
COPY ./conf/php5/fpm/php.ini /etc/php5/fpm/php.ini
COPY ./conf/php5/fpm/pool.d/www.conf /etc/php5/fpm/pool.d/www.conf
COPY ./conf/php5/cli/php.ini /etc/php5/cli/php.ini
COPY ./conf/apache2/apache2.conf /etc/apache2/apache2.conf
COPY ./conf/apache2/conf-available/php5-fpm.conf /etc/apache2/conf-available/php5-fpm.conf
COPY ./conf/apache2/sites-available /etc/apache2/sites-available
COPY ./conf/ssh/sshd_config /etc/ssh/sshd_config
COPY ./conf/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf
# Prevent php warnings
RUN sed -ir 's@^#@//@' /etc/php5/mods-available/*
RUN php5enmod \
    mcrypt \
    xdebug \
    xhprof
RUN a2enmod actions
RUN a2enconf php5-fpm
RUN a2ensite default default-ssl

# Configure directories for drupal.
RUN mkdir /var/www_files && \
    mkdir -p /var/www_files/public && \
    mkdir -p /var/www_files/private && \
    chown -R www-data:www-data /var/www_files
# Virtualhost is configured to serve from /var/www/web.
RUN mkdir /var/www/web && \
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
