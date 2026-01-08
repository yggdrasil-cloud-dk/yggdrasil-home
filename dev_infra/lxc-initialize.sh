snap install lxd --channel=latest/stable

cat <<EOF | lxd init --preseed
config: {}
networks:
- config:
    ipv4.address: 10.227.41.1/24
    ipv6.address: none
  description: ""
  name: lxdbr0
  type: ""
  project: default
storage_pools:
- config:
    size: 120GiB
  description: ""
  name: default
  driver: zfs
storage_volumes: []
profiles:
- config: {}
  description: ""
  devices:
    eth0:
      name: eth0
      network: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
projects: []
cluster: null
EOF

