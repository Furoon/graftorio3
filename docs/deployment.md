# Deploying graftorio3

graftorio3 writes a Prometheus exposition file. Anything that can read a file
can scrape it -- the recommended path is the node_exporter textfile collector,
because most servers already run node_exporter.

## node_exporter textfile collector

The mod writes to `<factorio-data>/script-output/graftorio3/game.prom`. Point
node_exporter at that directory:

```
--collector.textfile.directory=/opt/factorio/script-output/graftorio3
```

Metrics then appear as `factorio_*` on the node_exporter target you already
scrape. No extra scrape job, no sidecar container, no open port.

The node_exporter process needs read access to the directory. If Factorio and
node_exporter run as different users, a shared group is the simplest fix:

```sh
chgrp -R node-exp /opt/factorio/script-output/graftorio3
chmod -R g+rX /opt/factorio/script-output/graftorio3
```

## Containers

When Factorio runs in a container, bind-mount the output directory to a path
node_exporter can read on the host:

```yaml
services:
  factorio:
    volumes:
      - ./factorio-data/script-output/graftorio3:/factorio/script-output/graftorio3
```

## Several servers on one host

Two instances writing `game.prom` into the same textfile directory overwrite
each other. Give each instance its own file name and its own instance label:

| Setting | Server A | Server B |
| --- | --- | --- |
| `graftorio3-output-filename` | `alpha.prom` | `beta.prom` |
| `graftorio3-instance-label` | `alpha` | `beta` |

Every series then carries `instance="alpha"` / `instance="beta"` and the two
files coexist in one directory.

## Ansible

Minimal role fragment, assuming node_exporter is already managed elsewhere:

```yaml
- name: Ensure the metrics directory is readable by node_exporter
  ansible.builtin.file:
    path: "{{ factorio_root }}/script-output/graftorio3"
    state: directory
    owner: factorio
    group: node-exp
    mode: "0750"

- name: Point node_exporter at the textfile directory
  ansible.builtin.lineinfile:
    path: /etc/default/node_exporter
    regexp: '^OPTIONS='
    line: 'OPTIONS="--collector.textfile.directory={{ factorio_root }}/script-output/graftorio3"'
  notify: restart node_exporter
```

## Checking it works

In the server console or via RCON:

```
/graftorio3
```

This reports the mod version, the tick of the last collection, the output
path, the collection interval, which surfaces are collected, the active
settings, and any per-module collector errors. If it reports a recent
collection but Prometheus shows nothing, the problem is between the file and
the scrape, not in the mod.

In Prometheus:

```promql
count({__name__=~"factorio_.*"})
```
