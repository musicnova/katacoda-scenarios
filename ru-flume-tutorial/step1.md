Настройка Flume в CentOs 7


https://data-flair.training/blogs/apache-flume-installation-tutorial/


Введение
`
sudo useradd -m -p $(perl -e 'print crypt($ARGV[0], "password")' 'YOUR_PASSWORD') myprojectuser
`{{execute}}
```
```
`
sudo usermod -a -G sudo myprojectuser
`{{execute}}
```
```
`
su - myprojectuser
`{{execute}}

Apache Flume Installation Tutorial – A beginners guide
In this article, we will see how to install Apache Flume on Ubuntu. The article provides you the complete guide for installing Apache Flume 1.9.0 on Ubuntu. This article explains each step of the flume installation in detail along with the Screenshots. You will also know how to configure Flume for copying data into the Hadoop Distributed File System.

Let us now start with the step-by-step guide for Apache Flume installation.

Apache Flume Installation

Flume Installation Prerequisite
1. For installing Apache Flume we must have Hadoop installed and configured on our system.

2. Java must also be installed on your system.

If Hadoop is not installed on your system, then you can refer to the Hadoop 3 installation article to install Hadoop.

Step-by-step guide for Flume installation on Ubuntu
1. First we have to download Apache Flume 1.9.0. So let’s Download Apache Flume.

2. Locate the tar file that you have downloaded.

Unmute
Fullscreen
VDO.AI
.locating-flume-tar-flume-installation

3. Extract the tar file using the below command:
tar xzf apache-flume-1.9.0-bin.tar.gz

extract-flume-tar

Now we have successfully extracted apache-flume-1.9.0-bin.tar.gz. Use ls command to enlist files and directories.

viewing extracted files

4. Now we have to set the FLUME_HOME path in the .bashrc file. For this open .bashrc file in nano editor.

opening .bashrc file flume

Add below parameters in the .bashrc file.




export FLUME_HOME=/home/dataflair/apache-flume-1.9.0-bin
export PATH=$PATH:$FLUME_HOME/bin

adding flume directory path

Note: “/home/dataflair/apache-flume-1.9.0-bin” is the path of my Flume directory and apache-flume-1.9.0-bin is the name of my flume directory. You must provide the path where your flume directory is located.

Press Ctrl+O to save the changes and press Ctrl+X to exit.

5. Refresh the .bashrc file by using the below command:
source .bashrc

command to refresh .bashrc file

6. The flume has now successfully been installed on our system. To verify Flume installation use below command:
flume-ng version


