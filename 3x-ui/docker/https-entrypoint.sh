#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly ACME_HOME=/opt/acme
readonly ACME_CONFIG=/root/.acme.sh
readonly RENEW_DAYS=3
readonly MIN_VALID_SECONDS=86400
readonly RELOAD_COMMAND=/usr/local/bin/reload-panel.sh
readonly CRON_SCHEDULE='17 */6 * * *'
readonly ACME_SKIP_STATUS=2

acme() {
    "$ACME_HOME/acme.sh" --home "$ACME_HOME" --config-home "$ACME_CONFIG" "$@"
}

validate_ip() {
    local octet
    local -a octets
    if [[ ! ${ACME_IP:-} =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        printf 'Set ACME_IP to the public IPv4 address of this VPS.\n' >&2
        return 1
    fi
    IFS=. read -r -a octets <<< "$ACME_IP"
    for octet in "${octets[@]}"; do
        if (( 10#$octet > 255 )) || [[ ${#octet} -gt 1 && $octet == 0* ]]; then
            printf 'Invalid IPv4 address: %s\n' "$ACME_IP" >&2
            return 1
        fi
    done
}

issue_certificate() {
    local status
    local -a account_options=()
    if [[ -n ${ACME_EMAIL:-} ]]; then
        account_options=(--accountemail "$ACME_EMAIL")
    fi
    acme --register-account --server letsencrypt "${account_options[@]}"
    if acme --issue --server letsencrypt -d "$ACME_IP" --standalone \
        --keylength ec-256 --certificate-profile shortlived --days "$RENEW_DAYS"; then
        return 0
    else
        status=$?
        # `acme.sh` returns 2 when an existing certificate is not due for renewal.
        if [[ $status -ne $ACME_SKIP_STATUS ]]; then
            printf 'Certificate issuance failed. Check inbound TCP port 80 and the ACME log above.\n' >&2
            return "$status"
        fi
    fi
}

prepare_certificate() {
    local cert_directory=$1
    mkdir -p "$ACME_CONFIG" "$cert_directory"
    if [[ ! -s $cert_directory/privkey.pem ]] || \
        ! openssl x509 -in "$cert_directory/fullchain.pem" \
            -checkend "$MIN_VALID_SECONDS" -noout >/dev/null 2>&1; then
        issue_certificate
    fi
    acme --install-cert -d "$ACME_IP" --ecc \
        --key-file "$cert_directory/privkey.pem" \
        --fullchain-file "$cert_directory/fullchain.pem" \
        --reloadcmd "$RELOAD_COMMAND"
    openssl x509 -in "$cert_directory/fullchain.pem" -checkend 0 -noout
    openssl x509 -in "$cert_directory/fullchain.pem" -checkip "$ACME_IP" -noout
}

configure_panel() {
    local cert_directory=$1 output
    output=$(/app/x-ui setting -webCert "$cert_directory/fullchain.pem" \
        -webCertKey "$cert_directory/privkey.pem" 2>&1)
    if [[ $output != *'set certificate public key success'* || \
        $output != *'set certificate private key success'* ]]; then
        printf 'Panel TLS configuration was not confirmed:\n%s\n' "$output" >&2
        return 1
    fi
}

start_renewal() {
    printf '%s %s/acme.sh --cron --home %s --config-home %s >> /proc/1/fd/1 2>> /proc/1/fd/2\n' \
        "$CRON_SCHEDULE" "$ACME_HOME" "$ACME_HOME" "$ACME_CONFIG" > /etc/crontabs/root
    crond -b -l 8 -L /proc/1/fd/1
}

main() {
    validate_ip
    local cert_directory="/root/cert/$ACME_IP"
    prepare_certificate "$cert_directory"
    configure_panel "$cert_directory"
    start_renewal
    printf 'HTTPS configured for %s. ACME renewal checks run every 6 hours.\n' "$ACME_IP"
    exec /app/DockerEntrypoint.sh
}

main
