# 0011. Express EKS add-on ordering in the dependency graph, not with multiple applies

- **Status:** Accepted
- **Date:** 2026-10-14

## Context
The cluster was applied in two phases (`create_node_group=false`, then `true`) to avoid add-ons racing the
nodes. In practice phase 1 created `coredns` and `aws-ebs-csi-driver` with no nodes to schedule on; both stayed
`DEGRADED` until Terraform's 20-minute timeout failed the run.

## Decision
A single apply, with ordering declared in configuration:
- `vpc-cni` and `kube-proxy` use the EKS module's `before_compute = true`, so nodes join with networking ready.
- `coredns` (module default) and `aws-ebs-csi-driver` (`depends_on = [module.eks]`) are created after the node group.

## Alternatives considered
- **Keep two phases and move add-ons into phase 2:** still hides real dependencies inside a script and the pipeline.
- **Raise add-on timeouts:** only waits longer for something that can't succeed without nodes.

## Consequences
- One `terraform apply` builds the cluster correctly from empty.
- Lesson recorded: changing a resource address (`this[...]` → `before_compute[...]`) without a `moved` block
  makes Terraform destroy and recreate it. Here the destroy and create ran in parallel and failed with
  `409 Addon already exists`. Use `moved` blocks for address changes.
