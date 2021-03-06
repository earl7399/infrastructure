# ============================================================================
# Installs the FreeIPA client and configures SSH authentication
# ============================================================================

{%- set password_auth = salt['pillar.get']('ssh:password_authentication') -%}
{%- set root_login = salt['pillar.get']('ssh:permit_root_login') -%}

# All of our servers are intially provisioned with /root/.ssh/authorized_keys
# that are installed on MCP, so we can immediately disable password auth.
freeipa client sshd disable password authentication:
  file.replace:
    - name: /etc/ssh/sshd_config
    - pattern: ^\s*PasswordAuthentication\s+{{ 'no' if password_auth else 'yes' }}\s*$
    - repl: PasswordAuthentication {{ 'yes' if password_auth else 'no' }}
    - append_if_not_found: True
    - listen_in:
      - service: sshd

# Make sure that users home directories are created on initial login.
freeipa client sshd create home directory on initial login:
  file.line:
    - name: /etc/pam.d/sshd
    - content: session required pam_mkhomedir.so skel=/etc/skel/ umask=0022
    - after: session\s+.+?\s+pam_selinux\.so\s+close
    - mode: ensure

{% if salt['pillar.get']('freeipa:client:enabled') %}
# Install the FreeIPA client package. The ipa client isn't actually installed
# until the ipa-client-install script is run.
freeipa client install:
  pkg.installed:
    - name: freeipa-client

  cmd.run:
    - name: >
        ipa-client-install
        --domain={{ salt['pillar.get']('freeipa:client:domain', salt['pillar.get']('freeipa:client:realm'))|lower }}
        --realm={{ salt['pillar.get']('freeipa:client:realm')|upper }}
        --principal={{ salt['pillar.get']('freeipa:client:principal') }}
        --hostname={{ 'mcp.' ~ salt['pillar.get']('master:domain') if salt['grains.get']('fqdn') == 'mcp' else salt['grains.get']('fqdn') }}
        --password=$IPA_CLIENT_INSTALL_PASSWORD
        --mkhomedir
        --no-ntp
        --force-join
        --unattended
    - env:
        - IPA_CLIENT_INSTALL_PASSWORD: {{ salt['pillar.get']('freeipa:client:principal_password') }}
    - output_loglevel: quiet
    - creates: /etc/ipa/default.conf
    - require:
      - pkg: freeipa-client
    - require_in:
      - freeipa client sshd disable root login
{% endif %}

# Disables root login. We must wait until after the ipa client is installed,
# otherwise we'll end up locking ourselves out of a newly provisioned server.
freeipa client sshd disable root login:
  file.replace:
    - name: /etc/ssh/sshd_config
    - pattern: ^\s*PermitRootLogin\s+{{ 'no' if root_login else 'yes' }}\s*$
    - repl: PermitRootLogin {{ 'yes' if root_login else 'no' }}
    - append_if_not_found: True
    - listen_in:
      - service: sshd
