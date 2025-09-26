FROM ubuntu:20.04

# disable apt prompts
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /root

RUN apt update && \
    apt install -y  \
    git parallel dnsutils

RUN git clone https://github.com/GhostRooter0953/discord-voice-ips.git

COPY run.sh .
CMD ["bash", "run.sh"]
