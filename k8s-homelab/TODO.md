# TODO

## CKA training

* [x] install etcdctl and etcdutl when running 'preprod-up'. From Ubuntu repos, if possible
* [x] install glow markdown CLI viewer from Charm official deb repo
* [ ] add option to have multiple control plane hosts + VIP

## Homelab Kubernetes administration

* [x] install Caddy on control plane to serve requests to Ingresses from port 443. Caddy has to be built with support for PowerDNS. It has to reverse proxy requests on port 443 for the domain *.k8s.os76.xyz to port 30443 of the cluster nodes. Manage TLS installing Let's Encrypt certificates via DNS challenge.
* [ ] integrate cluster with AWS OIDC for IAM permissions on Pods
