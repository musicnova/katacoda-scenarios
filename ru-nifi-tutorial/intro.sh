echo '#!/bin/bash' > ~/mesosctl   
echo 'mkdir -p ~/.mesosctl' >> ~/mesosctl   
echo 'docker run --net=host -it -e MESOSCTL_CONFIGURATION_BASE_PATH=/config -v ~/apps:/apps -v ~/.mesosctl:/config:rw -v /home/core/.ssh:/home/core/.ssh docker.io/mesoshq/mesosctl:latest mesosctl' >> ~/mesosctl   
chmod +x ~/mesosctl   
mkdir -p ~/.mesosctl ~/apps   
echo 'cluster_name: Katacoda' >> ~/.mesosctl/config.yml   
echo 'os_family: CoreOS' >> ~/.mesosctl/config.yml   
echo 'os: CoreOS' >> ~/.mesosctl/config.yml   
echo 'ssh_key_path: /home/core/.ssh/id_rsa' >> ~/.mesosctl/config.yml   
echo 'ssh_port: 22' >> ~/.mesosctl/config.yml   
echo 'ssh_user: core' >> ~/.mesosctl/config.yml   
echo 'dns_servers:' >> ~/.mesosctl/config.yml   
echo ' - 8.8.8.8' >> ~/.mesosctl/config.yml   
echo ' - 8.8.4.4' >> ~/.mesosctl/config.yml   
echo 'masters:' >> ~/.mesosctl/config.yml   
echo ' - [[HOST2_IP]]' >> ~/.mesosctl/config.yml   
echo 'agents:' >> ~/.mesosctl/config.yml   
echo ' - [[HOST2_IP]]' >> ~/.mesosctl/config.yml   
echo 'registry:' >> ~/.mesosctl/config.yml   
echo ' - [[HOST2_IP]]' >> ~/.mesosctl/config.yml   
echo '{' > ~/apps/nginx.json   
echo ' "id": "nginx",' >> ~/apps/nginx.json   
echo ' "container": {' >> ~/apps/nginx.json   
echo ' "type": "DOCKER",' >> ~/apps/nginx.json   
echo ' "docker": {' >> ~/apps/nginx.json   
echo ' "image": "nginx:stable-alpine",' >> ~/apps/nginx.json   
echo ' "network": "BRIDGE",' >> ~/apps/nginx.json   
echo ' "portMappings": [' >> ~/apps/nginx.json   
echo ' { "hostPort": 31111, "containerPort": 80 }' >> ~/apps/nginx.json   
echo ' ]' >> ~/apps/nginx.json   
echo ' }' >> ~/apps/nginx.json   
echo ' },' >> ~/apps/nginx.json   
echo ' "instances": 1,' >> ~/apps/nginx.json   
echo ' "cpus": 0.1,' >> ~/apps/nginx.json   
echo ' "mem": 64,' >> ~/apps/nginx.json   
echo ' "healthChecks": [{' >> ~/apps/nginx.json   
echo ' "protocol": "HTTP",' >> ~/apps/nginx.json   
echo ' "path": "/",' >> ~/apps/nginx.json   
echo ' "portIndex": 0,' >> ~/apps/nginx.json   
echo ' "timeoutSeconds": 10,' >> ~/apps/nginx.json   
echo ' "gracePeriodSeconds": 10,' >> ~/apps/nginx.json   
echo ' "intervalSeconds": 2,' >> ~/apps/nginx.json   
echo ' "maxConsecutiveFailures": 10' >> ~/apps/nginx.json   
echo ' }]' >> ~/apps/nginx.json   
echo '}' >> ~/apps/nginx.json   
scp ~/mesosctl core@docker:~/   
scp core@docker:/home/core/.ssh/id_rsa   
ssh core@docker "mkdir -p ~/.mesosctl ~/apps"   
scp ~/.mesosctl/config.yml core@docker:~/.mesosctl/config.yml   
scp ~/apps/nginx.json core@docker:~/apps/nginx.json   
docker pull docker.io/mesoshq/mesosctl:latest
