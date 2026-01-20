.PHONY: help init plan apply destroy validate fmt output test clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

init: ## Initialize Terraform
	cd terraform && terraform init

plan: ## Run Terraform plan
	cd terraform && terraform plan

apply: ## Apply Terraform configuration
	cd terraform && terraform apply

destroy: ## Destroy all infrastructure
	cd terraform && terraform destroy

validate: ## Validate Terraform configuration
	cd terraform && terraform fmt -check && terraform validate

fmt: ## Format Terraform files
	cd terraform && terraform fmt -recursive

output: ## Show Terraform outputs
	cd terraform && terraform output

keys: ## Generate SSH keys
	./scripts/generate-ssh-keys.sh

test-alerts: ## Test alerting system (requires APP_IP env var)
	@if [ -z "$(APP_IP)" ]; then \
		echo "Error: APP_IP not set. Usage: make test-alerts APP_IP=<ip>:8080"; \
		exit 1; \
	fi
	./scripts/test-alerts.sh $(APP_IP)

session-grafana: ## Start Session Manager session to Grafana
	@INSTANCE_ID=$$(cd terraform && terraform output -raw grafana_instance_id 2>/dev/null); \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "Error: Could not get Grafana instance ID. Run 'make apply' first."; \
		exit 1; \
	fi; \
	echo "Starting Session Manager session to Grafana ($$INSTANCE_ID)..."; \
	aws ssm start-session --target $$INSTANCE_ID

session-prometheus: ## Start Session Manager session to Prometheus
	@INSTANCE_ID=$$(cd terraform && terraform output -raw prometheus_instance_id 2>/dev/null); \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "Error: Could not get Prometheus instance ID. Run 'make apply' first."; \
		exit 1; \
	fi; \
	echo "Starting Session Manager session to Prometheus ($$INSTANCE_ID)..."; \
	aws ssm start-session --target $$INSTANCE_ID

session-app: ## Start Session Manager session to Application
	@INSTANCE_ID=$$(cd terraform && terraform output -raw application_instance_id 2>/dev/null); \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "Error: Could not get Application instance ID. Run 'make apply' first."; \
		exit 1; \
	fi; \
	echo "Starting Session Manager session to Application ($$INSTANCE_ID)..."; \
	aws ssm start-session --target $$INSTANCE_ID

port-forward-grafana: ## Port forward Grafana (run in background)
	@INSTANCE_ID=$$(cd terraform && terraform output -raw grafana_instance_id 2>/dev/null); \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "Error: Could not get Grafana instance ID. Run 'make apply' first."; \
		exit 1; \
	fi; \
	echo "Port forwarding Grafana ($$INSTANCE_ID:3000 -> localhost:3000)..."; \
	echo "Access at http://localhost:3000"; \
	aws ssm start-session --target $$INSTANCE_ID \
		--document-name AWS-StartPortForwardingSession \
		--parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'

port-forward-prometheus: ## Port forward Prometheus (run in background)
	@INSTANCE_ID=$$(cd terraform && terraform output -raw prometheus_instance_id 2>/dev/null); \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "Error: Could not get Prometheus instance ID. Run 'make apply' first."; \
		exit 1; \
	fi; \
	echo "Port forwarding Prometheus ($$INSTANCE_ID:9090 -> localhost:9090)..."; \
	echo "Access at http://localhost:9090"; \
	aws ssm start-session --target $$INSTANCE_ID \
		--document-name AWS-StartPortForwardingSession \
		--parameters '{"portNumber":["9090"],"localPortNumber":["9090"]}'

clean: ## Clean up generated files
	rm -rf terraform/.terraform
	rm -f terraform/.terraform.lock.hcl
	rm -f terraform/terraform.tfstate*
	rm -rf keys/*.pem keys/id_rsa*
