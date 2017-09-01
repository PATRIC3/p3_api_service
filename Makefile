TOP_DIR = ../..
DEPLOY_RUNTIME ?= /disks/patric-common/runtime
TARGET ?= /tmp/deployment
include $(TOP_DIR)/tools/Makefile.common

SERVICE_SPEC = 
SERVICE_NAME = p3_api_service
SERVICE_PORT = 3001
SERVICE_DIR  = $(SERVICE_NAME)
SERVICE_APP_DIR      = $(TARGET)/services/$(SERVICE_DIR)/app

APP_REPO     = https://github.com/PATRIC3/p3_api.git
APP_DIR      = p3_api
APP_SCRIPT   = ./bin/p3api-server
WORKER_SCRIPT   = ./bin/p3-index-worker
APP_VERSION  = master

PATH := $(DEPLOY_RUNTIME)/build-tools/bin:$(PATH)

CONFIG          = p3api.conf
CONFIG_TEMPLATE = $(CONFIG).tt

PRODUCTION = true
SOLR_URL = http://chestnut.mcs.anl.gov:8983/solr
WORKSPACE_API_URL = https://p3.theseed.org/services/Workspace
DISTRIBUTE_URL = http://localhost:3001/
ENABLE_INDEXER = false
JBROWSE_API_ROOT = https://www.beta.patricbrc.org/jbrowse
PUBLIC_GENOME_DIR = /vol/patric3/downloads/genomes
NUM_WORKERS = 4
CACHE_ENABLED = false

SERVICE_PSGI = $(SERVICE_NAME).psgi
TPAGE_ARGS = --define kb_runas_user=$(SERVICE_USER) \
	--define kb_top=$(TARGET) \
	--define kb_runtime=$(DEPLOY_RUNTIME) \
	--define kb_service_name=$(SERVICE_NAME) \
	--define kb_service_dir=$(SERVICE_DIR) \
	--define kb_service_port=$(SERVICE_PORT) \
	--define kb_psgi=$(SERVICE_PSGI) \
	--define kb_app_dir=$(SERVICE_APP_DIR) \
	--define kb_app_script=$(APP_SCRIPT) \
	--define kb_worker_script=$(WORKER_SCRIPT) \
	--define p3api_production=$(PRODUCTION) \
	--define p3api_service_port=$(SERVICE_PORT) \
	--define p3api_solr_url=$(SOLR_URL) \
	--define p3api_workspace_api_url=$(WORKSPACE_API_URL) \
	--define p3api_distribute_url=$(DISTRIBUTE_URL) \
	--define p3api_enable_indexer=$(ENABLE_INDEXER) \
	--define p3api_jbrowse_api_root=$(JBROWSE_API_ROOT) \
	--define p3api_public_genome_dir=$(PUBLIC_GENOME_DIR) \
	--define p3api_newrelic_license_key=$(NEWRELIC_LICENSE_KEY) \
	--define p3api_num_workers=$(NUM_WORKERS) \
	--define p3api_queue_directory=$(QUEUE_DIRECTORY) \
	--define p3api_cache_enabled=$(CACHE_ENABLED) \
	--define p3api_cache_directory=$(CACHE_DIRECTORY) 

# to wrap scripts and deploy them to $(TARGET)/bin using tools in
# the dev_container. right now, these vars are defined in
# Makefile.common, so it's redundant here.
TOOLS_DIR = $(TOP_DIR)/tools
WRAP_PERL_TOOL = wrap_perl
WRAP_PERL_SCRIPT = bash $(TOOLS_DIR)/$(WRAP_PERL_TOOL).sh
SRC_PERL = $(wildcard scripts/*.pl)


default: build-app build-config

build-app:
	if [ ! -f $(APP_DIR)/package.json ] ; then \
		git clone --recursive $(APP_REPO) $(APP_DIR); \
		if [ "$(APP_VERSION)" != "" ] ; then \
			(cd $(APP_DIR); git checkout $(APP_VERSION)  ) ; \
		fi \
	fi
	cd $(APP_DIR); npm install; npm install forever

dist: 

test: 

deploy: deploy-client deploy-service

deploy-all: deploy-client deploy-service

deploy-client: 

deploy-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib bash ; \
	for src in $(SRC_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done

deploy-service: deploy-run-scripts deploy-app deploy-config

deploy-app: build-app
	-mkdir $(SERVICE_APP_DIR)
	rsync --delete -arv $(APP_DIR)/. $(SERVICE_APP_DIR)

deploy-config: build-config
	$(TPAGE) $(TPAGE_ARGS) $(CONFIG_TEMPLATE) > $(SERVICE_APP_DIR)/$(CONFIG)

build-config:
	$(TPAGE) $(TPAGE_ARGS) $(CONFIG_TEMPLATE) > $(APP_DIR)/$(CONFIG)

deploy-run-scripts:
	mkdir -p $(TARGET)/services/$(SERVICE_DIR)
	
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERVICE_DIR)/start_service
	chmod +x $(TARGET)/services/$(SERVICE_DIR)/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERVICE_DIR)/stop_service
	chmod +x $(TARGET)/services/$(SERVICE_DIR)/stop_service
	
	$(TPAGE) $(TPAGE_ARGS) service/start_worker.tt > $(TARGET)/services/$(SERVICE_DIR)/start_worker
	chmod +x $(TARGET)/services/$(SERVICE_DIR)/start_worker
	$(TPAGE) $(TPAGE_ARGS) service/stop_worker.tt > $(TARGET)/services/$(SERVICE_DIR)/stop_worker
	chmod +x $(TARGET)/services/$(SERVICE_DIR)/stop_worker

	if [ -f service/upstart.tt ] ; then \
		$(TPAGE) $(TPAGE_ARGS) service/upstart.tt > service/$(SERVICE_NAME).conf; \
	fi
	echo "done executing deploy-service target"

deploy-upstart: deploy-service
	-cp service/$(SERVICE_NAME).conf /etc/init/
	echo "done executing deploy-upstart target"

deploy-cfg:

deploy-docs:
	-mkdir -p $(TARGET)/services/$(SERVICE_DIR)/webroot/.
	cp docs/*.html $(TARGET)/services/$(SERVICE_DIR)/webroot/.


build-libs:

include $(TOP_DIR)/tools/Makefile.common.rules
