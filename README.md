# K3s Cluster Safe Shutdown and Startup

Production-ready Ansible playbook to safely shut down and start up a multi-node K3s cluster.
It uses Kubernetes API primitives for cordon and drain, preserves etcd quorum, and restarts nodes in a safe order.

## Features

- Worker-first shutdown to evacuate workloads
- Optional etcd snapshots before control-plane shutdown
- Ordered control-plane shutdown and serial start to preserve quorum
- Clean startup with API readiness checks
- Simple, explicit confirmation guard to reduce accidents
- Kubernetes operations executed from the control machine using your kubeconfig

## Requirements

- Ansible Core 2.19 or newer
- Python 3.10+ on the control machine
- uv (Python package manager, see [docs](https://docs.astral.sh/uv/))
- Collections (installed automatically via the setup script):
  - `kubernetes.core`
  - `community.general`
- A working kubeconfig on the control machine with permissions to cordon and drain nodes
- SSH access to all nodes with privilege escalation available

## Inventory

Copy `inventory/hosts.example.yml` to `inventory/hosts.yml` and edit the hosts and variables.
See `group_vars/all.yml` for defaults you can override in inventory or at run time.

## Quick start

```bash
# 1) Set up environment and install dependencies
./install-collections.sh

# 2) Create your inventory
cp inventory/hosts.example.yml inventory/hosts.yml
$EDITOR inventory/hosts.yml

# 3) Shutdown (requires explicit confirmation)
ansible-playbook playbooks/k3s_cluster_control.yml -t shutdown -e confirm=true

# 4) Startup
ansible-playbook playbooks/k3s_cluster_control.yml -t startup -e confirm=true
```

Or use the helper script:

```bash
./scripts/cluster-control.sh shutdown   # or startup
```

## Variables

- `kubeconfig`: Path to kubeconfig on the control machine, default `~/.kube/config`
- `longhorn_namespace`: Namespace for Longhorn if present, default `longhorn-system`
- `critical_namespaces`: Namespaces not to evict from, default `["kube-system", "longhorn-system", "metallb-system"]` (note: namespace-based exclusion is not currently implemented in the drain operation)
- `drain_timeout`: Timeout for draining a node in seconds, default `600`
- `shutdown_grace_period`: Pause between serial control-plane operations in seconds, default `30`
- `etcd_snapshot`: Whether to take an etcd snapshot before shutdown, default `true`
- `etcd_snapshot_retention`: Number of snapshots to keep if you implement rotation, default `5`
- `confirm`: Safety switch. Must be true to run shutdown or startup tasks.

## Notes

- The playbook uses fully qualified collection names for compatibility with modern Ansible.
- Kubernetes tasks run on the control machine (`delegate_to: localhost`) and use `K8S_AUTH_KUBECONFIG` to locate your kubeconfig.
- For K3s with embedded etcd, snapshots are taken with `k3s etcd-snapshot save` on the first master. Adjust if you use an external datastore.
- Longhorn specific safety checks are not enforced by default; ensure your storage workloads are healthy and replicated before shutdown.
- Test thoroughly in a non-production environment before using in production.
