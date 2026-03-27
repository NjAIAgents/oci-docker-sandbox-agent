# Post 4 — Deploying Your First Agent in the Sandbox

> **Coming in Post 4** of the series: *Running Autonomous Agents on OCI Free Tier* by Nj

This post is not live yet. Star or watch the repo and `git pull` when Post 4 is published.

---

## What Post 4 covers

With a hardened VM and a tested Docker sandbox, Post 4 deploys the first agent. This is where the series shifts from infrastructure to application:

- Deploying OpenClaw inside the Docker sandbox from Post 3
- Wiring the agent to Ollama running on the host (accessible via `host.docker.internal`)
- Configuring the agent's tool set and restricting what it can reach
- Validating that the isolation properties from Post 3 hold with an agent inside
- Running a first task end to end: agent receives input, uses tools, produces output

The single-agent setup in Post 4 is the foundation for the multi-agent system in Post 5.

---

## Prerequisites for Post 4

- Posts 1-3 complete: VM provisioned, hardened, Docker sandbox built
- Uncomment `AGENT_API_KEY` and `AGENT_MODEL` in your `.env` file

---

## Quick start (when live)

```bash
git pull
make agent
# then follow the steps in this README
```

---

## Coming soon

[Post 4 on Medium](#) <!-- placeholder -->
