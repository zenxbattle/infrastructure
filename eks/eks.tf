module "eks" {
  source = "terraform-aws-modules/eks/aws"

  name               = "sandbox-liju"
  kubernetes_version = "1.33"

  addons = {

    # this is cluster dns — the internal dns server for the entire cluster.
    # every pod uses it to resolve service names. when pod-a calls authn-svc-genapp.default:9001,
    # it asks coredns: "what ip is authn-svc-genapp.default.svc.cluster.local?" coredns returns the
    # clusterip of the authn service. without coredns, pods cannot find each other by name.
    #
    # the core-controllers node is tainted with core-controllers=true:NoSchedule. this taint
    # means "only pods that explicitly tolerate this can run here." we are adding that toleration
    # so coredns ignores the taint and schedules on this node anyway.
    #
    # we do this because no untainted worker nodes exist when the cluster first boots. the
    # core-controllers node is the only node. if coredns cannot tolerate the taint, it tries to
    # schedule, finds zero eligible nodes, and stays Pending forever. dns is dead. no pod can
    # resolve any service name. the cluster is running but effectively unusable.
    coredns = {
      configuration_values = jsonencode({
        tolerations = [
          {
            key      = "core-controllers"
            operator = "Equal"
            value    = "true"
            effect   = "NoSchedule"
          }
        ]
      })
    }

    # this is the eks pod identity agent — a daemonset that runs on every node.
    # it intercepts imds (instance metadata service) calls from pods and exchanges kubernetes
    # service account tokens for temporary iam credentials. it proxies requests so pods never
    # need static aws access keys or iam user credentials.
    #
    # here is the flow: a pod with a service account linked to a pod identity makes an aws api
    # call. the aws sdk checks the standard credential chain. when it reaches the imds step
    # (http://169.254.169.254), the pod identity agent intercepts the request. it reads the pod's
    # service account token, sends it to the eks auth service, receives temporary iam credentials,
    # and returns them to the pod. the pod now has scoped, short-lived aws access.
    #
    # we set before_compute = true to force this addon to install before any worker nodes join
    # the cluster. this guarantees the agent daemonset is running on every node before any pods
    # are scheduled there. without this ordering guarantee, a pod that needs aws access can start
    # on a node before the agent daemonset pod is ready on that node. the credential call to imds
    # fails with a timeout — no agent is listening yet. the pod gets AccessDenied on aws api calls.
    # eventually the agent starts and the pod recovers, but it causes startup errors and retries.
    eks-pod-identity-agent = {
      before_compute = true
    }

    kube-proxy = {}

    # this is the vpc cni (container network interface) plugin — a daemonset that runs on
    # every node. it is responsible for assigning ip addresses to pods from the vpc subnet
    # the node lives in. unlike overlay networks (flannel, calico default), vpc-cni gives each
    # pod a real, routeable ip from the aws vpc address space. other aws services see the pod's
    # ip directly — security groups, nacls, vpc flow logs all apply to pods natively.
    #
    # how it works: when a pod is scheduled on a node, the kubelet calls the cni plugin to set
    # up networking. vpc-cni attaches a secondary ip address from the node's eni (elastic network
    # interface) to the pod. the pod gets a veth pair connected to the node's network namespace.
    # traffic from the pod leaves through the node's eni with the pod's assigned ip as the source.
    # each eni supports a limited number of secondary ips (t4g supports ~50), so vpc-cni maintains
    # a warm pool of pre-attached ips for fast pod startup.
    #
    # we set before_compute = true because pods cannot start without ip addresses. if vpc-cni
    # is not installed when a worker node joins, the kubelet calls the cni plugin, gets no
    # response, and marks the pod as ContainerCreating with the error "failed to set up pod
    # network." the pod stays stuck indefinitely. every pod on every node is affected. the
    # cluster has nodes but cannot run any workload. this addon must exist before any pod does.
    vpc-cni = {
      before_compute = true
    }

    # this is the ebs csi (container storage interface) driver — a daemonset that runs on
    # every node plus a controller deployment. it lets pods request persistent storage through
    # persistentvolumeclaims (pvcs). when a pod claims a pvc, the csi driver creates an ebs
    # volume, attaches it to the node, and mounts it into the pod.
    #
    # two components: the node daemonset handles volume attach/detach/mount on each node.
    # the controller deployment handles volume creation/deletion and talks to the aws ebs api.
    # the controller needs to run somewhere — and the only node available at startup is the
    # tainted core-controllers node. so we add a toleration for the controller.
    #
    # without this toleration, the ebs csi controller pod cannot schedule anywhere at startup.
    # when a pvc is created, no controller is available to call ebs:CreateVolume. the pvc stays
    # Pending forever. stateful workloads (databases, message queues, caches) cannot start
    # because their storage is never provisioned.
    aws-ebs-csi-driver = {
      configuration_values = jsonencode({
        controller = {
          tolerations = [
            {
              key      = "core-controllers"
              operator = "Equal"
              value    = "true"
              effect   = "NoSchedule"
            }
          ]
        }
      })
    }
  }

  # this is the eks api server endpoint. controls whether the api is reachable from the internet.
  # we are setting it to public so kubectl works from your laptop without a vpn or bastion.
  # without this, kubectl only works inside the vpc. you would need tailscale or a bastion host
  # to run any kubectl command. authentication still requires iam via aws eks get-token.
  endpoint_public_access = true

  vpc_id     = data.aws_vpc.selected.id
  subnet_ids = data.aws_subnets.private.ids

  eks_managed_node_groups = {

    # this is a managed node group — an aws-managed autoscaling group of ec2 instances
    # that are pre-configured to join the eks cluster. aws handles the full lifecycle:
    # provisioning, health checking, replacing failed nodes, rolling ami updates, and
    # draining nodes during cluster version upgrades.
    #
    # we name it core-controllers because it runs only cluster controllers (karpenter,
    # argocd, aws-lbc, ebs-csi). no user workloads run here.
    #
    # how it works: aws launches a t4g.medium graviton ec2 instance in each private subnet.
    # a bootstrap script (managed by aws, not us) joins the instance to the eks cluster.
    # the kubelet registers it as a node. eks applies the labels and taints we define here.
    # the addons (coredns, kube-proxy, vpc-cni, ebs-csi) deploy as daemonsets on the node.
    #
    # we set min=max=desired=1 — a single fixed node for sandbox. the real platform uses
    # max=3 for high availability. if this node dies, aws auto-replaces it in 3-5 minutes.
    # during that window, controllers are down. karpenter cannot provision workers. argocd
    # cannot sync. existing pods on karpenter workers continue running unaffected.
    core-controllers = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = ["t4g.medium"]

      # this is the root ebs volume attached to the ec2 instance. it stores the operating
      # system, container images pulled by containerd, and emptyDir volumes from pods.
      # we are encrypting it at rest using the default aws kms key for ebs.
      # without encryption, the root volume data is stored in plaintext on the physical disk.
      # if the physical drive is decommissioned or stolen, all data on it is readable.
      # encryption is a security baseline — the real platform encrypts every volume.
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda" # root device name for arm64 graviton instances
          ebs = {
            encrypted = true
          }
        }
      }

      min_size     = 1
      max_size     = 1
      desired_size = 1

      # this controls access to the ec2 instance metadata service (imds) at 169.254.169.254.
      # every ec2 instance runs imds — it provides temporary credentials, instance identity,
      # and userdata. the hop limit controls how many network hops a metadata request can travel.
      #
      # we set it to 2 because the pod identity agent needs to proxy requests from pods.
      # the chain is: pod (hop 0) → agent daemonset on the node (hop 1) → real imds (hop 2).
      # without hop_limit=2, the agent receives the pod's request but cannot forward it to imds —
      # the metadata service rejects it as exceeding the hop count. pods get credential timeouts.
      metadata_options = {
        http_put_response_hop_limit = 2
      }

      # these are kubernetes labels attached to the node at registration time. they are
      # key-value pairs that the scheduler and other controllers can use for node selection.
      #
      # we set these because karpenter and argocd helm charts use nodeSelector to pin themselves
      # to this specific node. karpenter's values.yaml says "only run on nodes with label
      # karpenter.sh/controller=true". argocd uses argoproj.github.io/controller=true.
      #
      # without these labels, the controller pods have zero nodes matching their nodeSelector.
      # they stay Pending forever. no karpenter means no worker nodes provisioned. no argocd
      # means no gitops deployment pipeline. the cluster has a control plane but no functionality.
      labels = {
        "karpenter.sh/controller"       = "true"
        "argoproj.github.io/controller" = "true"
      }

      # this is a kubernetes node taint. it repels pods that do not have a matching toleration.
      # we are tainting the node so only controller pods run here.
      #
      # the taint has three parts: key=core-controllers, value=true, effect=NoSchedule.
      # "key" and "value" form a pair — any pod that wants to run here must have a toleration
      # with the same key and value. "effect" defines what happens to pods without the toleration:
      # NoSchedule means the scheduler will not place new pods here. PreferNoSchedule would mean
      # "try to avoid but allow if nowhere else." NoExecute would mean "evict existing pods too."
      #
      # "dedicated" is just a label for the taint block inside terraform — it has no effect on
      # kubernetes. it is a terraform map key, not a kubernetes concept. you could name it
      # "controller-only" or "reserved" — it is just an identifier inside this hcl block.
      #
      # how the scheduler uses taints: when a new pod needs to be placed, the scheduler iterates
      # over all nodes. for each node, it checks: does this pod tolerate every taint on this node?
      # if yes, the node is a candidate. if no, the node is skipped. a pod with a toleration of
      # key=core-controllers, operator=Equal, value=true, effect=NoSchedule would match this taint
      # and can schedule here. a pod with no toleration, or a toleration with a different key/value,
      # cannot schedule here.
      #
      # what happens without this taint: any pod can schedule on this node. user workloads compete
      # with controller pods for cpu and memory. if the node runs out of memory, the kernel oom-killer
      # may terminate the karpenter pod. karpenter stops provisioning new nodes. the cluster cannot
      # scale. if argocd gets evicted, no new deployments happen. the managed node group replaces
      # the dead node, but the cycle repeats because the taint is not there to prevent it.
      taints = {
        dedicated = {
          key    = "core-controllers"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      # this attaches an iam policy to the node's iam role. every ec2 instance has an iam role
      # that grants the instance itself permission to call aws apis — this is separate from pod
      # identities, which grant permissions to individual pods.
      #
      # the ebs csi driver runs as a daemonset on this node. its controller pod needs permission
      # to call ec2:CreateVolume, ec2:AttachVolume, ec2:DeleteVolume, and ec2:DescribeVolumes.
      # this policy grants those permissions.
      #
      # without this, the ebs csi driver cannot create or attach ebs volumes. any pod that uses
      # a persistentvolumeclaim gets stuck in Pending with "failed to provision volume" errors.
      # stateful workloads (databases, caches) cannot start because they depend on persistent storage.
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  # this is the eks access entry system — how aws iam identities are mapped to kubernetes
  # rbac roles. in a self-managed cluster, you edit kubeconfig files and certificate authorities.
  # in eks, you define access entries that say "iam role X gets kubernetes permission Y."
  #
  # how it works: when you run `aws eks update-kubeconfig`, kubectl is configured to call
  # `aws eks get-token` before every request. that command uses your current aws credentials
  # (from sso) to generate a temporary authentication token. kubectl sends this token to the
  # eks api server. the api server looks at the token, extracts your iam role, finds it in
  # the access entries, and maps you to the associated kubernetes rbac permissions.
  #
  # we are granting AmazonEKSClusterAdminPolicy — full cluster-admin, equivalent to the
  # system:masters group in a self-managed cluster. you can create, delete, and modify
  # everything. the principal_arn uses a wildcard * because sso roles have a random suffix
  # appended to the role name. writing the full arn would break when aws rotates the suffix.
  # the account_id is resolved dynamically from data.aws_caller_identity.
  #
  # without this entry, kubectl commands return "error: You must be logged in to the server
  # (Unauthorized)." aws sso login succeeds, the token is valid, but eks has no mapping from
  # your iam role to any kubernetes user. the cluster exists but you cannot interact with it.
  access_entries = {
    sso_administrators = {
      principal_arn = data.aws_iam_role.sso_administratoraccess.arn
      policy_associations = {
        eksadminpolicy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = local.default_tags
}
