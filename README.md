# Whole Tale Single-Node Installation

This repo contains scripts required to run a full instance of the Whole Tale
platform on a single system. This repo is based on https://github.com/whole-tale/deploy-dev, 
which is used to deploy development instances.

## Prerequisites
Instructions for these are listed below:
* **Wildcard DNS**: You must have a preconfigured wildcard domain (e.g., `*.wholetale.org`) and IP address. To use this repo, your DNS provider must be supported by [Let's Encrypt](https://go-acme.github.io/lego/dns/index.html) to automatically obtain wildcard TLS certificates. Cloudflare is strongly recommended.
* **Globus App**: You must register a Globus App to use Globus Authentication
* **ORCID App**: You must register an ORCID App to publish tales



## System Requirements
 * Linux (tested on Ubuntu 20.04)
 * docker 17.04.0+, swarm mode (tested on 27.0.3). See [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/).
 * python, requests
 * Default user with uid:1000 and gid:100
 * On Ubuntu, `apt-get install jq make davfs2 fuse libfuse-dev`
  
 
## Deployment 

The deployment process does the following
* Pulls all required images
* Starts the WT stack via Docker swarm
  * The `traefik` container will attempt to obtain a TLS certificate from the configured LE provider
* Starts the Celery worker (`gwvolman`)
  * **WARNING:** In this deployment, the container has elevated privileges including
    *  has access to host's filesystem
    *  ability to perform multiple system calls as de facto host's root
    *  During `celery_worker`'s initialization host's `/usr/local` directory is overshadowed by the content of `/usr/local` from the container.     
* Runs `setup_girder.py` to initialize the instance with a default configuration


If you haven't already, initialize your system as a swarm master:
```
docker swarm init
```

Add default user (1000) and group (100), if not present:
```
[[ -z $(getent group 100) ]] && sudo groupadd -g 100 wtgroup
[[ -z $(getent passwd 1000) ]] && sudo useradd -g 100 -u 1000 wtuser
```

Export Globus Oauth ID and secret:
```
export GLOBUS_CLIENT_ID=<client ID>
export GLOBUS_CLIENT_SECRET=<client secret>
```

Export ORCID ID and secret:
```
export ORCID_CLIENT_ID=<client ID>
export ORCID_CLIENT_SECRET=<client secret>
```

Export Cloudflare API TOKEN:
```
export WT_CLOUDFLARE_TOKEN=<cf_api_token>
```

Export domain you are using:
```
export WT_DOMAIN=local.wholetale.org
```

Clone this repository:

```
git clone https://github.com/whole-tale/deploy-single-node
cd deploy-single-node/
```

Run:
```
make deploy
```

To confirm things are working, all `REPLICAS` should show `1/1`
```
$ docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                        PORTS
jpzhf12jh6wj        wt_dashboard        replicated          1/1                 wholetale/dashboard:latest
26gv8qfb85sq        wt_girder           replicated          1/1                 wholetale/girder:latest
irdizcla8jal        wt_mongo            replicated          1/1                 mongo:3.2
p46dbxbgcae3        wt_redis            replicated          1/1                 redis:latest
vyf55zx0x95y        wt_registry         replicated          1/1                 registry:2.6                 *:443->443/tcp
41u4zyqrrv79        wt_traefik          replicated          1/1                 traefik:alpine               *:80->80/tcp, *:8080->8080/tcp
```

The `celery_worker` runs outside of swarm, confirm that it's running:
```
$ docker ps | grep celery_worker
0e8124024f03        wholetale/gwvolman:latest                                "python3 -m girder_w…"   15 hours ago        Up 15 hours                             celery_worker
```

The `traefik` container will attempt to obtain a wildcard TLS certificate from the configured LE
provider. If this fails, you will either need to re-run `make deploy` or attempt to rerun the `setup_girder.py` manually. To check the `traefik` logs:

```
docker logs $(docker ps --filter=name=wt_traefik  -q) | grep lego
```

You should see something similar to the following or errors:
```
time="2024-10-15T15:28:00Z" level=debug msg="legolog: [INFO] [wt.domain.org, *.wt.domain.org] acme: Obtaining bundled SAN certificate"
time="2024-10-15T15:28:00Z" level=debug msg="legolog: [INFO] [*.wt.domain.org] AuthURL: https://acme-v02.api.letsencrypt.org/acme/authz-v3/416621951187"
time="2024-10-15T15:28:00Z" level=debug msg="legolog: [INFO] [wt.domain.org] AuthURL: https://acme-v02.api.letsencrypt.org/acme/authz-v3/416621951197"
time="2024-10-15T15:28:00Z" level=debug msg="legolog: [INFO] [*.wt.domain.org] acme: use dns-01 solver"
time="2024-10-15T15:28:00Z" level=debug msg="legolog: [INFO] [wt.domain.org] acme: Could not find solver for: tls-alpn-01"
time="2024-10-15T15:28:00Z" level=debug msg="legolog: [INFO] [wt.domain.org] acme: Could not find solver for: http-01"
time="2024-10-15T15:28:00Z" level=debug msg="legolog: [INFO] [wt.domain.org] acme: use dns-01 solver"
time="2024-10-15T15:28:01Z" level=debug msg="legolog: [INFO] [wt.domain.org] acme: Preparing to solve DNS-01"
time="2024-10-15T15:28:02Z" level=debug msg="legolog: [INFO] cloudflare: new record for wt.domain.org, ID 27c74b66139fadf3f0f249faaa716269"
time="2024-10-15T15:28:02Z" level=debug msg="legolog: [INFO] [*.wt.domain.org] acme: Trying to solve DNS-01"
time="2024-10-15T15:28:02Z" level=debug msg="legolog: [INFO] [*.wt.domain.org] acme: Checking DNS record propagation using [127.0.0.11:53]"
time="2024-10-15T15:28:04Z" level=debug msg="legolog: [INFO] Wait for propagation [timeout: 2m0s, interval: 2s]"
time="2024-10-15T15:30:08Z" level=debug msg="legolog: [INFO] [*.wt.domain.org] The server validated our request"
time="2024-10-15T15:30:08Z" level=debug msg="legolog: [INFO] [wt.domain.org] acme: Trying to solve DNS-01"
time="2024-10-15T15:30:08Z" level=debug msg="legolog: [INFO] [wt.domain.org] acme: Checking DNS record propagation using [127.0.0.11:53]"
time="2024-10-15T15:30:10Z" level=debug msg="legolog: [INFO] Wait for propagation [timeout: 2m0s, interval: 2s]"
time="2024-10-15T15:32:13Z" level=debug msg="legolog: [INFO] [wt.domain.org] The server validated our request"
time="2024-10-15T15:32:13Z" level=debug msg="legolog: [INFO] [*.wt.domain.org] acme: Cleaning DNS-01 challenge"
time="2024-10-15T15:32:13Z" level=debug msg="legolog: [INFO] [wt.domain.org] acme: Cleaning DNS-01 challenge"
time="2024-10-15T15:32:14Z" level=debug msg="legolog: [INFO] [wt.domain.org, *.wt.domain.org] acme: Validations succeeded; requesting certificates"
time="2024-10-15T15:32:15Z" level=debug msg="legolog: [INFO] [wt.domain.org] Server responded with a certificate."
```

Once the certificate is obtained, you should be able to access Whole Tale at `https://dashboard.<your-domain>`.


## Uninstall 

The following will remove all services and delete the volume data:

```
make clean
```


## Other

### Using Godaddy

The original deployment uses GoDaddy, which has proven unreliable when working with LE.
To use GoDaddy with LE:

```
export GODADDY_API_KEY=<API Key>
export GODADDY_API_SECRET=<Secret>
```

Modify `docker-stack.yml`:
```
services:
  traefik:
...
    environment:
      - GODADDY_API_KEY=$WT_GODADDY_API_KEY
      - GODADDY_API_SECRET=$WT_GODADDY_API_SECRET
```

Modify `traefik/traefik.toml`:
```
[certificatesResolvers]
  [certificatesResolvers.default]
    [certificatesResolvers.default.acme]
...
      [certificatesResolvers.default.acme.dnsChallenge]
        provider = "godaddy"
```


### Configure DNS
This deployment requires that you have a valid wildcard DNS entry. To configure DNS in Cloudflare:
* Login to Cloudflare
* Select your domain then **DNS**
* Add a record for `*.yourdomain.org` pointing to your public IP address

### Get API Token
To obtain an API key in Cloudflare:
* Go to **My Profile** > **API Tokens**
* **Create Token** using **Edit zone DNS** template  with permission `Zone.Zone READ` and `Zone.DNS Edit`
* Optionally create a client IP address filter
* Copy your API token (will be used as `WT_CLOUDFLARE_TOKEN`)

### Registering a Globus App

* Go to https://app.globus.org/settings/developers
* Select **Register a portal, science gateway or other application**
* Create a new project, if needed
* Add redirect `https://girder.<your-domain>/api/v1/oauth/globus/callback`
* Select **Add Client Secret**
* Copy the Client ID and Secret

### Register ORCID App
* Login to https://orcid.org/
* Select user menu > **Developer tools**
* Create a new application 
* Add redirect URL `https://girder.<your-domain>/api/v1/oauth/orcid/callback
* Copy the Client ID and Secret

## STATA and MATLAB Licenses

In previous deployments, STATA and MATLAB licenses were copied to `volumes/licenses/`. Note that:
* Our current STATA licenses have expired and must be renewed
* UIUC has a new model for MATLAB licensing


## Restoring from Backup

Note: This has not been fully tested.

* Extract `dms.tar`, `homes.tar`, and `registry.tar` to their respective folders under `volumes`.
* Restore `mongodump-<date>.tar`

Run the `backup` container:
```
docker run -it --network wt_mongo -v $PWD:/tmp wholetale/backup bash
```

In the container, restore the database:
```
mongorestore --drop --host=wt_mongo:27017  --archive=/tmp/mongodump-<date>.tar
```

Change CORS Allowed Origin
* Open `https://girder.<yourdomain>`
* Go to Admin console > System configuration > Advanced settings
* Update the CORS Allowed Origin to `https://dashboard.<your-domain>`

