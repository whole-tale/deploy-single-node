FROM python:3.12-slim

LABEL maintainer="Kacper Kowalik <xarthisius.kk@gmail.com>"

ENV DEBIAN_FRONTEND=noninteractive \
  LANG=en_US.UTF-8 \
  LC_ALL=C.UTF-8

RUN apt-get update -qy \
  && apt-get install -yq --no-install-recommends \
    tini \
    git \
    libcairo2 \
    libmagic1 \
    libmagic-mgc \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install \
  'gwvolman>=2.1.2' \
  'girder-wholetale>=2.0.1'

RUN groupadd -g 1000 girder && useradd -g 1000 -G 1000 -u 1000 -m -s /bin/bash girder

EXPOSE 8080

USER girder
ENTRYPOINT ["/usr/bin/tini", "--", "girder", "serve", "--host", "0.0.0.0", "--mode=production"]
