#!/bin/bash
set -e
export PATH="/opt/puppet-omnibus/embedded/bin:/opt/local/bin:/sbin:/usr/sbin:$PATH"

set -x
if [ "$PKG_ITERATION" == "" ];then
  echo "PKG_ITERATION environment not set - producing debug build"
  export PKG_ITERATION=yelp-debug0
fi

if [ "$PUPPET_VERSION" == "" ];then
  echo "PUPPET_VERSION environment variable must be set"
  exit 1
fi
echo "Going for bundle install and build:"

export PUPPET_DASHVER=${PUPPET_VERSION//./-}
export PUPPET_BUILDPATH=/tmp/puppet.$PUPPET_DASHVER

cp -r /package_source/* /package/

# build puppet gem
ln -s /package/puppet-git $PUPPET_BUILDPATH # versioning here because of hardy
ls -la $PUPPET_BUILDPATH/
cd $PUPPET_BUILDPATH
patch lib/puppet/vendor/safe_yaml/lib/safe_yaml.rb < /tmp/safe_yaml.patch
#git checkout -q $PUPPET_VERSION
git init
git config --global user.email "you@example.com"
git add . ; git commit -m "sad"
git tag $PUPPET_VERSION -m "Something"
echo "Puppet version: $PUPPET_VERSION"
rake package:bootstrap
rake package:gem 
mv pkg/puppet-$PUPPET_VERSION.gem /package/vendor/

# build omnibus package
cd /package
gem install json_pure -v 2.5.1
gem install /package/vendor/puppet-$PUPPET_VERSION.gem

# Patch facter
mkdir /tmp/exo_facter ; cd /tmp/exo_facter
git clone https://github.com/exoscale/pkg-facter --branch=focal --depth=1
FACTER_RB=$(/opt/puppet-omnibus/embedded/bin/gem which facter)
cd ${FACTER_RB::-3} # strip .rb from facter path to get the folder
cd ../../
for i in 0002-Exclude-interfaces-facts.patch 0003-Exclude-ipaddress-facts.patch ; do
	patch -p1 < /tmp/exo_facter/pkg-facter/debian/patches/$i
done

cd /package
bundle install --local --path /tmp
FPM_CACHE_DIR=/package/vendor bundle exec fpm-cook clean
sed -i '/require "digest"/a require "zlib"' /tmp/ruby/2.7.0/gems/fpm-1.11.0/lib/fpm/package/deb.rb
FPM_CACHE_DIR=/package/vendor bundle exec fpm-cook package recipe.rb
echo "Copying package to the dist folder"
cp -v pkg/* /package_dest/
chown -R $EXT_UID:$EXT_GID /package_dest/*
echo "Package copying worked!"
exit 0
