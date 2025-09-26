#!/bin/bash

pushd discord-voice-ips

bash voice-domains-generator.sh russia
cp ./voice_domains/discord-voice-ip-list /root/mnt/discord-voice-ip-list
popd