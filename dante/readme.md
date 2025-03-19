https://hub.docker.com/r/davojan/dante-pam

0. docker-compose up
1. docker exec dante htpasswd -bd /etc/danted/sockd.passwd rugnar mypassword
2. curl -x socks5://rugnar:mypasswo@localhost:1080 -I https://github.com/
