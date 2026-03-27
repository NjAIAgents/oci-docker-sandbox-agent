# oci-docker-sandbox-agent

**Running Autonomous Agents on OCI Free Tier** — a 6-post Medium series by Nj

Clone once. `make provision`. `git pull` after each new post to unlock the next layer.

---

## Series

| Post | Directory | Topic | Status |
|------|-----------|-------|--------|
| 1 | [`01-provision/`](01-provision/) | Claim OCI Always Free ARM VM via Terraform | [Live — read on Medium](#post-1-claiming-your-free-oci-arm-vm) |
| 2 | [`02-harden/`](02-harden/) | OS hardening, firewall, fail2ban, swap | Coming soon |
| 3 | [`03-docker-sandbox/`](03-docker-sandbox/) | Docker install, container isolation, seccomp | Coming soon |
| 4 | [`04-agent/`](04-agent/) | Deploy OpenClaw agent in Docker sandbox | Coming soon |
| 5 | [`05-multi-agent/`](05-multi-agent/) | Multi-agent system, message bus, blast radius | Coming soon |
| 6 | [`06-observability/`](06-observability/) | Prometheus, Grafana, kill switches | Coming soon |

---

## What this series builds

By the end of Post 6 you will have a production-grade multi-agent sandbox running on free OCI infrastructure. The end state: multiple agents collaborating inside isolated Docker containers, each with a defined blast radius, observed by Prometheus and Grafana, with kill switches you can hit from a single command. Total cost: $0/month.

Post 1 gets you the machine. Every post after that adds exactly one layer.

---

## Prerequisites

You need these installed and configured before starting:

| Tool | Required by | Install |
|------|-------------|---------|
| `terraform` | Post 1 | [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install) |
| `oci` CLI | Post 1 | [docs.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm](https://docs.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm) |
| `jq` | Post 1 | `brew install jq` / `apt install jq` |
| `docker` | Post 3 | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |

You also need an OCI account with the Always Free tier available and `~/.oci/config` configured with API key auth. Run `oci setup config` if you have not done this yet.

---

## Quick start

```bash
# Clone once — you will git pull for each new post
git clone https://github.com/<username>/oci-docker-sandbox-agent
cd oci-docker-sandbox-agent

# Post 1: provision your ARM VM
make provision

# After provision.sh succeeds, copy .env.example and fill in VM_PUBLIC_IP
cp .env.example .env
# edit .env: set VM_PUBLIC_IP to the IP from terraform output

# SSH into your VM from anywhere in the repo
make ssh

# Each new post: pull and follow the new directory's README
git pull
# then: make harden / make docker / make agent / etc.
```

---

## Repo philosophy — additive only

Each post adds a new numbered directory. Nothing from a previous post is ever modified. If you completed Post 1 and then `git pull` after Post 2 is published, your existing `01-provision/` files are untouched. You get a new `02-harden/` directory and an updated `Makefile` that adds the `harden` target.

This means you can follow the series at your own pace without anything breaking under you.

---

## Article links

### Post 1: Claiming Your Free OCI ARM VM — The Right Way
> *Available now*
> [Read on Medium](#) <!-- TODO: replace with live URL -->

### Post 2: Hardening Your OCI VM Before Touching It
> *Coming soon*

### Post 3: Docker Isolation — Building the Sandbox
> *Coming soon*

### Post 4: Deploying Your First Agent in the Sandbox
> *Coming soon*

### Post 5: Multi-Agent Systems and Blast Radius Containment
> *Coming soon*

### Post 6: Observability, Grafana, and Kill Switches
> *Coming soon*

---

## Author

**Nj** — [Medium](https://medium.com/@navjyotnishant)
