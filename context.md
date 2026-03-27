# oci-docker-sandbox-agent - Build Context (Post 1 of 6)

## Repo name

`oci-docker-sandbox-agent`

This is a multi-post Medium series repo. Each post adds a new numbered
directory. Users clone once and `git pull` after each article to get the
next layer. Nothing from a previous post is modified - only additive.

-----

## Series overview

|Post    |Directory           |Topic                                        |
|--------|--------------------|---------------------------------------------|
|1 (this)|`01-provision/`     |Claim OCI Always Free ARM VM via Terraform   |
|2       |`02-harden/`        |OS hardening, firewall, fail2ban, swap       |
|3       |`03-docker-sandbox/`|Docker install, container isolation, seccomp |
|4       |`04-agent/`         |Deploy OpenClaw agent in Docker sandbox      |
|5       |`05-multi-agent/`   |Multi-agent system, message bus, blast radius|
|6       |`06-observability/` |Prometheus, Grafana, kill switches           |

-----

## Full repo structure (all 6 posts, build Post 1 now, scaffold rest as empty)

```
oci-docker-sandbox-agent/
│
│  # Root - shared across all posts
├── README.md                       # series index, per-post status, quick start
├── Makefile                        # unified interface, targets grow with each post
├── .env.example                    # master env file, grows with each post
├── scripts/
│   └── ssh-to-vm.sh                # populated after post 1 with VM IP
│
│  # POST 1 - Claim the VM (build this now)
├── 01-provision/
│   ├── setup.sh                    # interactive CLI setup - main deliverable
│   ├── templates/
│   │   ├── provision.sh.tpl        # AD rotation retry loop
│   │   ├── main.tf.tpl             # full OCI Terraform scaffold
│   │   ├── variable.tf.tpl         # variable declarations
│   │   └── terraform.tfvars.tpl    # variable values
│   └── README.md                   # post 1 specific instructions
│
│  # POST 2 - Harden (scaffold only, content in future post)
├── 02-harden/
│   └── README.md                   # "Coming in Post 2" placeholder
│
│  # POST 3 - Docker sandbox (scaffold only)
├── 03-docker-sandbox/
│   └── README.md                   # "Coming in Post 3" placeholder
│
│  # POST 4 - Agent (scaffold only)
├── 04-agent/
│   └── README.md                   # "Coming in Post 4" placeholder
│
│  # POST 5 - Multi-agent (scaffold only)
├── 05-multi-agent/
│   └── README.md                   # "Coming in Post 5" placeholder
│
│  # POST 6 - Observability (scaffold only)
└── 06-observability/
    └── README.md                   # "Coming in Post 6" placeholder
```

-----

## Makefile

Targets grow with each post. Build all targets now but only Post 1 target
is functional. Others print a "coming soon" message pointing to the article.

```makefile
.PHONY: provision harden docker agent multi-agent observe

# Post 1 - available now
provision:
	cd 01-provision && bash setup.sh

# Post 2 - coming soon
harden:
	@echo "Covered in Post 2. Pull the latest and follow 02-harden/README.md"

# Post 3 - coming soon
docker:
	@echo "Covered in Post 3. Pull the latest and follow 03-docker-sandbox/README.md"

# Post 4 - coming soon
agent:
	@echo "Covered in Post 4. Pull the latest and follow 04-agent/README.md"

# Post 5 - coming soon
multi-agent:
	@echo "Covered in Post 5. Pull the latest and follow 05-multi-agent/README.md"

# Post 6 - coming soon
observe:
	@echo "Covered in Post 6. Pull the latest and follow 06-observability/README.md"

# SSH helper - works after Post 1
ssh:
	bash scripts/ssh-to-vm.sh
```

-----

## .env.example

Grows with each post. Post 1 adds VM-related values only.
Document clearly which post introduces each variable.

```bash
# ---- Post 1: OCI Provisioning ----
OCI_REGION=us-chicago-1
OCI_TENANCY_OCID=
OCI_COMPARTMENT_OCID=
VM_PUBLIC_IP=                   # fill in after provision.sh succeeds
VM_SSH_KEY=~/.ssh/id_rsa

# ---- Post 2: VM Hardening ---- (uncomment when you reach Post 2)
# VM_USER=ubuntu

# ---- Post 4: Agent ---- (uncomment when you reach Post 4)
# AGENT_API_KEY=
# AGENT_MODEL=

# ---- Post 6: Observability ---- (uncomment when you reach Post 6)
# GRAFANA_ADMIN_PASSWORD=
```

-----

## Root README.md

Should cover:

- Series title and one-line description
- The full series table (post number, topic, status: live/coming soon)
- Prerequisites for the full series (OCI account, terraform, oci cli, jq, docker)
- Quick start: clone once, make provision, git pull for each new post
- Repo philosophy: additive only, nothing breaks between posts
- Links to each Medium article (placeholders for future posts)
- Author: Nj

-----

## How Post 1 works end to end

1. User clones `oci-docker-sandbox-agent` locally
1. User runs `make provision` from repo root (calls `cd 01-provision && bash setup.sh`)
1. `setup.sh` runs preflight checks, verifies OCI CLI connectivity, prompts
   for config values (with smart defaults auto-detected from ~/.oci/config),
   fetches availability domains directly from OCI API, then renders all
   templates into the user's Terraform directory (inside 01-provision/)
1. User runs `terraform init` then `bash provision.sh` from 01-provision/
1. `provision.sh` rotates across all 3 ADs in the region, retrying until
   capacity opens up
1. On success user fills VM_PUBLIC_IP in their .env file copied from .env.example
1. `make ssh` works from repo root from this point forward

-----

## setup.sh responsibilities

### Preflight checks

- terraform installed
- oci cli installed
- jq installed
- ~/.oci/config exists and has tenancy/region populated
- OCI API connectivity verified (live API call to oci iam tenancy get)
- SSH public key file exists at the specified path

### Auto-detection from ~/.oci/config

- tenancy OCID
- region
- These should be pre-filled as defaults so user just hits enter if correct

### Live OCI API calls during setup

- Fetch all availability domains for the region automatically using:
  `oci iam availability-domain list --compartment-id <tenancy_ocid>`
- User should never have to manually look up or type AD names

### Interactive prompts (with defaults shown)

- Target directory: path to existing Terraform project, or blank to scaffold new
- Region: auto-detected from config, user can override
- Compartment OCID: defaults to tenancy root OCID
- OCPUs: 1-4, default 4
- Memory GB: 6/12/18/24, default 24
- SSH public key path: default ~/.ssh/id_rsa.pub
- Seconds between AD attempts: default 60
- Minutes between full rounds: default 5 (enforce minimum 5)
- Instance display name: default free-arm-01

### File generation logic

- Always generate: provision.sh, terraform.tfvars
- Only generate main.tf and variable.tf if target directory has no existing main.tf
  (i.e. new project scaffold). If main.tf already exists, print a patch notice
  telling the user which variable blocks to add manually.
- Template rendering via sed substitution with {{PLACEHOLDER}} tokens

### Post-generation output

- Print the exact next-step commands for the user to run
- Print directory tree of what was generated
- Remind user to run terraform init if new project

-----

## provision.sh.tpl responsibilities

This is the retry loop script. Key behaviors:

### Error classification

Capture terraform apply stdout+stderr, classify into:

- `capacity` - "Out of host capacity" / "InsufficientServiceCapacity" -> rotate AD
- `limit` - "LimitExceeded" / "service limit" -> FATAL exit 2 (already at quota)
- `auth` - "NotAuthenticated" / 401 -> FATAL exit 3
- `forbidden` - "Forbidden" / 403 / "NotAuthorized" -> FATAL exit 4
- `invalid` - "InvalidParameter" / 400 / bad subnet or image OCID -> FATAL exit 5
- `ratelimit` - "TooManyRequests" / 429 -> backoff 2x round sleep, retry same AD once
- `internal` - "InternalError" / 5xx -> wait 120s, retry same AD once
- `unknown` - treat as transient, rotate AD

### Fatal exits stop the loop immediately with a clear message and remediation hint

### Retry behavior

- Between AD attempts: sleep AD_SLEEP seconds
- After all 3 ADs exhausted: sleep ROUND_SLEEP seconds
- On 429: sleep RATE_LIMIT_SLEEP (2x ROUND_SLEEP), retry same AD once before rotating
- On 5xx: sleep 120s, retry same AD once before rotating

### State management

- terraform destroy before each apply attempt to clean partial state
- Destroy failures are non-fatal (|| true)

### Logging

- All output written to oci-provision.log in addition to stdout
- Timestamped log lines
- Round counter displayed each iteration
- Clear SUCCESS message with AD name on completion

### On success

- Print instance details hint (how to get public IP via oci cli)
- Exit 0

-----

## Template placeholders

All templates use {{PLACEHOLDER}} tokens replaced by setup.sh via sed:

|Placeholder         |Source                               |
|--------------------|-------------------------------------|
|{{REGION}}          |~/.oci/config or user input          |
|{{TENANCY_OCID}}    |~/.oci/config auto-detected          |
|{{COMPARTMENT_OCID}}|user input, default = tenancy OCID   |
|{{AD1}}             |live OCI API fetch                   |
|{{AD2}}             |live OCI API fetch                   |
|{{AD3}}             |live OCI API fetch                   |
|{{OCPUS}}           |user input, default 4                |
|{{MEM}}             |user input, default 24               |
|{{SSH_KEY}}         |user input, default ~/.ssh/id_rsa.pub|
|{{AD_SLEEP}}        |user input, default 60               |
|{{ROUND_SLEEP}}     |computed from user input in seconds  |
|{{INSTANCE_NAME}}   |user input, default free-arm-01      |

-----

## main.tf.tpl (new project scaffold only)

Should include:

- terraform block with required_providers (oci hashicorp provider, version ~> 5.0)
- provider "oci" block using variables
- oci_core_vcn resource
- oci_core_subnet resource
- oci_core_internet_gateway resource
- oci_core_route_table + association
- oci_core_security_list with ingress 22/tcp and egress all
- oci_core_instance resource using VM.Standard.A1.Flex shape with var.availability_domain
- output block printing public IP

-----

## variable.tf.tpl

Variables needed:

- availability_domain (string, no default - passed dynamically by provision.sh)
- compartment_id (string)
- region (string, default {{REGION}})
- instance_name (string, default {{INSTANCE_NAME}})
- instance_ocpus (number, default {{OCPUS}})
- instance_memory (number, default {{MEM}})
- ssh_public_key (string, default {{SSH_KEY}})

-----

## terraform.tfvars.tpl

Static values pre-filled from setup.sh. availability_domain is intentionally
commented out since provision.sh passes it dynamically via -var flag.

-----

## README.md

Should cover:

- What this does and why (OCI capacity problem context)
- Prerequisites (terraform, oci cli, jq, ~/.oci/config already configured)
- Quick start (3 commands: clone, cd, bash setup.sh)
- What setup.sh generates
- How to run provision.sh and monitor it
- Exit codes reference (0/2/3/4/5)
- Directory structure diagram
- Link to Medium article (placeholder)

-----

## Constraints and decisions already made

- Templates use {{PLACEHOLDER}} not envsubst ($VAR) to avoid shell variable
  collision in the template files themselves
- provision.sh must be generated into the same directory as main.tf since
  it calls terraform without a path argument
- Minimum round sleep is 5 minutes (300s) - enforce this in setup.sh if user
  enters lower value
- Do not use --auth instance_principal or session tokens - assume standard
  API key auth via ~/.oci/config
- jq is a hard dependency (used to parse AD list JSON from OCI CLI)
- setup.sh should work on Mac (bash 3.x via Homebrew) and Linux (bash 4+)
- No Python, no PHP - pure bash + oci cli + terraform + jq only
- Color output in setup.sh using ANSI codes but gracefully degrade if not a TTY

-----

## Medium article context

This is Post 1 of a 6-part series targeting DevOps and cloud engineers.
Tone is technical, practical, no fluff. Author goes by Nj.

Series title: "Running Autonomous Agents on OCI Free Tier"

Post 1 title: "Claiming Your Free OCI ARM VM - The Right Way"

The article should:

- Open with the OCI capacity problem and why the free tier is worth fighting for
- Walk through prerequisites and OCI CLI setup
- Show clone + make provision as the primary workflow
- Explain the error handling taxonomy in provision.sh (why it matters for agents later)
- Close with a teaser for Post 2 (hardening the VM before putting anything on it)
- Link to the repo: https://github.com/<username>/oci-docker-sandbox-agent
- Each future post will add a directory and update the Makefile - readers should
  star/watch the repo and git pull after each article

Series arc context for the intro:
The end goal is a fully isolated multi-agent system running on free OCI infrastructure.
Post 1 gets the machine. By Post 6 the reader has a production-grade agent sandbox
with observability, isolation, and blast radius containment - all on $0/month infra.
