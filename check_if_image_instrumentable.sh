#!/bin/bash
# This script checks if the instrumentation of an image is supported
#
# Input: ImageId / Image name / Image SHA
#   Pull image
#        For rpm based images: docker run -i --rm  --user 0 --entrypoint=/bin/rpm <image id> -q glibc
#        For dpkg based images: docker run -i --rm  --user 0 --entrypoint=/usr/bin/dpkg <image  id> -s  libc6
#        For musl based images: docker run -i --rm  --user 0 --entrypoint=/sbin/apk <image id> version musl
#   Check if instrumentation of package supported 
#
# Pre-requisites:
#   - If the image to be instrumented is in registry and needs to be pulled, 
#     registry login should be performed on host prior to running the script
#

usage()
{
    echo "Usage:"
    echo "check_if_image_instrumentable.sh --help or -h <To print help message>"
    echo "check_if_image_instrumentable.sh <ImageID OR ImageName OR ImageSHA> (MANDATORY)"
}

print_usage_and_exit()
{
    usage
    if [[ $# -lt 1 ]]; then
        exit 1
    else
        exit $1
    fi
}

pullImage()
{
    docker pull $1
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Image pull failure. Aborting"
        exit 2
    fi
}

if [[ $# -lt 1 ]]; then
  echo "Insufficient arguments."
  echo "ImageID OR ImageName OR ImageSHA mandatory."
  echo ""
  print_usage_and_exit 0
fi

if [[ $# -gt 1 ]]; then
  echo "Extra arguments."
  echo "ImageID OR ImageName OR ImageSHA mandatory."
  echo ""
  print_usage_and_exit 0
fi

if [[ $1 == "--help" || $1 == "-h" ]]; then
    print_usage_and_exit
fi

image=$1
echo Image : ${image}

# Check image is in which format of the following:
# 1. Image ID - 7f335821efb5
# 2. Image RepoTag - centos:latest
# 3. Image SHA - sha256:438c429c905a252b96882d90d3e29de42a78f454eb4887775c9817be7361227d

imageFormat=0
dockerid_reg1="^([A-Za-z0-9]{12})"
dockerid_reg2="^([A-Za-z0-9]{64})"

if [[  $image =~ $dockerid_reg1 || $image =~ $dockerid_reg2 ]]; then
    # Image id
    imageFormat=1
fi

# Check if the image is locally present
if [ $imageFormat -ne 1 ]; then  
    if [[ "$(docker images -q  $image 2> /dev/null)" == "" ]]; then
        pullImage $image
    fi
elif [[ "$(docker image ls | grep $image)" == "" ]]; then
    pullImage $image
fi


# supported libc versions
supported_libc=(glibc-2.26-33.amzn2.0.1.x86_64.rpm* glibc-2.26-33.amzn2.0.2.x86_64.rpm* libc-bin_2.19-0ubuntu6.13_amd64.deb* libc-bin_2.19-0ubuntu6.14_amd64.deb* libc-bin_2.19-0ubuntu6.15_amd64.deb* libc-bin_2.19-0ubuntu6.6_amd64.deb* libc-bin_2.19-0ubuntu6.7_amd64.deb* libc-bin_2.19-0ubuntu6.9_amd64.deb* libc-bin_2.19-18+deb8u10_amd64.deb* libc-bin_2.19-18+deb8u6_amd64.deb* libc-bin_2.19-18+deb8u7_amd64.deb* libc-bin_2.23-0ubuntu10_amd64.deb* libc-bin_2.28-10.deb* libc-bin_2.23-0ubuntu11_amd64.deb* libc-bin_2.24-11+deb9u1_amd64.deb* libc-bin_2.24-11+deb9u3_amd64.deb* libc-bin_2.24-11+deb9u4_amd64.deb* libc-bin_2.27-3ubuntu1_amd64.deb* libc-bin_2.27-3ubuntu1.4_amd64.deb* libc-bin_2.27-3ubuntu1.2_amd64.deb* libc-bin_2.27-3ubuntu1.3_amd64.deb* musl-1.1.15-r8.apk* musl-1.1.16-r14.apk* musl-1.1.16-r15.apk* musl-1.1.18-r2.apk* musl-1.1.18-r3.apk* musl-1.1.19-r10.apk* musl-1.1.20-r3.apk* musl-1.1.20-r4.apk* musl-1.1.22-r3.apk* musl-1.1.24-r3.apk* musl-1.1.24-r9.apk* musl-1.1.24-r10.apk* musl-1.2.2-r0.apk*)

supported_centos_libc=(glibc-2.26-33.amzn2.0.1.x86_64.rpm* glibc-2.26-33.amzn2.0.2.x86_64.rpm* glibc-2.17-307.el7.1.x86_64.rpm glibc-2.28-72.el8.x86_64.rpm glibc-2.17-106.el7.x86_64.rpm glibc-2.26-32.amzn2.0.2.x86_64.rpm glibc-2.26-32.amzn2.0.1.x86_64.rpm glibc-2.17-292.el7.x86_64.rpm glibc-2.17-260.el7_6.6.x86_64.rpm glibc-2.17-222.el7.x86_64.rpm glibc-2.17-260.el7.x86_64.rpm glibc-2.17-260.el7_6.3.x86_64.rpm glibc-2.17-196.el7_4.2.x86_64.rpm glibc-2.17-196.el7.x86_64.rpm glibc-2.17-157.el7_3.1.x86_64.rpm glibc-2.17-106.el7_2.8.x86_64.rpm)

# Get OS details
echo -e 
echo "OS Details for $image -"
#echo $(docker run -i --rm $image /bin/cat /etc/os-release)
containrid=$(docker create $image)
#echo $containrid
var=$(docker cp  --follow-link $containrid:/etc/os-release os-file)
os=$(cat ./os-file)
rm -f ./os-file

echo $os

echo -e

echo "Checking if $image instrumentable -"
echo -e

# Check if RPM based package
if [[ "$os" =~ "centos" || "$os" =~ "fedora" ]]; then
    docker run -i --rm --user 0 --entrypoint=/bin/rpm $image rpm -q glibc
    result=$?
    if [ $result -eq 0 ]; then
        glibc_package=$(docker run -i --rm --user 0 --entrypoint=/bin/rpm $image rpm -qa glibc | grep glibc)
        echo glibc_package=$glibc_package
            if [[ "${supported_centos_libc[@]}" =~ .*"${glibc_package}".* ]]; then
                echo Result : $image can be instrumented
            else
                echo Result : $image instrumentation not supported
            fi
    fi
# Check if dpkg based package
elif [[ "$os" =~ "ubuntu" ]]; then
        docker run -i --rm  --user 0 --entrypoint=/usr/bin/dpkg $image -s libc6
        result=$?
        if [ $result -eq 0 ]; then
            libc_package=$(docker run -i --rm  --user 0 --entrypoint=/usr/bin/dpkg \
                                    $image -s libc6 | grep Version  | awk -F: '{print $2}')
            libc_package=$(echo $libc_package)
            echo libc_package : $libc_package
            if [[ "${supported_libc[@]}" =~ .*"${libc_package}".* ]]; then
                echo Result : $image can be instrumented
            else
                echo Result : $image instrumentation not supported
            fi
       fi
elif [[ "$os" =~ "debian" ]]; then
# check for debian/distroless images
	if [[ "$os" =~ "distroless" ]]; then
		docker cp --follow-link $containrid:/var/lib/dpkg/status.d/libc6 ./testlibc
		result=$?
		if [ $result -eq 0 ]; then
			libc_package=$(cat ./testlibc | grep Version  | awk -F: '{print $2}')
			rm -f ./testlibc
			libc_package=$(echo $libc_package)
			echo libc_package : $libc_package
		        if [[ "${supported_libc[@]}" =~ .*"${libc_package}".* ]]; then
				echo Result : $image can be instrumented
		        else
				echo Result : $image instrumentation not supported
			fi
		else
			docker cp --follow-link $containrid:/var/lib/dpkg/status.d/bGliYzY= ./testlibc
			result=$?
			if [ $result -eq 0 ]; then
				libc_package=$(cat ./testlibc | grep Version  | awk -F: '{print $2}')
				rm -f ./testlibc
				libc_package=$(echo $libc_package)
				echo libc_package : $libc_package
			        if [[ "${supported_libc[@]}" =~ .*"${libc_package}".* ]]; then
					echo Result : $image can be instrumented
			        else
					echo Result : $image instrumentation not supported
				fi
			fi
		fi
	else
	        docker run -i --rm  --user 0 --entrypoint=/usr/bin/dpkg $image -s libc6
		result=$?
	        if [ $result -eq 0 ]; then
			libc_package=$(docker run -i --rm  --user 0 --entrypoint=/usr/bin/dpkg \
						$image -s libc6 | grep Version  | awk -F: '{print $2}')
			libc_package=$(echo $libc_package)
			echo libc_package : $libc_package
			if [[ "${supported_libc[@]}" =~ .*"${libc_package}".* ]]; then
				echo Result : $image can be instrumented
			else
				echo Result : $image instrumentation not supported
			fi
		fi
	fi
elif [[ "$os" =~ "alpine" ]]; then
# Check if musl based package
            docker run -i --rm  --user 0 --entrypoint=/sbin/apk $image version musl
            result=$?
            if [ $result -eq 0 ]; then
                musl_package=$(docker run -i --rm  --user 0 --entrypoint=/sbin/apk $image version musl 2>/dev/null | grep musl- | awk -F' ' '{print $1}')
                musl_package=$(echo $musl_package)
                echo "musl package" : $musl_package
                if [[ "${supported_libc[@]}" =~ .*"${musl_package}".* ]]; then
                    echo Result : $image can be instrumented
                else
                    echo Result : $image instrumentation not supported
                fi
            fi
else
	echo "Results : Unsupported OS"
fi

var=$(docker rm -f $containrid)
