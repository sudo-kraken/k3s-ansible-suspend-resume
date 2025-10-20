<div align="center">
<img src="docs/assets/logo.png" align="center" width="144px" height="144px"/>

### K3s Cluster Safe Shutdown and Startup

_A production-ready Ansible playbook that safely suspends and resumes a multi-node K3s cluster. It uses Kubernetes API primitives to cordon and drain, preserves etcd quorum, and restarts nodes in a safe order._
</div>

<div align="center">

[![Ansible](https://img.shields.io/badge/Ansible-Required-red.svg?style=for-the-badge)](https://ansible.com) [![Ansible Version](https://img.shields.io/badge/Ansible-2.19%2B-blue?logo=ansible&style=for-the-badge)](https://docs.ansible.com/)

</div>

<div align="center">

[![OpenSSF Scorecard](https://img.shields.io/ossf-scorecard/github.com/sudo-kraken/k3s-ansible-suspend-resume?label=openssf%20scorecard&style=for-the-badge)](https://scorecard.dev/viewer/?uri=github.com/sudo-kraken/k3s-ansible-suspend-resume)

</div>

## Contents

- [Overview](#overview)
- [Architecture at a glance](#architecture-at-a-glance)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Configuration](#configuration)
  - [Role variables](#role-variables)
  - [Inventory structure](#inventory-structure)
  - [Repository contents](#repository-contents)
  - [Tag reference](#tag-reference)
- [Health](#health)
- [Endpoint](#endpoint)
- [Production notes](#production-notes)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Licence](#licence)
- [Security](#security)
- [Contributing](#contributing)
- [Support](#support)
- [Disclaimer](#disclaimer)

## Overview

Safely stop and start a K3s cluster without risking control plane quorum or leaving workloads stranded. The playbook performs ordered shutdown and clean startup using Kubernetes-aware operations from the control machine.

## Architecture at a glance

- Worker-first cordon and drain to evacuate workloads
- Optional etcd snapshot prior to control plane shutdown
- Ordered control plane stop and serial start to preserve quorum
- Clean startup with API readiness checks
- Safety confirmation switch to avoid accidental execution
- Kubernetes actions run from the control machine using your kubeconfig

## Features

- Worker-first shutdown to drain workloads
- Optional etcd snapshots before control plane shutdown
- Ordered control plane shutdown and serial start to maintain quorum
- Clean startup with Kubernetes API readiness checks
- Explicit confirmation guard to reduce accidents
- Uses `delegate_to: localhost` with your kubeconfig for Kubernetes operations

## Prerequisites

- Ansible Core 2.19 or newer on the control machine
- Python 3.10 or newer on the control machine
- `uv` recommended for Python dependency management
- Collections: `kubernetes.core` and `community.general`
- A working kubeconfig on the control machine with permissions to cordon and drain nodes
- SSH access to all nodes with privilege escalation available

## Quick start

```bash
# 1) Set up environment and install Ansible collections
./install-collections.sh

# 2) Create your inventory
cp inventory/hosts.example.yml inventory/hosts.yml
$EDITOR inventory/hosts.yml

# 3) Suspend the cluster (requires explicit confirmation)
ansible-playbook playbooks/k3s_cluster_control.yml -t shutdown -e confirm=true

# 4) Resume the cluster
ansible-playbook playbooks/k3s_cluster_control.yml -t startup -e confirm=true

# Optional helper script
./scripts/cluster-control.sh shutdown   # or: ./scripts/cluster-control.sh startup
```

## Configuration

### Role variables

Configure behaviour via inventory or `-e` overrides.

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `kubeconfig` | no | `~/.kube/config` | Path to kubeconfig on the control machine used for Kubernetes API calls |
| `longhorn_namespace` | no | `longhorn-system` | Namespace for Longhorn if present |
| `critical_namespaces` | no | `["kube-system", "longhorn-system", "metallb-system"]` | Namespaces considered critical. Note: namespace-based exclusion is not currently enforced during drain |
| `drain_timeout` | no | `600` | Timeout for draining a node in seconds |
| `shutdown_grace_period` | no | `30` | Pause between serial control plane operations in seconds |
| `etcd_snapshot` | no | `true` | Take an etcd snapshot before control plane shutdown |
| `etcd_snapshot_retention` | no | `5` | Number of snapshots to keep if you implement rotation |
| `confirm` | yes for shutdown/startup | `false` | Safety switch. Must be set to `true` to run shutdown or startup tasks |

### Inventory structure

Define your cluster in `inventory/hosts.yml`. Minimal example:

```yaml
all:
  children:
    k3s_masters:
      hosts:
        master-01:
          ansible_host: 10.0.0.10
        master-02:
          ansible_host: 10.0.0.11
        master-03:
          ansible_host: 10.0.0.12
    k3s_workers:
      hosts:
        worker-01:
          ansible_host: 10.0.0.20
        worker-02:
          ansible_host: 10.0.0.21
```

### Repository contents

| Path | Description |
|------|-------------|
| `playbooks/k3s_cluster_control.yml` | Entrypoint playbook with suspend and resume tasks |
| `inventory/hosts.example.yml` | Example inventory to copy and edit |
| `group_vars/all.yml` | Defaults that can be overridden in inventory or at run time |
| `scripts/cluster-control.sh` | Convenience wrapper for shutdown and startup |
| `install-collections.sh` | Helper to install required Ansible collections |
| `requirements.yml` | Collection requirements for `ansible-galaxy` |
| `ansible.cfg` | Project-local Ansible configuration |
| `pyproject.toml`, `uv.lock` | Python tooling and lock file for `uv` |

### Tag reference

| Tag | Description | Use case |
|-----|-------------|----------|
| `shutdown` | Stop workloads safely then shut down control plane in order | Planned maintenance or power down |
| `startup` | Start control plane serially then restore workers | Safe cluster bring-up after downtime |

## Health

- API readiness checks during startup to confirm the control plane is available
- Draining uses Kubernetes eviction and waits within `drain_timeout` to reduce disruption
- Optional etcd snapshot prior to shutdown for additional safety

## Endpoint

This project is an Ansible automation, not a network service.

- Primary entry point: `playbooks/k3s_cluster_control.yml`
- Invoke with `ansible-playbook -t <shutdown|startup> -e confirm=true` and the inventory suited to your environment

## Production notes

- Always take backups. The optional etcd snapshot can be enabled to add a safety net
- Keep `confirm=true` explicit in automation to avoid accidental runs
- Ensure your kubeconfig context targets the correct cluster before executing
- Validate Longhorn or other storage workloads are healthy and replicated before shutdown
- Test thoroughly in a non-production environment first

## Development

```bash
# Clone
git clone https://github.com/sudo-kraken/k3s-ansible-suspend-resume.git
cd k3s-ansible-suspend-resume

# Install Ansible collections
./install-collections.sh
# or:
ansible-galaxy collection install -r requirements.yml

# Prepare inventory
cp inventory/hosts.example.yml inventory/hosts.yml
$EDITOR inventory/hosts.yml

# Run a dry read of variables
ansible-inventory -i inventory/hosts.yml --graph
```

## Troubleshooting

- Verify cluster state
  ```bash
  kubectl get nodes
  kubectl get pods --all-namespaces
  ```

- Draining appears slow
  ```bash
  # Consider increasing drain_timeout or quiescing noisy workloads
  ```

- Startup checks fail
  ```bash
  # Confirm control plane nodes are powered on and reachable
  # Verify kubeconfig context and credentials
  ```

- Longhorn workloads
  ```bash
  kubectl get pods -n longhorn-system
  # Ensure volumes are healthy prior to shutdown
  ```

## Licence

This project is licensed under the MIT Licence. See the [LICENCE](LICENCE) file for details.

## Security

If you discover a security issue, please review and follow the guidance in [SECURITY.md](SECURITY.md) if present, or open a private security-focused issue with minimal details and request a secure contact channel.

## Contributing

Feel free to open issues or submit pull requests if you have suggestions or improvements.
See [CONTRIBUTING.md](CONTRIBUTING.md)

## Support

Open an [issue](/../../issues) with as much detail as possible, including your Ansible version, distribution details and relevant playbook output.

## Disclaimer

This tool performs maintenance operations on your Kubernetes cluster. Always:
- Test in a non-production environment first
- Ensure you have recent backups
- Review the role tasks before deployment
- Monitor the process during execution

Use at your own risk. I am not responsible for any damage or data loss.
