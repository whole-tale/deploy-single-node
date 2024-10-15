.PHONY: clean dirs deploy images restart_worker status

SUBDIRS = volumes/ps volumes/workspaces volumes/homes volumes/base volumes/versions volumes/runs volumes/licenses traefik/acme
TAG = latest
MEM_LIMIT = 2048
NODE = node --max_old_space_size=${MEM_LIMIT}
NG = ${NODE} ./node_modules/@angular/cli/bin/ng
YARN = /usr/local/bin/yarn

images:
	docker pull traefik:alpine
	docker pull mongo:3.2
	docker pull redis:latest
	docker pull registry:2.6
	docker pull node:carbon-slim
	docker pull wholetale/girder:$(TAG)
	docker pull wholetale/gwvolman:$(TAG)
	docker pull wholetale/repo2docker_wholetale:$(TAG)
	docker pull wholetale/ngx-dashboard:$(TAG)

dirs: $(SUBDIRS)

$(SUBDIRS):
	@sudo mkdir -p $@

services: dirs 

deploy: dirs
	docker stack deploy --compose-file=docker-stack.yml wt
	./run_worker.sh
	cid=$$(docker ps --filter=name=wt_girder -q);
	while [ -z $${cid} ] ; do \
		  echo $${cid} ; \
		  sleep 1 ; \
	    cid=$$(docker ps --filter=name=wt_girder -q) ; \
	done; \
	true
	./setup_girder.py

restart_girder:
	which jq || (echo "Please install jq to execute the 'restart_girder' make target" && exit 1)
	docker exec --user=root -ti $$(docker ps --filter=name=wt_girder -q) pip install -r /gwvolman/requirements.txt -e /gwvolman
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
                curl -XPUT -s 'http://localhost:8080/api/v1/system/restart' \
                        --header 'Content-Type: application/json' \
                        --header 'Accept: application/json' \
                        --header 'Content-Length: 0' \
                        --header "Girder-Token: $$(docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
                                curl 'http://localhost:8080/api/v1/user/authentication' \
                                --basic --user admin:arglebargle123 \
                                        | jq -r .authToken.token)"

restart_worker:
	docker exec --user=root -ti $$(docker ps --filter=name=wt_girder -q) pip install -e /gwvolman
	./stop_worker.sh && ./run_worker.sh

tail_girder_err:
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
		tail -n 200 /home/girder/.girder/logs/error.log

reset_girder:
	docker exec -ti $$(docker ps --filter=name=wt_girder -q) \
		python3 -c 'from girder.models import getDbConnection;getDbConnection().drop_database("girder")'

clean:
	-./stop_worker.sh
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
