# ============================================================================
# Update bundled letsencrypt certificate
# ============================================================================

{%- set minion_id = salt['grains.get']('id') %}
{%- set letsencrypt_dir = '/etc/letsencrypt/live/' ~ minion_id %}
{%- set certs_dir = salt['pillar.get']('ssl:certs_dir') %}

bundle_letsencrypt_cert.sh:
  file.managed:
    - name: /usr/local/bin/bundle_letsencrypt_cert.sh
    - template: jinja
    - mode: 755
    - contents: |
        #! /bin/sh

        cat {{ letsencrypt_dir }}/fullchain.pem \
            {{ letsencrypt_dir }}/privkey.pem | \
            diff --report-identical-files {{ certs_dir }}/{{ minion_id }}.pem - > /dev/null

        if [ $? -ne 0 ]; then
            cat {{ letsencrypt_dir }}/fullchain.pem \
                {{ letsencrypt_dir }}/privkey.pem >| \
                {{ certs_dir }}/{{ minion_id }}.pem

            cp {{ letsencrypt_dir }}/fullchain.pem {{ certs_dir }}/{{ minion_id }}.crt
            cp {{ letsencrypt_dir }}/privkey.pem {{ certs_dir }}/{{ minion_id }}.key

            chmod 644 {{ certs_dir }}/{{ minion_id }}.crt
            chmod 600 {{ certs_dir }}/{{ minion_id }}.key
            chmod 600 {{ certs_dir }}/{{ minion_id }}.pem

            echo 'Updated {{ certs_dir }}/{{ minion_id }}.pem'
            systemctl reload haproxy
        else
            echo 'Already up to date {{ certs_dir }}/{{ minion_id }}.pem'
        fi


bundle_letsencrypt_cert.sh on certbot changes:
  cmd.run:
    - name: /usr/local/bin/bundle_letsencrypt_cert.sh
    - unless: |
        cat {{ letsencrypt_dir }}/fullchain.pem \
            {{ letsencrypt_dir }}/privkey.pem | \
            diff --report-identical-files {{ certs_dir }}/{{ minion_id }}.pem - > /dev/null
    - require:
      - file: bundle_letsencrypt_cert.sh
    - watch:
      - certbot_{{ minion_id }}


reload haproxy on certbot changes:
  module.wait:
    - name: service.reload
    - m_name: haproxy
    - onchanges:
      - cmd: /usr/local/bin/bundle_letsencrypt_cert.sh


bundle_letsencrypt_cert.service:
  file.managed:
    - name: /lib/systemd/system/bundle_letsencrypt_cert.service
    - template: jinja
    - require:
      - file: bundle_letsencrypt_cert.sh
    - contents: |
        [Unit]
        Description=Bundles the cert & private key generated by certbot

        [Service]
        Type=oneshot
        ExecStart=/usr/local/bin/bundle_letsencrypt_cert.sh
        PrivateTmp=true

  module.watch:
    - name: service.available
    - m_name: bundle_letsencrypt_cert.service
    - require:
      - file: bundle_letsencrypt_cert.service
    - watch:
      - file: bundle_letsencrypt_cert.service


bundle_letsencrypt_cert.timer:
  file.managed:
    - name: /lib/systemd/system/bundle_letsencrypt_cert.timer
    - template: jinja
    - require:
      - file: bundle_letsencrypt_cert.service
    - watch_in:
      - service: bundle_letsencrypt_cert.timer
    - contents: |
        [Unit]
        Description=Daily timer to bundle the cert & private key generated by certbot

        [Timer]
        OnCalendar=*-*-* 02:00:00
        Persistent=true

        [Install]
        WantedBy=timers.target

  service.running:
    - name: bundle_letsencrypt_cert.timer
    - enable: true
