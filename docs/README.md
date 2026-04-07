# Documentation

All documentation in this repository should be written in English.

## Structure

- `deployment/`: deployment and environment setup guides
- `assets/images/`: images referenced by Markdown files

## Current Documents

- `deployment/Kubernetes_Deployment.md`: K3s-based Kubernetes deployment guide
- `deployment/NFS_Deployment.md`: NFS-backed shared storage deployment guide for K3s
- `deployment/DNS_Deployment.md`: CoreDNS-based lab DNS deployment guide for K3s

## Image Convention

Store Markdown images under `docs/assets/images/<document-slug>/`.

Example:

```text
docs/
|-- deployment/
|   `-- Kubernetes_Deployment.md
`-- assets/
    `-- images/
        `-- kubernetes-deployment/
            `-- architecture.png
```

Use relative paths in Markdown:

```md
![Architecture](../assets/images/kubernetes-deployment/architecture.png)
```
