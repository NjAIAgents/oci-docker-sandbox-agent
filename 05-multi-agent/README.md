# Post 5 — Multi-Agent Systems and Blast Radius Containment

> **Coming in Post 5** of the series: *Running Autonomous Agents on OCI Free Tier* by Nj

This post is not live yet. Star or watch the repo and `git pull` when Post 5 is published.

---

## What Post 5 covers

A single agent is a proof of concept. Multiple agents collaborating with bounded blast radius is a system. Post 5 builds that system:

- Designing a message bus that lets agents communicate without direct access to each other
- Assigning each agent a specific role and a restricted tool set
- Defining blast radius: what each agent can and cannot do if compromised or misbehaving
- Running multiple agents concurrently inside isolated containers on the same VM
- Testing cross-agent coordination on a realistic task
- Understanding where the single-VM model breaks down and when you need to distribute

The architecture introduced in Post 5 is what Post 6 adds observability to.

---

## Prerequisites for Post 5

- Posts 1-4 complete: VM provisioned, hardened, Docker sandbox built, single agent running

---

## Quick start (when live)

```bash
git pull
make multi-agent
# then follow the steps in this README
```

---

## Coming soon

[Post 5 on Medium](#) <!-- placeholder -->
