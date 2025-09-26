FROM ubuntu:20.04

# disable apt prompts
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /root

RUN apt update && \
    apt install git parallel dnsutils

COPY discover-voice.sh .

CMD ["bash", "discover-voice.sh"]
