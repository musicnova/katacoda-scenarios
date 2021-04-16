Настройка CentOs 7

`
sudo yum -y install gem
`{execute}
```
```
`
sudo yum -y install java-1.8.0-openjdk-devel
`{execute}
```
```

`
sudo useradd -m -p $(perl -e 'print crypt($ARGV[0], "password")' 'YOUR_PASSWORD') mykafkauser
`{execute}

```
sudo useradd mykafkauser -m
```
`
sudo usermod -a -G wheel kafka
`{execute}
```
```
`
su -l kafka
`{execute}
```
```
`
mkdir ~/Downloads
`{execute}
```
```
`
curl "https://archive.apache.org/dist/kafka/2.1.1/kafka_2.11-2.1.1.tgz" -o ~/Downloads/kafka.tgz
`{execute}
```
```
`
mkdir ~/kafka && cd ~/kafka
`{execute}
```
```
`
tar -xvzf ~/Downloads/kafka.tgz --strip 1
`{execute}
```
```
`
cat < EOF >> ~/mykafkauser/config/server.properties

delete.topic.enable = true

EOF
`{execute}
```
```
`
exit
`{execute}
```
```
`
cat < EOF > /etc/systemd/system/zookeeper.service
[Unit]
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=simple
User=kafka
ExecStart=/home/kafka/kafka/bin/zookeeper-server-start.sh /home/kafka/kafka/config/zookeeper.properties
ExecStop=/home/kafka/kafka/bin/zookeeper-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target

EOF
`{execute}
```
```
`
vi /etc/systemd/system/kafka.service
`{execute}
```
```
`
cat < EOF >> /etc/systemd/system/kafka.service
[Unit]
Requires=zookeeper.service
After=zookeeper.service

[Service]
Type=simple
User=kafka
ExecStart=/bin/sh -c '/home/kafka/kafka/bin/kafka-server-start.sh /home/kafka/kafka/config/server.properties > /home/kafka/kafka/kafka.log 2>&1'
ExecStop=/home/kafka/kafka/bin/kafka-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target

EOF
`{execute}
```
```
`
systemctl start kafka
`{execute}
```
```
`
journalctl -u kafka
`{execute}
```
```
`
sudo systemctl enable kafka
`{execute}
```
```
`
su - mykafkauser
`{execute}
```
```
`
~/mykafkauser/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic TutorialTopic
`{execute}
```
```
`
echo "Hello, World" | ~/mykafkauser/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic TutorialTopic > /dev/null
`{execute}
```
```
`
sudo gem install kafkat
`{execute}
```
```
`
cat < EOF >> ~/.kafkatcfg
{
  "kafka_path": "~/kafka",
  "log_path": "/tmp/kafka-logs",
  "zk_path": "localhost:2181"
}

EOF
`{execute}
```
```
`
kafkat partitions
`{execute}
```

Output
Topic                 Partition   Leader      Replicas        ISRs    
TutorialTopic         0             0         [0]             [0]
__consumer_offsets    0             0         [0]                           [0]
...
...
```

