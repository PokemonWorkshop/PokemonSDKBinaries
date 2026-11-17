
# OpenSSL is bundled, but trusted certificate authorities belong to the host.
if [[ -z "${SSL_CERT_FILE+x}" ]]; then
  for psdk_ca_bundle in /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/cert.pem; do
    if [[ -r "$psdk_ca_bundle" ]]; then
      export SSL_CERT_FILE="$psdk_ca_bundle"
      break
    fi
  done
  unset psdk_ca_bundle
fi
