FROM alpine:3.3

RUN apk add --update g++ make perl-dev libxml2-dev openssl openssl-dev expat-dev bash \
    && rm -rf /var/cache/apk/*

RUN cpan install XML::LibXML LWP::Protocol::http10 LWP::Protocol::https

COPY aliases.sh /etc/profile.d/
COPY . /test/

WORKDIR /test/
ENTRYPOINT  ["./entrypoint.sh"]
CMD ["test"]


LABEL org.label-schema.docker.dockerfile="/Dockerfile" \
      org.label-schema.license="MIT" \
      org.label-schema.name="HTTP Test" \
      org.label-schema.vcs-type="Git" \
      org.label-schema.vcs-url="https://github.com/allamand/test-http"
