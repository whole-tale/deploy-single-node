FROM python:3.12-slim

RUN apt update -qqy && \
  DEBIAN_FRONTEND=noninteractive apt install -qy tini && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*

RUN pip install gwvolman>=2.1.2
RUN groupadd -g 999 docker && groupadd -g 1000 ubuntu && useradd -g 1000 -G 999 -u 1000 -m -s /bin/bash ubuntu

ENV GIRDER_WORKER_BROKER=redis://redis/ GIRDER_WORKER_BACKEND=redis://redis/

USER ubuntu
ENTRYPOINT ["/usr/bin/tini", "--", "python3", "-m", "girder_worker", "-l", "INFO", "-c", "3"]
