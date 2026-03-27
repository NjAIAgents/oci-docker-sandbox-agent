# Post 2 — Hardening Your OCI VM Before Touching It

> **Coming in Post 2** of the series: *Running Autonomous Agents on OCI Free Tier* by Nj

This post is not live yet. Star or watch the repo and `git pull` when Post 2 is published.

---

## What Post 2 covers

A freshly provisioned Ubuntu VM on a public IP is exposed the moment it boots. Before installing anything else, you need a baseline security posture. Post 2 walks through:

- Updating the OS and enabling unattended security upgrades
- Configuring `ufw` with a minimal allow-list (SSH only to start)
- Installing and tuning `fail2ban` to block SSH brute-force attempts
- Adding swap space (the Always Free ARM VM has no swap by default)
- Disabling root login and password authentication over SSH
- Creating a non-root user for all future operations

These steps take about 15 minutes. None of them are optional before Post 3.

---

## Prerequisites for Post 2

- Post 1 complete: VM is provisioned, `VM_PUBLIC_IP` is set in `.env`, `make ssh` works
- Uncomment `VM_USER=ubuntu` in your `.env` file

---

## Quick start (when live)

```bash
git pull
make harden
# then follow the steps in this README
```

---

## Coming soon

[Post 2 on Medium](#) <!-- placeholder -->
