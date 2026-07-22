#!/bin/sh

#move to script directory so all relative paths work
cd "$(dirname "$0")"

#includes
. ../config.sh
. ../environment.sh

#upgrade packages
apt update && apt upgrade -y

# install dependencies
apt install -y autoconf automake devscripts g++ git-core libncurses5-dev libtool libtool-bin make libjpeg-dev
apt install -y pkg-config flac  libgdbm-dev libdb-dev gettext sudo equivs git dpkg-dev libpq-dev
apt install -y liblua5.2-dev libtiff5-dev libperl-dev libcurl4-openssl-dev libsqlite3-dev libpcre3-dev
apt install -y devscripts libspeexdsp-dev libspeex-dev libldns-dev libedit-dev libopus-dev libmemcached-dev
apt install -y libshout3-dev libmpg123-dev libmp3lame-dev yasm nasm libsndfile1-dev libuv1-dev libvpx-dev
apt install -y libavformat-dev libswscale-dev libvlc-dev sox libsox-fmt-all
apt install -y libpcre3-dev libtiff5-dev

#install dependencies that depend on the operating system version
if [ ."$os_codename" = ."noble" ]; then
	apt install -y python3-distutils mlocate libvpx9 swig3.0
fi
if [ ."$os_codename" = ."stretch" ]; then
	apt install -y python3-distutils mlocate libvpx4 swig3.0
fi
if [ ."$os_codename" = ."buster" ]; then
	apt install -y python3-distutils mlocate libvpx5 swig3.0
fi
if [ ."$os_codename" = ."bullseye" ]; then
	apt install -y python3-distutils mlocate libvpx6 swig4.0
fi
if [ ."$os_codename" = ."trixie" ]; then
	apt install -y python3-distutils-extra plocate libtiff-dev libpcre2-dev swig
fi
if [ ."$os_codename" = ."bookworm" ]; then
	apt install -y libvpx7 swig4.0
fi

# additional dependencies
apt install -y sqlite3 unzip

# preserve the executing directory, so we need to return after we are done
CWD=$(pwd)

# install libks - dependency for switch versions greater than 1.10.0
if [ ! -d /usr/src/libks ]; then

	# libks build-requirements
	apt install -y cmake uuid-dev

	# libks
	cd /usr/src
	git clone https://github.com/signalwire/libks.git libks
	cd libks
	cmake .
	make -j $(getconf _NPROCESSORS_ONLN)
	make install

	# libks C includes
	export C_INCLUDE_PATH=/usr/include/libks
fi

# sofia-sip - dependency for switch versions greater than 1.10.0
if [ ! -d /usr/src/sofia-sip ]; then
	cd /usr/src
	rm -dfr sofia-sip
	if [ ."$sofia_version" = ."master" ]; then
		git clone https://github.com/freeswitch/sofia-sip.git sofia-sip
		cd sofia-sip
	elif [ ."$os_codename" = ."trixie" ]; then
		git clone https://github.com/freeswitch/sofia-sip.git sofia-sip
		cd sofia-sip
	else
		wget https://github.com/freeswitch/sofia-sip/archive/refs/tags/v$sofia_version.zip
		unzip v$sofia_version.zip
		mv sofia-sip-$sofia_version sofia-sip
		cd sofia-sip
	fi
	sh autogen.sh
	./configure --enable-debug
	make -j $(getconf _NPROCESSORS_ONLN)
	make install
fi

# spandsp - dependency for switch versions greater than 1.10.0
if [ ! -d /usr/src/spandsp ]; then
	cd /usr/src
	git clone https://github.com/freeswitch/spandsp.git spandsp
	cd spandsp
	if [ ."$sofia_version" != ."master" ]; then
		echo ""
	elif [ ."$os_codename" = ."trixie" ]; then
		echo ""
	else
		git reset --hard 0d2e6ac65e0e8f53d652665a743015a88bf048d4
	fi
	#/usr/bin/sed -i 's/AC_PREREQ(\[2\.71\])/AC_PREREQ([2.69])/g' /usr/src/spandsp/configure.ac
	sh autogen.sh
	./configure --enable-debug
	make -j $(getconf _NPROCESSORS_ONLN)
	make install
	ldconfig
fi

cd /usr/src

#check for master

#master branch
echo "Using version master"
rm -r /usr/src/freeswitch
git clone -b $switch_version-CORPIT https://github.com/yois615/freeswitch.git freeswitch-$switch_version
cd /usr/src/freeswitch-$switch_version
./bootstrap.sh -j


# enable required modules
#sed -i /usr/src/freeswitch/modules.conf -e s:'#applications/mod_avmd:applications/mod_avmd:'
sed -i modules.conf -e s:'#applications/mod_av:formats/mod_av:'
sed -i modules.conf -e s:'#applications/mod_callcenter:applications/mod_callcenter:'
sed -i modules.conf -e s:'#applications/mod_cidlookup:applications/mod_cidlookup:'
sed -i modules.conf -e s:'#applications/mod_memcache:applications/mod_memcache:'
sed -i modules.conf -e s:'#applications/mod_nibblebill:applications/mod_nibblebill:'
sed -i modules.conf -e s:'#applications/mod_curl:applications/mod_curl:'
sed -i modules.conf -e s:'#applications/mod_translate:applications/mod_translate:'
sed -i modules.conf -e s:'#formats/mod_shout:formats/mod_shout:'
sed -i modules.conf -e s:'#formats/mod_pgsql:formats/mod_pgsql:'
sed -i modules.conf -e s:'#say/mod_say_es:say/mod_say_es:'
sed -i modules.conf -e s:'#say/mod_say_fr:say/mod_say_fr:'

#disable module or install dependency libks to compile signalwire
sed -i modules.conf -e s:'applications/mod_signalwire:#applications/mod_signalwire:'
sed -i modules.conf -e s:'endpoints/mod_skinny:#endpoints/mod_skinny:'
sed -i modules.conf -e s:'endpoints/mod_verto:#endpoints/mod_verto:'

# prepare the build
#./configure --prefix=/usr/local/freeswitch --enable-core-pgsql-support --disable-fhs
./configure -C --enable-portable-binary --disable-dependency-tracking --enable-debug \
--prefix=/usr --localstatedir=/var --sysconfdir=/etc \
--with-openssl --enable-core-pgsql-support

# compile and install
make -j $(getconf _NPROCESSORS_ONLN)
make install

# create voicemail directory for installer
mkdir -p /var/lib/freeswitch/storage/voicemail

#return to the executing directory
cd $CWD
