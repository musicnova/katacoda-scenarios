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
```

`
sudo usermod -a -G wheel mykafkauser
`{execute}

```
```

`
su -l mykafkauser
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
mkdir ~/mykafka && cd ~/mykafka
`{execute}

```
```

`
tar -xvzf ~/Downloads/kafka.tgz --strip 1
`{execute}

```
```

`
cat < EOF >> ~/mykafka/config/server.properties

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
ExecStart=/home/mykafkauser/mykafka/bin/zookeeper-server-start.sh /home/mykafkauser/mykafka/config/zookeeper.properties
ExecStop=/home/mykafkauser/mykafka/bin/zookeeper-server-stop.sh
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
ExecStart=/bin/sh -c '/home/mykafkauser/mykafka/bin/kafka-server-start.sh /home/mykafkauser/mykafka/config/server.properties > /home/mykafkauser/mykafka/kafka.log 2>&1'
ExecStop=/home/mykafkauser/mykafka/bin/kafka-server-stop.sh
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
~/mykafka/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic TutorialTopic
`{execute}

```
```

`
echo "Hello, World" | ~/mykafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic TutorialTopic > /dev/null
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
  "kafka_path": "~/mykafka",
  "log_path": "/tmp/mykafka-logs",
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
```
