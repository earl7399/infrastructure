ssh:
  permit_root_login: True


ufw:
  services:
    http:
      protocol: tcp
      comment: Public HTTP

    https:
      protocol: tcp
      comment: Public HTTPS

    8000:
      protocol: tcp
      comment: Alternate HTTP
