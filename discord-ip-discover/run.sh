#!/bin/bash

pushd discord-voice-ips

mkdir -p ./regions/russia/russia-voice-resolved
bash voice-domains-generator.sh
cp ./voice_domains/discord-voice-ip-list /root/mnt/discord-voice-ip-list
popd