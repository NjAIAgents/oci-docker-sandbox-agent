# Post 6 — Observability, Grafana, and Kill Switches

> **Coming in Post 6** of the series: *Running Autonomous Agents on OCI Free Tier* by Nj

This post is not live yet. Star or watch the repo and `git pull` when Post 6 is published.

---

## What Post 6 covers

You cannot operate a multi-agent system you cannot see. Post 6 adds the observability layer:

- Installing Prometheus and the Node Exporter on the VM
- Wiring container metrics (CPU, memory, network) from Docker into Prometheus
- Deploying Grafana and building a dashboard for the agent sandbox
- Adding agent-specific metrics: task throughput, tool invocation counts, error rates
- Implementing kill switches: single commands that stop individual agents or the entire system
- Setting up alerting thresholds that page you before a runaway agent saturates the VM

By the end of Post 6 you have a production-grade observability stack on $0/month infrastructure.

---

## Prerequisites for Post 6

- Posts 1-5 complete: full multi-agent system running
- Uncomment `GRAFANA_ADMIN_PASSWORD` in your `.env` file

---

## Quick start (when live)

```bash
git pull
make observe
# then follow the steps in this README
```

---

## Coming soon

[Post 6 on Medium](#) <!-- placeholder -->
