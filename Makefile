PUPPET_GIT    := $(or ${upstream_puppet_git},"https://github.com/exoscale/pkg-puppet")
VERSION       := $(or ${puppet_version},"3.8.5")
ITERATION     := $(or ${puppet_vendor_version},y7)
PACKAGE_NAME  := "puppet-omnibus"
PKG_ITERATION := exo5
EXOSCALE_DOCKER_REGISTRY ?= "registry.internal.exoscale.ch"

.PHONY: dist docker itest package clean

require_os:
	if [ -z "$(OS)" ]; then \
		echo "OS is not set, aborting"; \
		exit 1; \
	fi

dist: require_os
	mkdir -p pkg
	mkdir -p dist/$(OS)
	chmod 777 pkg dist/$(OS)

puppet_git:
	if [ -d puppet-git ] && [ -d puppet-git/.git ]; then \
		cd puppet-git;                                     \
		git clean -fdx;                                    \
		git remote set-url origin $(PUPPET_GIT);           \
		git fetch origin;                                  \
	else                                                 \
		rm -rf puppet-git;                                 \
		git clone $(PUPPET_GIT) puppet-git;                \
	fi

#puppet_exo:
#	[ -d puppet-git ] && rm -rf puppet-git 
#	wget -c https://github.com/exoscale/pkg-puppet/raw/focal/puppet_3.8.5.orig.tar.gz
#	mkdir puppet-git
#	tar -xf puppet_3.8.5.orig.tar.gz --strip-components=1 -C puppet-git
#	sed -i "s/packaging_url.*/packaging_url: \'https:\/\/github.com\/puppetlabs\/packaging.git --branch=0.99.30'/" puppet-git/ext/build_defaults.yaml

puppet_exo:
	[ -d puppet-git ] && rm -rf puppet-git || true
	[ -d pkg-puppet ] && rm -rf pkg-puppet || true
	git clone https://github.com/exoscale/pkg-puppet --branch=focal --depth=1
	mkdir puppet-git
	tar -xf pkg-puppet/puppet_3.8.5.orig.tar.gz --strip-components=1 -C puppet-git
	sed -i "s/packaging_url.*/packaging_url: \'https:\/\/github.com\/puppetlabs\/packaging.git --branch=0.99.30'/" puppet-git/ext/build_defaults.yaml
	cd puppet-git ; for i in $$(ls -1 ../pkg-puppet/debian/patches | grep -v series) ; do patch -p1 < ../pkg-puppet/debian/patches/$$i ; done

docker: require_os
	flock /tmp/puppet_omnibus_$(OS)_docker_build.lock \
	docker build -f Dockerfile.$(OS) -t package_puppet_omnibus_$(OS) --build-arg EXOSCALE_DOCKER_REGISTRY=$(DOCKER_REGISTRY) .

package: require_os dist puppet_exo docker
	docker run \
	  -e PKG_ITERATION=$(PKG_ITERATION) \
	  -e PUPPET_VERSION=$(VERSION) \
	  -e PUPPET_BASE=$(VERSION) \
	  -e HOME=/package \
	  -e EXT_UID=`id -u` \
	  -e EXT_GID=`id -g` \
	  -v `pwd`:/package_source:ro \
	  -v `pwd`/dist/$(OS):/package_dest:rw \
	  -v /etc/ssh/ssh_known_hosts:/etc/ssh/ssh_known_hosts:ro \
	  package_puppet_omnibus_$(OS) \
	  /package_source/JENKINS_BUILD.sh

itest: require_os package
	docker run \
		-v `pwd`/itest:/itest:ro \
		-v `pwd`/dist:/dist:ro \
		docker-dev.yelpcorp.com/$(OS)_yelp \
		/itest/ubuntu.sh \
		/dist/$(OS)/$(PACKAGE_NAME)_$(VERSION)-$(PKG_ITERATION)_amd64.deb \
		$(VERSION)

clean:
	rm -rf dist/ cache/ pkg/

itest_%:
	OS=$* make itest

jammy_package:
	OS=jammy make package
