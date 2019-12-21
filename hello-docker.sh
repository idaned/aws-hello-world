#! /bin/bash
# script for configuring docker in an offline server and running hello-world
# $1 = server internal ip
# $2 = ssh keypair

# while the instance is still creating..
while [[ `ping $1 -t 1 -c 1 | grep "+1 errors"` ]];do
	sleep 3;
done

# if the instance is created already, docker should be installed
if [ ! `ssh -o "StrictHostKeyChecking no" -i $2 ubuntu@$1 "which docker"` ]; then
  wget https://download.docker.com/linux/ubuntu/dists/bionic/pool/stable/amd64/docker-ce_18.03.1~ce~3-0~ubuntu_amd64.deb
  wget http://mirrors.kernel.org/ubuntu/pool/main/libt/libtool/libltdl7_2.4.6-0.1_amd64.deb
  sudo docker pull hello-world
  sudo docker save -o hello-world.docker hello-world
  
  scp -i $2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    docker-ce_18.03.1~ce~3-0~ubuntu_amd64.deb \
    libltdl7_2.4.6-0.1_amd64.deb \
    hello-world.docker \
    ubuntu@$1:/tmp/
  	
  ssh -i $2 ubuntu@$1 "sudo dpkg -i /tmp/libltdl7_2.4.6-0.1_amd64.deb && 
    sudo dpkg -i /tmp/docker-ce_18.03.1~ce~3-0~ubuntu_amd64.deb
  
  ssh -i $2 ubuntu@$1 "sudo docker load -i /tmp/hello-world.docker";
fi

# then run the hello-world container application :)
ssh -i $2 ubuntu@$1 "sudo docker run hello-world"
