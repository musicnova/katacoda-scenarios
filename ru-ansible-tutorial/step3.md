Настройка NGINX в CentOs 7


https://www.digitalocean.com/community/tutorials/how-to-set-up-django-with-postgres-nginx-and-gunicorn-on-ubuntu-18-04-ru


https://www.katacoda.com/kennethlove/scenarios/django-tutorial


Step 1: Update the System


Update the system with the latest packages and security patches using these commands.


`ansible -m shell -a 'yum -y install nginx' server1`{execute}

```
```

Step 2: Install EPEL Repository

EPEL or Extra Packages for Enterprise Linux repository is a free and community based repository which provide many extra open source software packages which are not available in default YUM repository.

We need to install EPEL repository into the system as Ansible is available in default YUM repository is very old.

`echo sudo yum -y install epel-repo`{execute}

```
```

`
echo sudo yum -y install epel-repo
`{execute}
```
```

Update the repository cache by running the command.

`
sudo yum -y update
`{execute}
```
```

Step 3: Install Ansible

Run the following command to install the latest version of Ansible.

`
sudo yum -y install ansible
`{execute}
```
```

You can check if Ansible is installed successfully by finding its version.


`
ansible --version
`{execute}
```
```


Step 4: Testing Ansible (Optional)


Now that we have Ansible installed, let’s play around to see some basic uses of this software. This step is optional.


Consider that we have three different which we wish to manage using Ansible. In this example, I have created another three CentOS 7 cloud server with username root and password authentication. The IP address assigned to my cloud servers are


192.168.0.101
192.168.0.102
192.168.0.103


You can have less number of servers to test with.


Step 4.1 Generate SSH Key Pair


Although we can connect to remote hosts using a password through Ansible it is recommended to set up key-based authentication for easy and secure logins.


Generate an SSH key pair on your system by running the command.


`
ssh-keygen
`{execute}

```
[sneluser@host]$ ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/home/sneluser/.ssh/id_rsa):
Created directory '/home/sneluser/.ssh'.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/sneluser/.ssh/id_rsa.
Your public key has been saved in /home/sneluser/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:AAtQYpD0cuE0XyteDXvx55utFgDd1eQtKHsB4mvt+e4 sneluser@host.neetusuthar.com
The key's randomart image is:
+---[RSA 2048]----+
|**o+.  o..o . .oo|
|o.+.+o..=ooo o .o|
| . +.o.+.oo.o.. o|
|  o . o..o +o. . |
|     .  S o o.   |
|       . . o .+  |
|          o  o.. |
|           . ..  |
|           oE.   |
+----[SHA256]-----+
```

Step 4.2 Copy Public Key into Target Server


Now that our key pair is ready, we need to copy the public key into our target systems. Run the following command to copy the public key into the first server.


`
ssh-copy-id root@192.168.0.101
`{execute}
```
[sneluser@host]$ ssh-copy-id root@192.168.0.101
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/sneluser/.ssh/id_rsa.pub"
The authenticity of host '192.168.0.101 (192.168.0.101)' can't be established.
ECDSA key fingerprint is SHA256:d/D6NKU57CXaY4T3pnsIUycEPDv0Az2MiojBGjNj3+A.
ECDSA key fingerprint is MD5:5e:24:6a:13:99:e7:67:47:06:3e:2d:3e:97:d8:11:e7.
Are you sure you want to continue connecting (yes/no)? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@192.168.0.101's password:

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.0.101'"
and check to make sure that only the key(s) you wanted were added.
```

`
ssh root@192.168.0.101
`{execute}
```
```


It should log you in without asking for a password.


Repeat step 4.2 for all the remaining two hosts.


Step 4.3 Configure Ansible Hosts


By default, Ansible reads the host file from the location /etc/ansible/hosts. Open the hosts file into the editor.


`
sudo vi /etc/ansible/hosts
`{execute}

```
```

`
sudo cat /etc/ansible/hosts
`{execute}
```
[servers]
server1 ansible_host=192.168.0.101 ansible_user=root
server2 ansible_host=192.168.0.102 ansible_user=root
server3 ansible_host=192.168.0.103 ansible_user=root
{execute}
```


Save the file and exit from the editor.


Step 4.4 Connect using Ansible


We have done the minimal configuration required to connect to the remote machine using Ansible.


Run the following command to ping the host using Ansible ping module.


`
ansible -m ping all
`{execute}
```
[sneluser@host ~]$ ansible -m ping all
server1 | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}
server2 | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}
server3 | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}
```

`
ansible -m shell -a 'yum -y update' all
`

```
```

`
ansible -m shell -a 'yum -y update' server1
`{execute}

```
```

