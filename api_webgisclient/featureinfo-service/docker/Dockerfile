FROM sourcepole/qwc-feature-info-service

RUN localedef -i de_CH -c -f UTF-8 -A /usr/share/locale/locale.alias de_CH.UTF-8
ENV LANG de_CH.utf8
ENV PGSERVICEFILE /usr/etc/postgresql/pg_service.conf

RUN mkdir -p /srv/qwc_service/config/default
ADD custom /srv/qwc_service/info_modules/custom
