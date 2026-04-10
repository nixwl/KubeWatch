# Request Tracker Deployment

Request Tracker (commonly referred to as RT) is an open-source ticketing system or issue tracking system designed to track, manage, and coordinate various types of requests, tasks, and issues. Originally developed by Best Practical Solutions, it is widely utilized in IT support, customer service, project management, and internal collaboration.

- Ticket Creation & Management: Users can submit requests via email or web forms, and the system automatically generates a Ticket. Each ticket features a unique ID, status, priority, owner, and due date.
- Multi-User Collaboration: Supports team assignments, comments, and status updates, enabling seamless collaborative processing. It also provides robust access control, ensuring different roles have appropriate viewing and operational permissions.
- Deep Email Integration: A standout feature of RT is its tight email integration. Sending an email to a designated address automatically creates a ticket, and replying to emails automatically associates the message with the correct ticket, maintaining a complete communication history.
- Customizable Workflows: Automation is achieved through configurable rules called Scrips. For example:
  - Automatically assigning new tickets to specific personnel.
  - Escalating priority for tickets that remain unhandled past a deadline.
  - Sending satisfaction surveys automatically upon ticket closure.
- Knowledge Base & Templates: Supports saved replies (Templates) and knowledge base articles to improve response efficiency.
- Reporting & Analytics: Provides statistical reports on ticket volume, response times, and resolution rates, facilitating performance analysis and process optimization.
- High Extensibility: Built on Perl, RT supports a wide range of Extensions for features such as LDAP/Active Directory integration, Slack notifications, and REST API access.

## Prerequisites

- A Kubernetes namespace named `rt`
- A working PostgreSQL deployment in the `database` namespace
- Worker nodes labeled with `node-role=worker`
- Helm installed on the operator machine
- A DNS name such as `rt.example.com`
- A certificate issuer such as `producer-ca-issuer`

## Prepare The PostgreSQL Database

We use PostgreSQL as the external database for RT. Start a temporary PostgreSQL client pod and connect to the primary service:

```sh
kubectl -n database run psql --rm -it --restart=Never \
  --image=alpine/psql:18.1 \
  --env='PGPASSWORD=<postgres-password>' \
  --command -- psql -h pg-postgresql-primary -U postgres -d postgres
```

Inside PostgreSQL, create the RT role, database, and schema:

```pgsql
-- create user and database
CREATE ROLE rt LOGIN PASSWORD 'rt123!' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE DATABASE rt OWNER rt;
-- permission assign
REVOKE ALL ON DATABASE rt FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE rt TO rt;
\c rt
CREATE SCHEMA IF NOT EXISTS rt AUTHORIZATION rt;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE USAGE ON SCHEMA public FROM PUBLIC;
ALTER ROLE rt IN DATABASE rt SET search_path = rt,public;
```

Verify connectivity with the new account:

```sh
kubectl -n database run psql-rt --rm -it --restart=Never \
  --image=alpine/psql:18.1 \
  --env='PGPASSWORD=rt123!' \
  --command -- psql -h pg-postgresql-primary -U rt -d rt -v ON_ERROR_STOP=1
```

Inside the session, confirm the connection:

```pgsql
\conninfo
SHOW search_path;
SELECT current_user, current_database();
\q
```

## Create RT Base Secret

We define a namespace named `rt` and a [base secret](../../configs/pipelines/workload/rt-secret.yaml) that stores the database connection, the initial RT root password, and the web identity values.

```yaml
# rt-secret.yaml
apiVersion: v1
kind: Secret
metadata:
name: rt-secrets
namespace: rt
type: Opaque
stringData:
RT_DB_HOST: "pg-postgresql-primary.database.svc.cluster.local"
RT_DB_PORT: "5432"
RT_DB_NAME: "rt"
RT_DB_USER: "rt"
RT_DB_PASS: "rt123!"
RT_ROOT_PASSWORD: "root123!"
RT_WEB_DOMAIN: "rt.example.com"
RT_WEB_PORT: "443"
RT_WEB_PATH: ""
RT_RTNAME: "rt.example.com"
RT_ORGANIZATION: "example.com"
```

```sh
kubectl apply -f rt-secret.yaml
```

## Add The Helm Chart and Export Values

The deployment uses `bjw-s/app-template` version `4.6.2`.

```sh
helm repo add bjw-s https://bjw-s-labs.github.io/helm-charts
helm repo update
helm search repo bjw-s/app-template -l | head
# export values
helm show values bjw-s/app-template --version 4.6.2 > rt-values.yaml
```

Use the provided [rt-values-init.yaml](../../configs/pipelines/workload/rt-values-init.yaml) and [rt-values-web.yaml](../../configs/pipelines/workload/rt-values-web.yaml) as the actual working configuration files.

## Phase 1: Run The RT Initialization Job

The source package uses a one-time init job to:

- Enable `RT::Authen::Token`
- Enable `RT::Extension::REST2`
- Initialize the core RT database schema
- Create the `RTxAuthTokens` table and sequence if they do not already exist

The init values file uses:

- `type: job`
- Node scheduling on `node-role=worker`
- The image `quay.io/abh/rt`
- A mounted `RT_SiteConfig.d` config map
- A mounted secret named `rt-env`

Important runtime behavior from the source file:

- Installs `perl-dbd-pg` and `postgresql-client`
- Runs `/opt/rt/sbin/rt-setup-database --action init --skip-create`
- Uses `/run/secrets/RT_ROOT_PASSWORD` for the initial RT root password
- Creates the token table with `psql` if needed

Ensure the namespace exists, then install the init job:

```sh
kubectl get ns rt >/dev/null 2>&1 || kubectl create ns rt

# apply init job
helm upgrade --install rt-init bjw-s/app-template \
  -n rt \
  --version 4.6.2 \
  -f rt-values-init.yaml

# Verify The Init Job
kubectl -n rt get pods,job -l app.kubernetes.io/instance=rt-init -o wide
kubectl -n rt logs -l app.kubernetes.io/instance=rt-init --all-containers --tail=200

# If the schema initialization completed successfully, remove the init release
helm uninstall rt-init -n rt
```

## Phase 2: Deploy The RT Web Application

The final deployment uses `rt-values-web.yaml`, which enables the same plugins, mounts the RT configuration directory, exposes RT through Traefik, and runs the web application as a Deployment.

The source notes also mention importing a registry [pull secret](../../configs/pipelines/workload/rt-secret.yaml) for `quay.io` before deploying RT:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: nixwl-pull-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: "<base64-dockerconfigjson>"
```

Apply it if your cluster requires authenticated pulls:

```sh
kubectl apply -f rt-pull-secret.yaml --namespace=rt
```

```sh
helm upgrade --install rt bjw-s/app-template \
  -n rt \
  --create-namespace \
  --version 4.6.2 \
  -f rt-values-web.yaml
```

## Verify The Deployment

Check the Deployment, ReplicaSet, Pods, Service, and Endpoints:

```sh
kubectl -n rt get deploy,rs,pods -o wide
kubectl -n rt get svc -o wide
kubectl -n rt get endpoints rt -o yaml
```

Test in-cluster access, expected 200 or 302

```sh
kubectl -n rt run curl --rm -it --restart=Never --image=curlimages/curl \
  --command -- sh -lc 'curl -sS -I http://rt:8000/ | head -n 20'
```

Check the ingress and TLS resources:

```sh
kubectl -n rt get ingress -o wide
kubectl -n rt describe ingress rt | sed -n '/Rules:/,$p'
kubectl -n rt get certificate,certificaterequest,order,challenge 2>/dev/null || true
kubectl -n rt get secret rt-general-tls -o wide
```

Then test external HTTPS access:

```sh
curl -vk https://rt.example.com/
```

## Optional: Enable The Auth Token Plugin For API Access

Keep `RT::Authen::Token` and `RT::Extension::REST2` enabled so RT can issue API tokens later. After deployment, you can grant the relevant rights in the RT UI and retrieve the token from the user profile or token management page.

```yaml
configMaps:
  rt-siteconfig:
    enabled: true
    data:
      05-plugins.pm: |
        Plugin('RT::Authen::Token');
        Plugin('RT::Extension::REST2');
```
