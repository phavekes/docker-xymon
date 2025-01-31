FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive TZ=posixrules
ADD AutomaticCleanup /etc/apt/apt.conf.d/99AutomaticCleanup

# Install what we need from Ubuntu
RUN apt-get update && \
    apt-get install -y curl xymon apache2 ssmtp mailutils rrdtool ntpdate && \
    apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/ && \
    rm -rf /var/lib/apt/lists/*

# Get the 'dumb init' package for proper 'init' behavior
RUN curl -L https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_amd64.deb > dumb-init.deb && \
    dpkg -i dumb-init.deb && \
    rm dumb-init.deb

ADD add-files /

# Enable necessary apache components
# make sure the "localhost" is correctly identified
# and ensure the ghost list can be updated
# Then, save the configuration so when this container starts with a
# blank volume, we can initialize it

RUN a2enmod rewrite authz_groupfile cgi; \
     perl -i -p -e "s/^127.0.0.1.*/127.0.0.1    xymon-docker # bbd http:\/\/localhost\//" /etc/xymon/hosts.cfg; \
     chown xymon:xymon /etc/xymon/ghostlist.cfg /var/lib/xymon/www ; \
     tar -C /etc/xymon -czf /root/xymon-config.tgz . ; \
     tar -C /var/lib/xymon -czf /root/xymon-data.tgz .

# Redirect Xymon logs to stdout, so they can be vieuwed with `docker logs`

RUN mkdir -p /var/log/xymon/ \
  && ln -sf /dev/stderr /var/log/xymon/acknowledge.log \
  && ln -sf /dev/stderr /var/log/xymon/alert.log \
  && ln -sf /dev/stderr /var/log/xymon/clientdata.log \
  && ln -sf /dev/stderr /var/log/xymon/combostatus.log \
  && ln -sf /dev/stderr /var/log/xymon/dynmic-hosts.log \
  && ln -sf /dev/stderr /var/log/xymon/history.log \
  && ln -sf /dev/stderr /var/log/xymon/hostdata.log \
  && ln -sf /dev/stderr /var/log/xymon/notifications.log \
  && ln -sf /dev/stderr /var/log/xymon/rrd-data.log \
  && ln -sf /dev/stderr /var/log/xymon/rrd-status.log \
  && ln -sf /dev/stderr /var/log/xymon/xymonclient.log \
  && ln -sf /dev/stderr /var/log/xymon/xymond.log \
  && ln -sf /dev/stderr /var/log/xymon/xymongen.log \
  && ln -sf /dev/stderr /var/log/xymon/xymonlaunch.log \
  && ln -sf /dev/stderr /var/log/xymon/xymonnet.log \
  && ln -sf /dev/stderr /var/log/xymon/xymonnetagain.log \
  && chown -R xymon /var/log/xymon

VOLUME /etc/xymon /var/lib/xymon
EXPOSE 80 1984

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/etc/init.d/container-start"]
