module "aws_lb_controller_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  name   = "liju-aws-lbc"

  # attaches AWSLoadBalancerControllerIAMPolicy:
  #   ec2:Describe*, elasticloadbalancing:* (create/delete/modify alb/nlb),
  #   acm:List/Describe (tls certs), ec2:Authorize/RevokeSecurityGroup*,
  #   wafv2:*, shield:*, iam:CreateServiceLinkedRole
  # lets the aws lb controller create albs/nlbs for k8s services and gateways
  # without this, kong-internal gets no nlb and services are unreachable
  # ref: https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/#iam-permissions
  attach_aws_lb_controller_policy = true

  association_defaults = {
    namespace       = "kube-system"
    service_account = "aws-load-balancer-controller-sa"
  }

  associations = {
    sandbox-liju = {
      cluster_name = module.eks.cluster_name
    }
  }

  tags = local.default_tags
}

module "external_dns_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  name   = "liju-external-dns"

  external_dns_hosted_zone_arns = [data.aws_route53_zone.sandbox_liju_internal.arn]
  # attaches inline policy scoped to the hosted zone:
  #   route53:ChangeResourceRecordSets (upsert/delete dns records),
  #   route53:ListResourceRecordSets, route53:ListHostedZones
  # lets external-dns create route53 records in the private hosted zone
  # when a gateway or cert is created, external-dns auto-registers *.sandbox-liju.internal
  # without this, services cant resolve each other by dns name
  # ref: https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md#iam-policy
  attach_external_dns_policy = true

  association_defaults = {
    namespace       = "external-dns"
    service_account = "external-dns-sa"
  }

  associations = {
    sandbox-liju = {
      cluster_name = module.eks.cluster_name
    }
  }

  tags = local.default_tags
}

module "cert_manager_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  name   = "liju-cert-manager"

  cert_manager_hosted_zone_arns = [data.aws_route53_zone.sandbox_liju_internal.arn]
  # attaches inline policy scoped to the hosted zone:
  #   route53:GetChange (check dns propagation for acme challenges),
  #   route53:ListHostedZonesByName, route53:ChangeResourceRecordSets
  # lets cert-manager solve dns-01 challenges in route53 to issue tls certs
  # combined with self-signed issuer in gitops, auto-provisions internal certs
  # without this, kong cant terminate https on *.sandbox-liju.internal
  # ref: https://cert-manager.io/docs/configuration/acme/dns01/route53/
  attach_cert_manager_policy = true

  association_defaults = {
    namespace       = "cert-manager"
    service_account = "cert-manager-sa"
  }

  associations = {
    sandbox-liju = {
      cluster_name = module.eks.cluster_name
    }
  }

  tags = local.default_tags
}
