# Post 3 — Docker Isolation: Building the Sandbox

> **Coming in Post 3** of the series: *Running Autonomous Agents on OCI Free Tier* by Nj

This post is not live yet. Star or watch the repo and `git pull` when Post 3 is published.

---

## What Post 3 covers

The entire point of this series is that agents run inside containers, not on the host. Post 3 builds the sandbox layer:

- Installing Docker on Ubuntu ARM (the non-obvious steps for aarch64)
- Configuring the Docker daemon with resource caps and logging limits
- Writing a `seccomp` profile that restricts the syscall surface available to containers
- Building a base container image with only the tools the agent needs
- Testing isolation: confirming read-only mounts, `--network none`, and no write path to the host
- Understanding what container escape looks like and why it matters for your threat model

The sandbox built in Post 3 is what Posts 4-6 deploy agents into.

---

## Prerequisites for Post 3

- Posts 1 and 2 complete: VM is provisioned and hardened
- SSH access working via `make ssh`

---

## Quick start (when live)

```bash
git pull
make docker
# then follow the steps in this README
```

---

## Coming soon

[Post 3 on Medium](#) <!-- placeholder -->
