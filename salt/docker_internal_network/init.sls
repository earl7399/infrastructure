docker_internal_network:
  docker_network.present:
    - internal: True
    - require:
      - sls: docker
