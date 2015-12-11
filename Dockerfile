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
RUN add-apt-repository ppa:ondrej/php-7.0 && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        php-cli         \
        php-common      \
        php-curl        \
        php-gd          \
        php-imap        \
        php-intl        \
        php-ldap        \
        php-mysql       \
        php-sqlite3     \
        php-tidy
        # php-imagick
        # php-memcache
        # php-mcrypt
        # php-redis
        # php-xhprof
# RUN php5enmod \
#     mcrypt \
#     xhprof

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        git         \
        php-dev

# Xdebug
ENV XDEBUG_VERSION='XDEBUG_2_4_0beta1'
RUN git clone -b $XDEBUG_VERSION --depth 1 https://github.com/xdebug/xdebug.git /usr/local/src/xdebug
RUN cd /usr/local/src/xdebug && \
    phpize      && \
    ./configure && \
    make clean  && \
    make        && \
    make install
COPY ./conf/php/mods-available/xdebug.ini /etc/php/7.0/mods-available/xdebug.ini
RUN ln -s /etc/php/7.0/mods-available/xdebug.ini /etc/php/7.0/cli/conf.d/20-xdebug.ini

# Apache
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        apache2                 \
        libapache2-mod-php     \
        ssl-cert
RUN service apache2 stop
RUN a2enmod \
    headers     \
    rewrite
# RUN php5enmod -s apache2 \
#     mcrypt \
#     xhprof \
RUN ln -s /etc/php/7.0/mods-available/xdebug.ini /etc/php/7.0/apache2/conf.d/20-xdebug.ini
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

# Drush
RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install --yes \
        mysql-client
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/local/bin --filename=composer
ENV DRUSH_VERSION='8.0.0-rc3'
RUN git clone -b $DRUSH_VERSION --depth 1 https://github.com/drush-ops/drush.git /usr/local/src/drush
RUN cd /usr/local/src/drush && composer install
RUN ln -s /usr/local/src/drush/drush /usr/local/bin/drush
RUN drush -y dl --destination=/usr/local/src/drush/commands registry_rebuild
COPY ./conf/drush/drush-remote.sh /usr/local/bin/drush-remote
RUN chmod +x /usr/local/bin/drush-remote

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
COPY ./conf/php/apache2/php.ini /etc/php/7.0/apache2/php.ini
COPY ./conf/php/cli/php.ini /etc/php/7.0/cli/php.ini
COPY ./conf/apache2/sites-available /etc/apache2/sites-available
COPY ./conf/ssh/sshd_config /etc/ssh/sshd_config
COPY ./conf/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf
RUN a2ensite default default-ssl

# Use baseimage-docker's init system.
ADD init/ /etc/my_init.d/
ADD services/ /etc/service/
RUN chmod -v +x /etc/service/*/run
RUN chmod -v +x /etc/my_init.d/*.sh

EXPOSE 80 443 22

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
