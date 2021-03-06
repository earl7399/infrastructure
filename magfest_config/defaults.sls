{%- import_yaml 'ip_blacklist.yaml' as ip_blacklist %}
{%- set master_ip = salt['network.interface_ip']('eth1') -%}
{%- set private_ip = salt['grains.get']('ip4_interfaces')[salt['grains.get']('private_interface', 'eth1')][0] %}
{%- set salt_env = salt['grains.get']('env') %}
{%- set host_prefix = '' if not salt_env or salt_env == 'prod' else salt_env ~ '-' %}
{%- set master_domain = 'magfest.info' if salt['grains.get']('is_vagrant') else 'magfest.net' %}

ip_blacklist: {{ ip_blacklist.ip_blacklist }}

master:
  domain: {{ master_domain }}
  address: {{ master_ip }}
  host_prefix: '{{ host_prefix }}'


minion:
  master: {{ master_ip }}

  log_file: file:///dev/log
  log_level: info

  use_superseded:
    - module.run


mine_functions:
  public_ip:
    - mine_function: network.interface_ip
    - eth0
  private_ip:
    - mine_function: network.interface_ip
    - {{ salt['grains.get']('private_interface', 'eth1') }}


ssh:
  password_authentication: True
  permit_root_login: False


ufw:
  enabled: True

  settings:
    ipv6: False

  sysctl:
    ipv6_autoconf: 0

  applications:
    OpenSSH:
      limit: True
      to_addr: {{ private_ip }}
      comment: Private network SSH
