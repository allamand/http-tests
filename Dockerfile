FROM alpine:3.3

RUN apk add --update g++ make perl-dev libxml2-dev openssl openssl-dev expat-dev bash \
    && rm -rf /var/cache/apk/*

#RUN apk add --update --no-cache \
#	libxml2-dev \
#	libgcrypt-dev \
#	gcc \
 #       perl \
  #      bash

#RUN apk add --no-cache \ 
#        --repository http://nl.alpinelinux.org/alpine/edge/community \
#        perl-xml-libxml

#RUN apk add --no-cache ca-certificates wget && \
#update-ca-certificates

#RUN apk --update add --virtual make gcc libxml2-dev \
#    && cpan install XML::LibXML
#    && cpan install XML/LibXML.pm
#XML::LibXML

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
      org.label-schema.vcs-url="https://github.com/allamand/http-test"