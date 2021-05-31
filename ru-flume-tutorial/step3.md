Настройка CentOs 7


https://www.digitalocean.com/community/tutorials/how-to-install-hadoop-in-stand-alone-mode-on-ubuntu-18-04

https://gist.github.com/darcyliu/d47edccb923b0f03280a4cf8b66227c1

`
yum install java -y
`{execute}

```
```

`
wget http://downloads.typesafe.com/scala/2.11.7/scala-2.11.7.tgz
`{execute}

```
```

`
tar xvf scala-2.11.7.tgz
`{execute}

```
```

`
sudo mv scala-2.11.7 /usr/lib
`{execute}

```
```

`
sudo ln -s /usr/lib/scala-2.11.7 /usr/lib/scala
`{execute}

```
```

`
export PATH=$PATH:/usr/lib/scala/bin
`{execute}

```
```

`
scala -version
`{execute}

```
```

`
wget http://d3kbcqa49mib13.cloudfront.net/spark-1.6.0-bin-hadoop2.6.tgz
`{execute}

```
```

`
tar xvf spark-1.6.0-bin-hadoop2.6.tgz
`{execute}

```
```

`
export SPARK_HOME=$HOME/spark-1.6.0-bin-hadoop2.6
`{execute}

```
```

`
export PATH=$PATH:$SPARK_HOME/bin
`{execute}

```
```

`
firewall-cmd --permanent --zone=public --add-port=6066/tcp
`{execute}

```
```

`
firewall-cmd --permanent --zone=public --add-port=7077/tcp
`{execute}

```
```

`
firewall-cmd --permanent --zone=public --add-port=8080-8081/tcp
`{execute}

```
```

`
firewall-cmd --reload
`{execute}

```
```

`
echo 'export PATH=$PATH:/usr/lib/scala/bin' >> .bash_profile
`{execute}

```
```

`
echo 'export SPARK_HOME=$HOME/spark-1.6.0-bin-hadoop2.6' >> .bash_profile
`{execute}

```
```

`
echo 'export PATH=$PATH:$SPARK_HOME/bin' >> .bash_profile
`{execute}

```
```

