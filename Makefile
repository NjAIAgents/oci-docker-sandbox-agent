.PHONY: provision harden docker agent multi-agent observe ssh check-provision-deps check-ssh-deps

# ---- Prerequisite checks ----

# Tools required before running setup.sh
check-provision-deps:
	@command -v terraform >/dev/null 2>&1 || \
		{ echo ""; echo "  [MISSING] terraform — install from https://developer.hashicorp.com/terraform/install"; echo ""; exit 1; }
	@command -v oci >/dev/null 2>&1 || \
		{ echo ""; echo "  [MISSING] oci — install from https://docs.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm"; echo ""; exit 1; }
	@command -v jq >/dev/null 2>&1 || \
		{ echo ""; echo "  [MISSING] jq — install via: brew install jq  OR  apt install jq"; echo ""; exit 1; }
	@test -f "$(HOME)/.oci/config" || \
		{ echo ""; echo "  [MISSING] ~/.oci/config — run: oci setup config"; echo ""; exit 1; }
	@test -f "$(HOME)/.ssh/id_ed25519.pub" || test -f "$(HOME)/.ssh/id_rsa.pub" || \
		{ echo ""; echo "  [MISSING] SSH public key — run: ssh-keygen -t ed25519 -C \"oci-docker-sandbox-agent\""; echo ""; exit 1; }
	@echo "  [OK] terraform, oci, jq, ~/.oci/config, and SSH key found"

# Tools required for SSH (post-provision)
check-ssh-deps:
	@test -f ".env" || \
		{ echo ""; echo "  [MISSING] .env — copy .env.example to .env and set VM_PUBLIC_IP after provisioning"; echo ""; exit 1; }
	@grep -q "VM_PUBLIC_IP=.\+" .env 2>/dev/null || \
		{ echo ""; echo "  [MISSING] VM_PUBLIC_IP not set in .env — fill it in after provision.sh succeeds"; echo ""; exit 1; }

# ---- Post 1: Claim the VM (available now) ----
provision: check-provision-deps
	cd 01-provision && bash setup.sh

# ---- Post 2: OS hardening ----
harden: check-ssh-deps
	cd 02-harden && bash setup.sh

# ---- Post 3: Docker sandbox ----
docker:
	@echo ""
	@echo "Covered in Post 3: Docker install, container isolation, and seccomp profiles."
	@echo "Pull the latest and follow 03-docker-sandbox/README.md"
	@echo ""
	@echo "  git pull"
	@echo "  cat 03-docker-sandbox/README.md"
	@echo ""

# ---- Post 4: Agent deployment ----
agent:
	@echo ""
	@echo "Covered in Post 4: Deploying OpenClaw agent in the Docker sandbox."
	@echo "Pull the latest and follow 04-agent/README.md"
	@echo ""
	@echo "  git pull"
	@echo "  cat 04-agent/README.md"
	@echo ""

# ---- Post 5: Multi-agent system ----
multi-agent:
	@echo ""
	@echo "Covered in Post 5: Multi-agent system, message bus, and blast radius containment."
	@echo "Pull the latest and follow 05-multi-agent/README.md"
	@echo ""
	@echo "  git pull"
	@echo "  cat 05-multi-agent/README.md"
	@echo ""

# ---- Post 6: Observability ----
observe:
	@echo ""
	@echo "Covered in Post 6: Prometheus, Grafana, and kill switches."
	@echo "Pull the latest and follow 06-observability/README.md"
	@echo ""
	@echo "  git pull"
	@echo "  cat 06-observability/README.md"
	@echo ""

# ---- SSH helper: works after Post 1 completes ----
ssh: check-ssh-deps
	bash scripts/ssh-to-vm.sh
