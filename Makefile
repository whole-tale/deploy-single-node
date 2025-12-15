.PHONY: clean dirs deploy images restart_worker status

SUBDIRS = volumes/ps volumes/workspaces volumes/homes volumes/base volumes/versions volumes/runs volumes/licenses traefik/acme volumes/registry volumes/io_manager_storage
TAG = latest
MEM_LIMIT = 2048
NODE = node --max_old_space_size=${MEM_LIMIT}
NG = ${NODE} ./node_modules/@angular/cli/bin/ng
YARN = /usr/local/bin/yarn

images:
	docker pull traefik:v3.6
	docker pull mongo:4.4
	docker pull xarthisius/girder_wholetale:$(TAG)
	docker pull wholetale/instance_logger:$(TAG)
	docker pull wholetale/custom-errors:$(TAG)
	docker pull redis:7-bullseye
	docker pull registry:2.6
	docker pull node:carbon-slim
	docker pull postgres:11
	docker pull xarthisius/repo2docker_wholetale:20250415
	docker pull wholetale/girderfs:$(TAG)
	docker pull xarthisius/gwvolman:$(TAG)
	docker pull xarthisius/dagster:$(TAG)
	docker pull wholetale/ngx-dashboard:$(TAG)

dirs: $(SUBDIRS)

$(SUBDIRS):
	@sudo mkdir -p $@
	@sudo chown 1000:1000 $@

.env:
	curl -s -o .env https://wt.xarthisius.xyz/wt_local_env

traefik/certs:
	mkdir -p traefik/certs

traefik/certs/fullchain.pem: traefik/certs
	curl -s -o traefik/certs/fullchain.pem https://wt.xarthisius.xyz/wt_local_cert

traefik/certs/privkey.pem: traefik/certs
	curl -s -o traefik/certs/privkey.pem https://wt.xarthisius.xyz/wt_local_key

certs: .env traefik/certs/fullchain.pem traefik/certs/privkey.pem

services: dirs 

deploy: dirs certs
	. ./.env && htpasswd -Bbn $${registry_user} $${registry_pass} > registry/auth/registry.password
	. ./.env && docker stack config --compose-file docker-stack.yml | docker stack deploy --compose-file=docker-stack.yml wt
	cid=$$(docker ps --filter=name=wt_girder -q);
	while [ -z $${cid} ] ; do \
		  echo $${cid} ; \
		  sleep 1 ; \
	    cid=$$(docker ps --filter=name=wt_girder -q) ; \
	done; \
	true
	./setup_girder.py

tail_girder_err:
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
		tail -n 200 /home/girder/.girder/logs/error.log

reset_girder:
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
		python3 -c 'from girder.models import getDbConnection;getDbConnection().drop_database("girder")'

clean:
	-./destroy_instances.py
	-docker stack rm wt
	limit=15 ; \
	until [ -z "$$(docker service ls --filter label=com.docker.stack.namespace=wt -q)" ] || [ "$${limit}" -lt 0 ]; do \
	  sleep 2 ; \
	  limit="$$((limit-1))" ; \
	done; true
	limit=15 ; \
	until [ -z "$$(docker network ls --filter label=com.docker.stack.namespace=wt -q)" ] || [ "$${limit}" -lt 0 ]; do \
	  sleep 2 ; \
	  limit="$$((limit-1))" ; \
	done; true
	for dir in ps workspaces homes base versions runs ; do \
	  sudo rm -rf volumes/$$dir ; \
	done; true
	-docker volume rm wt_mongo-cfg wt_mongo-data

status:
	@-./scripts/git_status.sh
