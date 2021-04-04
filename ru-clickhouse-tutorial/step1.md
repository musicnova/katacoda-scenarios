
How To Set Up a Ceph Cluster within Kubernetes Using Rook


Block StorageKubernetesDigitalOcean Volumes


https://www.digitalocean.com/community/tutorials/how-to-set-up-a-ceph-cluster-within-kubernetes-using-rook


Last Validated onMarch 10, 2021 Originally Published onAugust 6, 2020 27.4kviews
The author selected the Mozilla Foundation to receive a donation as part of the Write for DOnations program.

Introduction
Kubernetes containers are stateless as a core principle, but data must still be managed, preserved, and made accessible to other services. Stateless means that the container is running in isolation without any knowledge of past transactions, which makes it easy to replace, delete, or distribute the container. However, it also means that data will be lost for certain lifecycle events like restart or deletion.

Rook is a storage orchestration tool that provides a cloud-native, open source solution for a diverse set of storage providers. Rook uses the power of Kubernetes to turn a storage system into self-managing services that provide a seamless experience for saving Kubernetes application or deployment data.

Ceph is a highly scalable distributed-storage solution offering object, block, and file storage. Ceph clusters are designed to run on any hardware using the so-called CRUSH algorithm (Controlled Replication Under Scalable Hashing).

One main benefit of this deployment is that you get the highly scalable storage solution of Ceph without having to configure it manually using the Ceph command line, because Rook automatically handles it. Kubernetes applications can then mount block devices and filesystems from Rook to preserve and monitor their application data.

In this tutorial, you will set up a Ceph cluster using Rook and use it to persist data for a MongoDB database as an example.

Note: This guide should be used as an introduction to Rook Ceph and is not meant to be a production deployment with a large number of machines.

Prerequisites
Before you begin this guide, you’ll need the following:

A DigitalOcean Kubernetes cluster with at least three nodes that each have 2 vCPUs and 4 GB of Memory. To create a cluster on DigitalOcean and connect to it, see the Kubernetes Quickstart.
The kubectl command-line tool installed on a development server and configured to connect to your cluster. You can read more about installing kubectl in its official documentation.
A DigitalOcean block storage Volume with at least 100 GB for each node of the cluster you just created—for example, if you have three nodes you will need three Volumes. Select Manually Format rather than automatic and then attach your Volume to the Droplets in your node pool. You can follow the Volumes Quickstart to achieve this.
Step 1 — Setting up Rook
After completing the prerequisite, you have a fully functional Kubernetes cluster with three nodes and three Volumes—you’re now ready to set up Rook.

In this section, you will clone the Rook repository, deploy your first Rook operator on your Kubernetes cluster, and validate the given deployment status. A Rook operator is a container that automatically bootstraps the storage clusters and monitors the storage daemons to ensure the storage clusters are healthy.

Before you start deploying the needed Rook resources you first need to install the LVM package on all of your nodes as a prerequisite for Ceph. For that, you will create a Kubernetes DaemonSet that installs the LVM package on the node using apt. A DaemonSet is a deployment that runs one pod on each node.

First, you will create a YAML file:

nano lvm.yaml
 
The DaemonSet will define the container that will be executed on each of the nodes. Here you define a DaemonSet with a container running debian, which installs lvm2 using the apt command and then copies the installation files to the node using volumeMounts:

lvm.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
 name: lvm
 namespace: kube-system
spec:
 revisionHistoryLimit: 10
 selector:
   matchLabels:
     name: lvm
 template:
   metadata:
     labels:
       name: lvm
   spec:
     containers:
     - args:
       - apt -y update; apt -y install lvm2
       command:
       - /bin/sh
       - -c
       image: debian:10
       imagePullPolicy: IfNotPresent
       name: lvm
       securityContext:
         privileged: true
       volumeMounts:
       - mountPath: /etc
         name: etc
       - mountPath: /sbin
         name: sbin
       - mountPath: /usr
         name: usr
       - mountPath: /lib
         name: lib
     dnsPolicy: ClusterFirst
     restartPolicy: Always
     schedulerName: default-scheduler
     securityContext:
     volumes:
     - hostPath:
         path: /etc
         type: Directory
       name: etc
     - hostPath:
         path: /sbin
         type: Directory
       name: sbin
     - hostPath:
         path: /usr
         type: Directory
       name: usr
     - hostPath:
         path: /lib
         type: Directory
       name: lib
 
Now that the DaemonSet is configured correctly, it is time to apply it using the following command:

kubectl apply -f lvm.yaml
 
Now that all the prerequisites are met, you will clone the Rook repository, so you have all the resources needed to start setting up your Rook cluster:

git clone --single-branch --branch release-1.3 https://github.com/rook/rook.git
 
This command will clone the Rook repository from GitHub and create a folder with the name of rook in your directory. Now enter the directory using the following command:

cd rook/cluster/examples/kubernetes/ceph
 
Next you will continue by creating the common resources you needed for your Rook deployment, which you can do by deploying the Kubernetes config file that is available by default in the directory:

kubectl create -f common.yaml
 
The resources you’ve created are mainly CustomResourceDefinitions (CRDs) and define new resources that the operator will later use. They contain resources like the ServiceAccount, Role, RoleBinding, ClusterRole, and ClusterRoleBinding.

Note: This standard file assumes that you will deploy the Rook operator and all Ceph daemons in the same namespace. If you want to deploy the operator in a separate namespace, see the comments throughout the common.yaml file.

After the common resources are created, the next step is to create the Rook operator.

Before deploying the operator.yaml file, you will need to change the CSI_RBD_GRPC_METRICS_PORT variable because your DigitalOcean Kubernetes cluster already uses the standard port by default. Open the file with the following command:

nano operator.yaml
 
Then search for the CSI_RBD_GRPC_METRICS_PORT variable, uncomment it by removing the #, and change the value from port 9090 to 9093:

operator.yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: rook-ceph-operator-config
  namespace: rook-ceph
data:
  ROOK_CSI_ENABLE_CEPHFS: "true"
  ROOK_CSI_ENABLE_RBD: "true"
  ROOK_CSI_ENABLE_GRPC_METRICS: "true"
  CSI_ENABLE_SNAPSHOTTER: "true"
  CSI_FORCE_CEPHFS_KERNEL_CLIENT: "true"
  ROOK_CSI_ALLOW_UNSUPPORTED_VERSION: "false"
  # Configure CSI CSI Ceph FS grpc and liveness metrics port
  # CSI_CEPHFS_GRPC_METRICS_PORT: "9091"
  # CSI_CEPHFS_LIVENESS_METRICS_PORT: "9081"
  # Configure CSI RBD grpc and liveness metrics port
  CSI_RBD_GRPC_METRICS_PORT: "9093"
  # CSI_RBD_LIVENESS_METRICS_PORT: "9080"
 
Once you’re done, save and exit the file.

Next, you can deploy the operator using the following command:

kubectl create -f operator.yaml
 
The command will output the following:

Output
configmap/rook-ceph-operator-config created
deployment.apps/rook-ceph-operator created
Again, you’re using the kubectl create command with the -f flag to assign the file that you want to apply. It will take around a couple of seconds for the operator to be running. You can verify the status using the following command:

kubectl get pod -n rook-ceph
 
You use the -n flag to get the pods of a specific Kubernetes namespace (rook-ceph in this example).

Once the operator deployment is ready, it will trigger the creation of the DeamonSets that are in charge of creating the rook-discovery agents on each worker node of your cluster. You’ll receive output similar to:

Output
NAME                                  READY   STATUS    RESTARTS   AGE
rook-ceph-operator-599765ff49-fhbz9   1/1     Running   0          92s
rook-discover-6fhlb                   1/1     Running   0          55s
rook-discover-97kmz                   1/1     Running   0          55s
rook-discover-z5k2z                   1/1     Running   0          55s
You have successfully installed Rook and deployed your first operator. Next, you will create a Ceph cluster and verify that it is working.

Step 2 — Creating a Ceph Cluster
Now that you have successfully set up Rook on your Kubernetes cluster, you’ll continue by creating a Ceph cluster within the Kubernetes cluster and verifying its functionality.

First let’s review the most important Ceph components and their functionality:

Ceph Monitors, also known as MONs, are responsible for maintaining the maps of the cluster required for the Ceph daemons to coordinate with each other. There should always be more than one MON running to increase the reliability and availability of your storage service.
Ceph Managers, also known as MGRs, are runtime daemons responsible for keeping track of runtime metrics and the current state of your Ceph cluster. They run alongside your monitoring daemons (MONs) to provide additional monitoring and an interface to external monitoring and management systems.
Ceph Object Store Devices, also known as OSDs, are responsible for storing objects on a local file system and providing access to them over the network. These are usually tied to one physical disk of your cluster. Ceph clients interact with OSDs directly.
To interact with the data of your Ceph storage, a client will first make contact with the Ceph Monitors (MONs) to obtain the current version of the cluster map. The cluster map contains the data storage location as well as the cluster topology. The Ceph clients then use the cluster map to decide which OSD they need to interact with.

Rook enables Ceph storage to run on your Kubernetes cluster. All of these components are running in your Rook cluster and will directly interact with the Rook agents. This provides a more streamlined experience for administering your Ceph cluster by hiding Ceph components like placement groups and storage maps while still providing the options of advanced configurations.

Now that you have a better understanding of what Ceph is and how it is used in Rook, you will continue by setting up your Ceph cluster.

You can complete the setup by either running the example configuration, found in the examples directory of the Rook project, or by writing your own configuration. The example configuration is fine for most use cases and provides excellent documentation of optional parameters.

Now you’ll start the creation process of a Ceph cluster Kubernetes Object.

First, you need to create a YAML file:

nano cephcluster.yaml
 
The configuration defines how the Ceph cluster will be deployed. In this example, you will deploy three Ceph Monitors (MON) and enable the Ceph dashboard. The Ceph dashboard is out of scope for this tutorial, but you can use it later in your own individual project for visualizing the current status of your Ceph cluster.

Add the following content to define the apiVersion and the Kubernetes Object kind as well as the name and the namespace the Object should be deployed in:

cephcluster.yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
 
After that, add the spec key, which defines the model that Kubernetes will use to create your Ceph cluster. You’ll first define the image version you want to use and whether you allow unsupported Ceph versions or not:

cephcluster.yaml
spec:
  cephVersion:
    image: ceph/ceph:v14.2.8
    allowUnsupported: false
 
Then set the data directory where configuration files will be persisted using the dataDirHostPath key:

cephcluster.yaml
dataDirHostPath: /var/lib/rook
 
Next, you define if you want to skip upgrade checks and when you want to upgrade your cluster using the following parameters:

cephcluster.yaml
skipUpgradeChecks: false
continueUpgradeAfterChecksEvenIfNotHealthy: false
 
You configure the number of Ceph Monitors (MONs) using the mon key. You also allow the deployment of multiple MONs per node:

cephcluster.yaml
mon:
  count: 3
  allowMultiplePerNode: false
 
Options for the Ceph dashboard are defined under the dashboard key. This gives you options to enable the dashboard, customize the port, and prefix it when using a reverse proxy:

cephcluster.yaml
dashboard:
  enabled: true
  # serve the dashboard under a subpath (useful when you are accessing the dashboard via a reverse proxy)
  # urlPrefix: /ceph-dashboard
  # serve the dashboard at the given port.
  # port: 8443
  # serve the dashboard using SSL
  ssl: false
 
You can also enable monitoring of your cluster with the monitoring key (monitoring requires Prometheus to be pre-installed):

cephcluster.yaml
monitoring:
  enabled: false
  rulesNamespace: rook-ceph
 
RDB stands for RADOS (Reliable Autonomic Distributed Object Store) block device, which are thin-provisioned and resizable Ceph block devices that store data on multiple nodes.

RBD images can be asynchronously shared between two Ceph clusters by enabling rbdMirroring. Since we’re working with one cluster in this tutorial, this isn’t necessary. The number of workers is therefore set to 0:

cephcluster.yaml
rbdMirroring:
  workers: 0
 
You can enable the crash collector for the Ceph daemons:

cephcluster.yaml
crashCollector:
  disable: false
 
The cleanup policy is only important if you want to delete your cluster. That is why this option has to be left empty:

cephcluster.yaml
cleanupPolicy:
  deleteDataDirOnHosts: ""
removeOSDsIfOutAndSafeToRemove: false
 
The storage key lets you define the cluster level storage options; for example, which node and devices to use, the database size, and how many OSDs to create per device:

cephcluster.yaml
storage:
  useAllNodes: true
  useAllDevices: true
  config:
    # metadataDevice: "md0" # specify a non-rotational storage so ceph-volume will use it as block db device of bluestore.
    # databaseSizeMB: "1024" # uncomment if the disks are smaller than 100 GB
    # journalSizeMB: "1024"  # uncomment if the disks are 20 GB or smaller
 
You use the disruptionManagement key to manage daemon disruptions during upgrade or fencing:

cephcluster.yaml
disruptionManagement:
  managePodBudgets: false
  osdMaintenanceTimeout: 30
  manageMachineDisruptionBudgets: false
  machineDisruptionBudgetNamespace: openshift-machine-api
 
These configuration blocks will result in the final following file:

cephcluster.yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: ceph/ceph:v14.2.8
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  skipUpgradeChecks: false
  continueUpgradeAfterChecksEvenIfNotHealthy: false
  mon:
    count: 3
    allowMultiplePerNode: false
  dashboard:
    enabled: true
    # serve the dashboard under a subpath (useful when you are accessing the dashboard via a reverse proxy)
    # urlPrefix: /ceph-dashboard
    # serve the dashboard at the given port.
    # port: 8443
    # serve the dashboard using SSL
    ssl: false
  monitoring:
    enabled: false
    rulesNamespace: rook-ceph
  rbdMirroring:
    workers: 0
  crashCollector:
    disable: false
  cleanupPolicy:
    deleteDataDirOnHosts: ""
  removeOSDsIfOutAndSafeToRemove: false
  storage:
    useAllNodes: true
    useAllDevices: true
    config:
      # metadataDevice: "md0" # specify a non-rotational storage so ceph-volume will use it as block db device of bluestore.
      # databaseSizeMB: "1024" # uncomment if the disks are smaller than 100 GB
      # journalSizeMB: "1024"  # uncomment if the disks are 20 GB or smaller
  disruptionManagement:
    managePodBudgets: false
    osdMaintenanceTimeout: 30
    manageMachineDisruptionBudgets: false
    machineDisruptionBudgetNamespace: openshift-machine-api
 
Once you’re done, save and exit your file.

You can also customize your deployment by, for example changing your database size or defining a custom port for the dashboard. You can find more options for your cluster deployment in the cluster example of the Rook repository.

Next, apply this manifest in your Kubernetes cluster:

kubectl apply -f cephcluster.yaml
 
Now check that the pods are running:

kubectl get pod -n rook-ceph
 
This usually takes a couple of minutes, so just refresh until your output reflects something like the following:

Output
NAME                                                   READY   STATUS    RESTARTS   AGE
csi-cephfsplugin-lz6dn                                 3/3     Running   0          3m54s
csi-cephfsplugin-provisioner-674847b584-4j9jw          5/5     Running   0          3m54s
csi-cephfsplugin-provisioner-674847b584-h2cgl          5/5     Running   0          3m54s
csi-cephfsplugin-qbpnq                                 3/3     Running   0          3m54s
csi-cephfsplugin-qzsvr                                 3/3     Running   0          3m54s
csi-rbdplugin-kk9sw                                    3/3     Running   0          3m55s
csi-rbdplugin-l95f8                                    3/3     Running   0          3m55s
csi-rbdplugin-provisioner-64ccb796cf-8gjwv             6/6     Running   0          3m55s
csi-rbdplugin-provisioner-64ccb796cf-dhpwt             6/6     Running   0          3m55s
csi-rbdplugin-v4hk6                                    3/3     Running   0          3m55s
rook-ceph-crashcollector-pool-33zy7-68cdfb6bcf-9cfkn   1/1     Running   0          109s
rook-ceph-crashcollector-pool-33zyc-565559f7-7r6rt     1/1     Running   0          53s
rook-ceph-crashcollector-pool-33zym-749dcdc9df-w4xzl   1/1     Running   0          78s
rook-ceph-mgr-a-7fdf77cf8d-ppkwl                       1/1     Running   0          53s
rook-ceph-mon-a-97d9767c6-5ftfm                        1/1     Running   0          109s
rook-ceph-mon-b-9cb7bdb54-lhfkj                        1/1     Running   0          96s
rook-ceph-mon-c-786b9f7f4b-jdls4                       1/1     Running   0          78s
rook-ceph-operator-599765ff49-fhbz9                    1/1     Running   0          6m58s
rook-ceph-osd-prepare-pool-33zy7-c2hww                 1/1     Running   0          21s
rook-ceph-osd-prepare-pool-33zyc-szwsc                 1/1     Running   0          21s
rook-ceph-osd-prepare-pool-33zym-2p68b                 1/1     Running   0          21s
rook-discover-6fhlb                                    1/1     Running   0          6m21s
rook-discover-97kmz                                    1/1     Running   0          6m21s
rook-discover-z5k2z                                    1/1     Running   0          6m21s
You have now successfully set up your Ceph cluster and can continue by creating your first storage block.

Step 3 — Adding Block Storage
Block storage allows a single pod to mount storage. In this section, you will create a storage block that you can use later in your applications.

Before Ceph can provide storage to your cluster, you first need to create a storageclass and a cephblockpool. This will allow Kubernetes to interoperate with Rook when creating persistent volumes:

kubectl apply -f ./csi/rbd/storageclass.yaml
 
The command will output the following:

Output
cephblockpool.ceph.rook.io/replicapool created
storageclass.storage.k8s.io/rook-ceph-block created
Note: If you’ve deployed the Rook operator in a namespace other than rook-ceph you need to change the prefix in the provisioner to match the namespace you use.

After successfully deploying the storageclass and cephblockpool, you will continue by defining the PersistentVolumeClaim (PVC) for your application. A PersistentVolumeClaim is a resource used to request storage from your cluster.

For that, you first need to create a YAML file:

nano pvc-rook-ceph-block.yaml
 
Add the following for your PersistentVolumeClaim:

pvc-rook-ceph-block.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pvc
spec:
  storageClassName: rook-ceph-block
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
 
First, you need to set an apiVersion (v1 is the current stable version). Then you need to tell Kubernetes which type of resource you want to define using the kind key (PersistentVolumeClaim in this case).

The spec key defines the model that Kubernetes will use to create your PersistentVolumeClaim. Here you need to select the storage class you created earlier: rook-ceph-block. You can then define the access mode and limit the resources of the claim. ReadWriteOnce means the volume can only be mounted by a single node.

Now that you have defined the PersistentVolumeClaim, it is time to deploy it using the following command:

kubectl apply -f pvc-rook-ceph-block.yaml
 
You will receive the following output:

Output
persistentvolumeclaim/mongo-pvc created
You can now check the status of your PVC:

kubectl get pvc
 
When the PVC is bound, you are ready:

Output
NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
mongo-pvc   Bound    pvc-ec1ca7d1-d069-4d2a-9281-3d22c10b6570   5Gi        RWO            rook-ceph-block   16s
You have now successfully created a storage class and used it to create a PersistenVolumeClaim that you will mount to a application to persist data in the next section.

Step 4 — Creating a MongoDB Deployment with a rook-ceph-block
Now that you have successfully created a storage block and a persistent volume, you will put it to use by implementing it in a MongoDB application.

The configuration will contain a few things:

A single container deployment based on the latest version of the mongo image.
A persistent volume to preserve the data of the MongoDB database.
A service to expose the MongoDB port on port 31017 of every node so you can interact with it later.
First open the configuration file:

nano mongo.yaml
 
Start the manifest with the Deployment resource:

mongo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo
spec:
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
      - image: mongo:latest
        name: mongo
        ports:
        - containerPort: 27017
          name: mongo
        volumeMounts:
        - name: mongo-persistent-storage
          mountPath: /data/db
      volumes:
      - name: mongo-persistent-storage
        persistentVolumeClaim:
          claimName: mongo-pvc

...
 
For each resource in the manifest, you need to set an apiVersion. For deployments and services, use apiVersion: apps/v1, which is a stable version. Then, tell Kubernetes which resource you want to define using the kind key. Each definition should also have a name defined in metadata.name.

The spec section tells Kubernetes what the desired state of your final state of the deployment is. This definition requests that Kubernetes should create one pod with one replica.

Labels are key-value pairs that help you organize and cross-reference your Kubernetes resources. You can define them using metadata.labels and you can later search for them using selector.matchLabels.

The spec.template key defines the model that Kubernetes will use to create each of your pods. Here you will define the specifics of your pod’s deployment like the image name, container ports, and the volumes that should be mounted. The image will then automatically be pulled from an image registry by Kubernetes.

Here you will use the PersistentVolumeClaim you created earlier to persist the data of the /data/db directory of the pods. You can also specify extra information like environment variables that will help you with further customizing your deployment.

Next, add the following code to the file to define a Kubernetes Service that exposes the MongoDB port on port 31017 of every node in your cluster:

mongo.yaml
...

---
apiVersion: v1
kind: Service
metadata:
  name: mongo
  labels:
    app: mongo
spec:
  selector:
    app: mongo
  type: NodePort
  ports:
    - port: 27017
      nodePort: 31017
 
Here you also define an apiVersion, but instead of using the Deployment type, you define a Service. The service will receive connections on port 31017 and forward them to the pods’ port 27017, where you can then access the application.

The service uses NodePort as the service type, which will expose the Service on each Node’s IP at a static port between 30000 and 32767 (31017 in this case).

Now that you have defined the deployment, it is time to deploy it:

kubectl apply -f mongo.yaml
 
You will see the following output:

Output
deployment.apps/mongo created
service/mongo created
You can check the status of the deployment and service:

kubectl get svc,deployments
 
The output will be something like this:

Output
NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)           AGE
service/kubernetes   ClusterIP   10.245.0.1       <none>        443/TCP           33m
service/mongo        NodePort    10.245.124.118   <none>        27017:31017/TCP   4m50s

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/mongo   1/1     1            1           4m50s
After the deployment is ready, you can start saving data into your database. The easiest way to do so is by using the MongoDB shell, which is included in the MongoDB pod you just started. You can open it using kubectl.

For that you are going to need the name of the pod, which you can get using the following command:

kubectl get pods
 
The output will be similar to this:

Output
NAME                     READY   STATUS    RESTARTS   AGE
mongo-7654889675-mjcks   1/1     Running   0          13m
Now copy the name and use it in the exec command:

kubectl exec -it your_pod_name mongo
 
Now that you are in the MongoDB shell let’s continue by creating a database:

use test
 
The use command switches between databases or creates them if they don’t exist.

Output
switched to db test
Then insert some data into your new test database. You use the insertOne() method to insert a new document in the created database:

db.test.insertOne( {name: "test", number: 10  })
 
Output
{
    "acknowledged" : true,
    "insertedId" : ObjectId("5f22dd521ba9331d1a145a58")
}
The next step is retrieving the data to make sure it is saved, which can be done using the find command on your collection:

db.getCollection("test").find()
 
The output will be similar to this:

Output
NAME                     READY   STATUS    RESTARTS   AGE
{ "_id" : ObjectId("5f1b18e34e69b9726c984c51"), "name" : "test", "number" : 10 }
Now that you have saved some data into the database, it will be persisted in the underlying Ceph volume structure. One big advantage of this kind of deployment is the dynamic provisioning of the volume. Dynamic provisioning means that applications only need to request the storage and it will be automatically provided by Ceph instead of developers creating the storage manually by sending requests to their storage providers.

Let’s validate this functionality by restarting the pod and checking if the data is still there. You can do this by deleting the pod, because it will be restarted to fulfill the state defined in the deployment:

kubectl delete pod -l app=mongo
 
Now let’s validate that the data is still there by connecting to the MongoDB shell and printing out the data. For that you first need to get your pod’s name and then use the exec command to open the MongoDB shell:

kubectl get pods
 
The output will be similar to this:

Output
NAME                     READY   STATUS    RESTARTS   AGE
mongo-7654889675-mjcks   1/1     Running   0          13m
Now copy the name and use it in the exec command:

kubectl exec -it your_pod_name mongo
 
After that, you can retrieve the data by connecting to the database and printing the whole collection:

use test
db.getCollection("test").find()
 
The output will look similar to this:

Output
NAME                     READY   STATUS    RESTARTS   AGE
{ "_id" : ObjectId("5f1b18e34e69b9726c984c51"), "name" : "test", "number" : 10 }
As you can see the data you saved earlier is still in the database even though you restarted the pod. Now that you have successfully set up Rook and Ceph and used them to persist the data of your deployment, let’s review the Rook toolbox and what you can do with it.

Step 5 — Running the Rook Toolbox
The Rook Toolbox is a tool that helps you get the current state of your Ceph deployment and troubleshoot problems when they arise. It also allows you to change your Ceph configurations like enabling certain modules, creating users, or pools.

In this section, you will install the Rook Toolbox and use it to execute basic commands like getting the current Ceph status.

The toolbox can be started by deploying the toolbox.yaml file, which is in the examples/kubernetes/ceph directory:

kubectl apply -f toolbox.yaml
 
You will receive the following output:

Output
deployment.apps/rook-ceph-tools created
Now check that the pod is running:

kubectl -n rook-ceph get pod -l "app=rook-ceph-tools"
 
Your output will be similar to this:

Output
NAME                               READY   STATUS    RESTARTS   AGE
rook-ceph-tools-7c5bf67444-bmpxc   1/1     Running   0          9s
Once the pod is running you can connect to it using the kubectl exec command:

kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') bash
 
Let’s break this command down for better understanding:

The kubectl exec command lets you execute commands in a pod; like setting an environment variable or starting a service. Here you use it to open the BASH terminal in the pod. The command that you want to execute is defined at the end of the command.
You use the -n flag to specify the Kubernetes namespace the pod is running in.
The -i (interactive) and -t (tty) flags tell Kubernetes that you want to run the command in interactive mode with tty enabled. This lets you interact with the terminal you open.
$() lets you define an expression in your command. That means that the expression will be evaluated (executed) before the main command and the resulting value will then be passed to the main command as an argument. Here we define another Kubernetes command to get a pod where the label app=rook-ceph-tool and read the name of the pod using jsonpath. We then use the name as an argument for our first command.
Note: As already mentioned this command will open a terminal in the pod, so your prompt will change to reflect this.

Now that you are connected to the pod you can execute Ceph commands for checking the current status or troubleshooting error messages. For example the ceph status command will give you the current health status of your Ceph configuration and more information like the running MONs, the current running data pools, the available and used storage, and the current I/O operations:

ceph status
 
Here is the output of the command:

Output
  cluster:
    id:     71522dde-064d-4cf8-baec-2f19b6ae89bf
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum a,b,c (age 23h)
    mgr: a(active, since 23h)
    osd: 3 osds: 3 up (since 23h), 3 in (since 23h)

  data:
    pools:   1 pools, 32 pgs
    objects: 61 objects, 157 MiB
    usage:   3.4 GiB used, 297 GiB / 300 GiB avail
    pgs:     32 active+clean

  io:
    client:   5.3 KiB/s wr, 0 op/s rd, 0 op/s wr
You can also query the status of specific items like your OSDs using the following command:

ceph osd status
 
This will print information about your OSD like the used and available storage and the current state of the OSD:

Output
+----+------------+-------+-------+--------+---------+--------+---------+-----------+
| id |    host    |  used | avail | wr ops | wr data | rd ops | rd data |   state   |
+----+------------+-------+-------+--------+---------+--------+---------+-----------+
| 0  | node-3jis6 | 1165M | 98.8G |    0   |     0   |    0   |     0   | exists,up |
| 1  | node-3jisa | 1165M | 98.8G |    0   |  5734   |    0   |     0   | exists,up |
| 2  | node-3jise | 1165M | 98.8G |    0   |     0   |    0   |     0   | exists,up |
+----+------------+-------+-------+--------+---------+--------+---------+-----------+
More information about the available commands and how you can use them to debug your Ceph deployment can be found in the official documentation.

You have now successfully set up a complete Rook Ceph cluster on Kubernetes that helps you persist the data of your deployments and share their state between the different pods without having to use some kind of external storage or provision storage manually. You also learned how to start the Rook Toolbox and use it to debug and troubleshoot your Ceph deployment.

Conclusion
In this article, you configured your own Rook Ceph cluster on Kubernetes and used it to provide storage for a MongoDB application. You extracted useful terminology and became familiar with the essential concepts of Rook so you can customize your deployment.

If you are interested in learning more, consider checking out the official Rook documentation and the example configurations provided in the repository for more configuration options and parameters.

You can also try out the other kinds of storage Ceph provides like shared file systems if you want to mount the same volume to multiple pods at the same time.



Настройка Django с Postgres, Nginx и Gunicorn в Ubuntu 18.04


Nginx Python PostgreSQL Django Python Frameworks Ubuntu 18.04 Databases


https://www.digitalocean.com/community/tutorials/how-to-set-up-a-ceph-cluster-within-kubernetes-using-rook


Введение

Django — это мощная веб-система, помогающая создать приложение или сайт Python с нуля. Django включает упрощенный сервер разработки для локального тестирования кода, однако для серьезных производственных задач требуется более защищенный и мощный веб-сервер.

В этом руководстве мы покажем, как установить и настроить определенные компоненты Ubuntu 18.04 для поддержки и обслуживания приложений Django. Вначале мы создадим базу данных PostgreSQL вместо того, чтобы использовать базу данных по умолчанию SQLite. Мы настроим сервер приложений Gunicorn для взаимодействия с нашими приложениями. Затем мы настроим Nginx для работы в качестве обратного прокси-сервера Gunicorn, что даст нам доступ к функциям безопасности и повышения производительности для обслуживания наших приложений.

Предварительные требования и цели
Для прохождения этого обучающего модуля вам потребуется новый экземпляр сервера Ubuntu 18.04 с базовым брандмауэром и пользователем с привилегиями sudo и без привилегий root. Чтобы узнать, как настроить такой сервер, воспользуйтесь нашим модулем Руководство по начальной настройке сервера.

Мы будем устанавливать Django в виртуальной среде. Установка Django в отдельную среду проекта позволит отдельно обрабатывать проекты и их требования.

Когда база данных будет работать, мы выполним установку и настройку сервера приложений Gunicorn. Он послужит интерфейсом нашего приложения и будет обеспечивать преобразование запросов клиентов по протоколу HTTP в вызовы Python, которые наше приложение сможет обрабатывать. Затем мы настроим Nginx в качестве обратного прокси-сервера для Gunicorn, чтобы воспользоваться высокоэффективными механизмами обработки соединений и удобными функциями безопасности.

Давайте приступим.

Установка пакетов из хранилищ Ubuntu
Чтобы начать данную процедуру нужно загрузить и установить все необходимые нам элементы из хранилищ Ubuntu. Для установки дополнительных компонентов мы немного позднее используем диспетчер пакетов Python pip.

Нам нужно обновить локальный индекс пакетов apt, а затем загрузить и установить пакеты. Конкретный состав устанавливаемых пакетов зависит от того, какая версия Python будет использоваться в вашем проекте.

Если вы используете Django с Python 3, введите:
```
sudo apt update
sudo apt install python3-pip python3-dev libpq-dev postgresql postgresql-contrib nginx curl
```
Версия Django 1.11 — последняя версия Django с поддержкой Python 2. Если вы создаете новый проект, мы настоятельно рекомендуем использовать Python 3. Если вам необходимо использовать Python 2, введите:
```
sudo apt update
sudo apt install python-pip python-dev libpq-dev postgresql postgresql-contrib nginx curl
```
Эта команда устанавливает pip, файлы разработки Python для последующего построения сервера Gunicorn, СУБД Postgres и необходимые для взаимодействия с ней библиотеки, а также веб-сервер Nginx.

Создание базы данных и пользователя PostgreSQL
Вначале мы создадим базу данных и пользователя базы данных для нашего приложения Django.

По умолчанию Postgres использует для локальных соединений схему аутентификации «peer authentication». Это означает, что если имя пользователя операционной системы совпадает с действительным именем пользователя Postgres, этот пользователь может войти без дополнительной аутентификации.

Во время установки Postgres был создан пользователь операционной системы с именем postgres, соответствующий пользователю postgres базы данных PostgreSQL, имеющему права администратора. Этот пользователь нам потребуется для выполнения административных задач. Мы можем использовать sudo и передать это имя пользователя с опцией -u.

Выполните вход в интерактивный сеанс Postgres, введя следующую команду:
```
sudo -u postgres psql
```
Вы увидите диалог PostgreSQL, где можно будет задать наши требования.

Вначале создайте базу данных для своего проекта:
```
CREATE DATABASE myproject;
```
Примечание. Каждое выражение Postgres должно заканчиваться точкой с запятой. Если с вашей командой возникнут проблемы, проверьте это.

Затем создайте пользователя базы данных для нашего проекта. Обязательно выберите безопасный пароль:
```
CREATE USER myprojectuser WITH PASSWORD 'password';
```
Затем мы изменим несколько параметров подключения для только что созданного нами пользователя. Это ускорит работу базы данных, поскольку теперь при каждом подключении не нужно будет запрашивать и устанавливать корректные значения.

Мы зададим кодировку по умолчанию UTF-8, чего и ожидает Django. Также мы зададим схему изоляции транзакций по умолчанию «read committed», которая будет блокировать чтение со стороны неподтвержденных транзакций. В заключение мы зададим часовой пояс. По умолчанию наши проекты Django настроены на использование времени по Гринвичу (UTC). Все эти рекомендации взяты из проекта Django:
```
ALTER ROLE myprojectuser SET client_encoding TO 'utf8';
ALTER ROLE myprojectuser SET default_transaction_isolation TO 'read committed';
ALTER ROLE myprojectuser SET timezone TO 'UTC';
```
Теперь мы предоставим созданному пользователю доступ для администрирования новой базы данных:
```
GRANT ALL PRIVILEGES ON DATABASE myproject TO myprojectuser;
```
Завершив настройку, закройте диалог PostgreSQL с помощью следующей команды:
```
\q
```
Теперь настройка Postgres завершена, и Django может подключаться к базе данных и управлять своей информацией в базе данных.

Создание виртуальной среды Python для вашего проекта
Мы создали базу данных, и теперь можем перейти к остальным требованиям нашего проекта. Для удобства управления мы установим наши требования Python в виртуальной среде.

Для этого нам потребуется доступ к команде virtualenv. Для установки мы можем использовать pip.

Если вы используете Python 3, обновите pip и установите пакет с помощью следующей команды:
```
sudo -H pip3 install --upgrade pip
sudo -H pip3 install virtualenv
```
Если вы используете Python 2, обновите pip и установите пакет с помощью следующей команды:
```
sudo -H pip install --upgrade pip
sudo -H pip install virtualenv
```
После установки virtualenv мы можем начать формирование нашего проекта. Создайте каталог для файлов нашего проекта и перейдите в этот каталог:
```
mkdir ~/myprojectdir
cd ~/myprojectdir
```
Создайте в каталоге проекта виртуальную среду Python с помощью следующей команды:
```
virtualenv myprojectenv
```
Эта команда создаст каталог myprojectenv в каталоге myprojectdir. В этот каталог будут установлены локальная версия Python и локальная версия pip. Мы можем использовать эту команду для установки и настройки изолированной среды Python для нашего проекта.

Прежде чем установить требования Python для нашего проекта, необходимо активировать виртуальную среду. Для этого можно использовать следующую команду:
```
source myprojectenv/bin/activate
```
Командная строка изменится, показывая, что теперь вы работаете в виртуальной среде Python. Она будет выглядеть примерно следующим образом: (myprojectenv)user@host:~/myprojectdir$.

После запуска виртуальной среды установите Django, Gunicorn и адаптер psycopg2 PostgreSQL с помощью локального экземпляра pip:

Примечание. Если виртуальная среда активна (когда перед командной строкой стоит (myprojectenv)), необходимо использовать pip вместо pip3, даже если вы используете Python 3. Копия инструмента в виртуальной среде всегда имеет имя pip вне зависимости от версии Python.
```
pip install django gunicorn psycopg2-binary
```
Теперь у вас должно быть установлено все программное обеспечение, необходимое для запуска проекта Django.

Создание и настройка нового проекта Django
Установив компоненты Python, мы можем создать реальные файлы проекта Django.

Создание проекта Django
Поскольку у нас уже есть каталог проекта, мы укажем Django установить файлы в него. В этом каталоге будет создан каталог второго уровня с фактическим кодом (это нормально) и размещен скрипт управления. Здесь мы явно определяем каталог, а не даем Django принимать решения относительно текущего каталога:
```
django-admin.py startproject myproject ~/myprojectdir
```
Сейчас каталог вашего проекта (в нашем случае ~/myprojectdir) должен содержать следующее:

~/myprojectdir/manage.py: скрипт управления проектами Django.
~/myprojectdir/myproject/: пакет проекта Django. В нем должны содержаться файлы __init__.py, settings.py, urls.py и wsgi.py.
~/myprojectdir/myprojectenv/: виртуальный каталог, которы мы создали до этого.
Изменение настроек проекта
Прежде всего, необходимо изменить настройки созданных файлов проекта. Откройте файл настроек в текстовом редакторе:

nano ~/myprojectdir/myproject/settings.py

Найдите директиву ALLOWED_HOSTS. Она определяет список адресов сервера или доменных имен, которые можно использовать для подключения к экземпляру Django. Любой входящий запрос с заголовком Host, не включенный в этот список, будет вызывать исключение. Django требует, чтобы вы использовали эту настройку, чтобы предотвратить использование определенного класса уязвимости безопасности.

В квадратных скобках перечислите IP-адреса или доменные имена, связанные с вашим сервером Django. Каждый элемент должен быть указан в кавычках, отдельные записи должны быть разделены запятой. Если вы хотите включить в запрос весь домен и любые субдомены, добавьте точку перед началом записи. В следующем фрагменте кода для демонстрации в строках комментариев приведено несколько примеров:

Примечание. Обязательно используйте localhost как одну из опций, поскольку мы будем использовать локальный экземпляр Nginx как прокси-сервер.
```
~/myprojectdir/myproject/settings.py
. . .
# The simplest case: just add the domain name(s) and IP addresses of your Django server
# ALLOWED_HOSTS = [ 'example.com', '203.0.113.5']
# To respond to 'example.com' and any subdomains, start the domain with a dot
# ALLOWED_HOSTS = ['.example.com', '203.0.113.5']
ALLOWED_HOSTS = ['your_server_domain_or_IP', 'second_domain_or_IP', . . ., 'localhost']
```

```
ПРИМЕЧАНИЕ ПЕРЕВОДЧИКА - ПИШИТЕ ПРОСТО ALLOWED_HOSTS = [*] И НЕ УСЛОЖНЯЙТЕ СЕБЕ ЖИЗНЬ
```

Затем найдите раздел. который будет настраивать доступ к базе данных. Он будет начинаться со слова DATABASES. Конфигурация в файле предназначена для базы данных SQLite. Мы уже создали базу данных PostgreSQL для нашего проекта, и поэтому нужно изменить настройки.

Измените настройки, указав параметры базы данных PostgreSQL. Мы укажем Django использовать адаптер psycopg2, который мы установили вместе с pip. Нам нужно указать имя базы данных, имя пользователя базы данных, пароль пользователя базы данных, и указать, что база данных расположена на локальном компьютере. Вы можете оставить для параметра PORT пустую строку:
```
~/myprojectdir/myproject/settings.py
. . .

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'myproject',
        'USER': 'myprojectuser',
        'PASSWORD': 'password',
        'HOST': 'localhost',
        'PORT': '',
    }
}

. . .
```
Затем перейдите в конец файла и добавьте параметр, указывающий, где следует разместить статичные файлы. Это необходимо, чтобы Nginx мог обрабатывать запросы для этих элементов. Следующая строка указывает Django, что они помещаются в каталог static в базовом каталоге проекта:
```
~/myprojectdir/myproject/settings.py
. . .

STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'static/')
```
Сохраните файл и закройте его после завершения.

Завершение начальной настройки проекта
Теперь мы можем перенести начальную схему базы данных для нашей базы данных PostgreSQL, используя скрипт управления:
```
~/myprojectdir/manage.py makemigrations
~/myprojectdir/manage.py migrate
```
Создайте административного пользователя проекта с помощью следующей команды:
```
~/myprojectdir/manage.py createsuperuser
```
Вам нужно будет выбрать имя пользователя, указать адрес электронной почты, а затем задать и подтвердить пароль.

Мы можем собрать весь статичный контент в заданном каталоге с помощью следующей команды:
```
~/myprojectdir/manage.py collectstatic
```
Данную операцию нужно будет подтвердить. Статичные файлы будут помещены в каталог static в каталоге вашего проекта.

Если вы следовали указаниям модуля по начальной настройке сервера, ваш сервер должен защищать брандмауэр UFW. Чтобы протестировать сервер разработки, необходимо разрешить доступ к порту, который мы будем использовать.

Создайте исключение для порта 8000 с помощью следующей команды:
```
sudo ufw allow 8000
```
Теперь вы можете протестировать ваш проект, запустив сервер разработки Django с помощью следующей команды:
```
~/myprojectdir/manage.py runserver 0.0.0.0:8000
```
Откройте в браузере доменное имя или IP-адрес вашего сервера с суффиксом :8000:
```
http://server_domain_or_IP:8000
```
Вы увидите страницу индекса Django по умолчанию:

Страница индекса Django

Если вы добавите /admin в конце URL в панели адреса, вам будет предложено ввести имя пользователя и пароль администратора, созданные с помощью команды createsuperuser:

Вход в панель администратора Django

После аутентификации вы получите доступ к интерфейсу администрирования Django по умолчанию:

Интерфейс администрирования Django

Завершив изучение, нажмите CTRL+C в окне терминала, чтобы завершить работу сервера разработки.

Тестирование способности Gunicorn обслуживать проект
Перед выходом из виртуальной среды нужно протестировать способность Gunicorn обслуживать приложение. Для этого нам нужно войти в каталог нашего проекта и использовать gunicorn для загрузки модуля WSGI проекта:
```
cd ~/myprojectdir
gunicorn --bind 0.0.0.0:8000 myproject.wsgi
```
Gunicorn будет запущен на том же интерфейсе, на котором работал сервер разработки Django. Теперь вы можете вернуться и снова протестировать приложение.

Примечание. В интерфейсе администратора не будут применяться в стили, поскольку Gunicorn неизвестно, как находить требуемый статичный контент CSS.

Мы передали модуль в Gunicorn, указав относительный путь к файлу Django wsgi.py, который представляет собой точку входа в наше приложение. Для этого мы использовали синтаксис модуля Python. В этом файле определена функция application, которая используется для взаимодействия с приложением. Дополнительную информацию о спецификации WSGI можно найти здесь.

После завершения тестирования нажмите CTRL+C в окне терминала, чтобы остановить работу Gunicorn.

Мы завершили настройку нашего приложения Django. Теперь мы можем выйти из виртуальной среды с помощью следующей команды:
```
deactivate
```
Индикатор виртуальной среды будет убран из командной строки.

Создание файлов сокета и служебных файлов systemd для Gunicorn
Мы убедились, что Gunicorn может взаимодействовать с нашим приложением Django, но теперь нам нужно реализовать более надежный способ запуска и остановки сервера приложений. Для этого мы создадим служебные файлы и файлы сокета systemd.

Сокет Gunicorn создается при загрузке и прослушивает подключения. При подключении systemd автоматически запускает процесс Gunicorn для обработки подключения.

Создайте и откройте файл сокета systemd для Gunicorn с привилегиями sudo:
```
sudo nano /etc/systemd/system/gunicorn.socket
```
В этом файле мы создадим раздел [Unit] для описания сокета, раздел [Socket] для определения расположения сокета и раздел [Install], чтобы обеспечить установку сокета в нужное время:
```
/etc/systemd/system/gunicorn.socket
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.sock

[Install]
WantedBy=sockets.target
```
Сохраните файл и закройте его после завершения.

Теперь создайте и откройте служебный файл systemd для Gunicorn в текстовом редакторе с привилегиями sudo. Имя файла службы должно соответствовать имени файла сокета за исключением расширения:

sudo nano /etc/systemd/system/gunicorn.service

Начните с раздела [Unit], предназначенного для указания метаданных и зависимостей. Здесь мы разместим описание службы и предпишем системе инициализации запускать ее только после достижения сетевой цели: Поскольку наша служба использует сокет из файла сокета, нам потребуется директива Requires, чтобы задать это отношение:
```
/etc/systemd/system/gunicorn.service
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target
```
Теперь откроем раздел [Service]. Здесь указываются пользователь и группа, от имени которых мы хотим запустить данный процесс. Мы сделаем владельцем процесса учетную запись обычного пользователя, поскольку этот пользователь является владельцем всех соответствующих файлов. Групповым владельцем мы сделаем группу www-data, чтобы Nginx мог легко взаимодействовать с Gunicorn.

Затем мы составим карту рабочего каталога и зададим команду для запуска службы. В данном случае мы укажем полный путь к исполняемому файлу Gunicorn, установленному в нашей виртуальной среде. Мы привяжем процесс к сокету Unix, созданному в каталоге /run, чтобы процесс мог взаимодействовать с Nginx. Мы будем регистрировать все данные на стандартном выводе, чтобы процесс journald мог собирать журналы Gunicorn. Также здесь можно указать любые необязательные настройки Gunicorn. Например, в данном случае мы задали 3 рабочих процесса:
```
/etc/systemd/system/gunicorn.service
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
User=sammy
Group=www-data
WorkingDirectory=/home/sammy/myprojectdir
ExecStart=/home/sammy/myprojectdir/myprojectenv/bin/gunicorn \
          --access-logfile - \
          --workers 3 \
          --bind unix:/run/gunicorn.sock \
          myproject.wsgi:application
```
Наконец, добавим раздел [Install]. Это покажет systemd, куда привязывать эту службу, если мы активируем ее запуск при загрузке. Нам нужно, чтобы эта служба запускалась во время работы обычной многопользовательской системы:
```
/etc/systemd/system/gunicorn.service
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
User=sammy
Group=www-data
WorkingDirectory=/home/sammy/myprojectdir
ExecStart=/home/sammy/myprojectdir/myprojectenv/bin/gunicorn \
          --access-logfile - \
          --workers 3 \
          --bind unix:/run/gunicorn.sock \
          myproject.wsgi:application

[Install]
WantedBy=multi-user.target
```
Теперь служебный файл systemd готов. Сохраните и закройте его.

Теперь мы можем запустить и активировать сокет Gunicorn. Файл сокета /run/gunicorn.sock будет создан сейчас и будет создаваться при загрузке. При подключении к этому сокету systemd автоматически запустит gunicorn.service для его обработки:
```
sudo systemctl start gunicorn.socket
sudo systemctl enable gunicorn.socket
```
Успешность операции можно подтвердить, проверив файл сокета.

Проверка файла сокета Gunicorn
Проверьте состояние процесса, чтобы узнать, удалось ли его запустить:
```
sudo systemctl status gunicorn.socket
```
Затем проверьте наличие файла gunicorn.sock в каталоге /run:
```
file /run/gunicorn.sock

Output
/run/gunicorn.sock: socket
```
Если команда systemctl status указывает на ошибку, или если в каталоге отсутствует файл gunicorn.sock, это означает, что сокет Gunicorn не удалось создать. Проверьте журналы сокета Gunicorn с помощью следующей команды:
```
sudo journalctl -u gunicorn.socket
```
Еще раз проверьте файл /etc/systemd/system/gunicorn.socket и устраните любые обнаруженные проблемы, прежде чем продолжить.

Тестирование активации сокета
Если вы запустили только gunicorn.socket, служба gunicorn.service не будет активна в связи с отсутствием подключений к совету. Для проверки можно ввести следующую команду:
```
sudo systemctl status gunicorn
```
```
Output
● gunicorn.service - gunicorn daemon
   Loaded: loaded (/etc/systemd/system/gunicorn.service; disabled; vendor preset: enabled)
   Active: inactive (dead)
Чтобы протестировать механизм активации сокета, установим соединение с сокетом через curl с помощью следующей команды:
```
```
curl --unix-socket /run/gunicorn.sock localhost
```
Выводимые данные приложения должны отобразиться в терминале в формате HTML. Это показывает, что Gunicorn запущен и может обслуживать ваше приложение Django. Вы можете убедиться, что служба Gunicorn работает, с помощью следующей команды:
```
sudo systemctl status gunicorn
```
```
Output
● gunicorn.service - gunicorn daemon
   Loaded: loaded (/etc/systemd/system/gunicorn.service; disabled; vendor preset: enabled)
   Active: active (running) since Mon 2018-07-09 20:00:40 UTC; 4s ago
 Main PID: 1157 (gunicorn)
    Tasks: 4 (limit: 1153)
   CGroup: /system.slice/gunicorn.service
           ├─1157 /home/sammy/myprojectdir/myprojectenv/bin/python3 /home/sammy/myprojectdir/myprojectenv/bin/gunicorn --access-logfile - --workers 3 --bind unix:/run/gunicorn.sock myproject.wsgi:application
           ├─1178 /home/sammy/myprojectdir/myprojectenv/bin/python3 /home/sammy/myprojectdir/myprojectenv/bin/gunicorn --access-logfile - --workers 3 --bind unix:/run/gunicorn.sock myproject.wsgi:application
           ├─1180 /home/sammy/myprojectdir/myprojectenv/bin/python3 /home/sammy/myprojectdir/myprojectenv/bin/gunicorn --access-logfile - --workers 3 --bind unix:/run/gunicorn.sock myproject.wsgi:application
           └─1181 /home/sammy/myprojectdir/myprojectenv/bin/python3 /home/sammy/myprojectdir/myprojectenv/bin/gunicorn --access-logfile - --workers 3 --bind unix:/run/gunicorn.sock myproject.wsgi:application

Jul 09 20:00:40 django1 systemd[1]: Started gunicorn daemon.
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1157] [INFO] Starting gunicorn 19.9.0
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1157] [INFO] Listening at: unix:/run/gunicorn.sock (1157)
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1157] [INFO] Using worker: sync
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1178] [INFO] Booting worker with pid: 1178
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1180] [INFO] Booting worker with pid: 1180
Jul 09 20:00:40 django1 gunicorn[1157]: [2018-07-09 20:00:40 +0000] [1181] [INFO] Booting worker with pid: 1181
Jul 09 20:00:41 django1 gunicorn[1157]:  - - [09/Jul/2018:20:00:41 +0000] "GET / HTTP/1.1" 200 16348 "-" "curl/7.58.0"
```
Если результат вывода curl или systemctl status указывают на наличие проблемы, поищите в журналах более подробные данные:
```
sudo journalctl -u gunicorn
```
Проверьте файл /etc/systemd/system/gunicorn.service на наличие проблем. Если вы внесли изменения в файл /etc/systemd/system/gunicorn.service, перезагрузите демона, чтобы заново считать определение службы, и перезапустите процесс Gunicorn с помощью следующей команды:
```
sudo systemctl daemon-reload
sudo systemctl restart gunicorn
```
Обязательно устраните вышеперечисленные проблемы, прежде чем продолжить.

Настройка Nginx как прокси для Gunicorn
Мы настроили Gunicorn, и теперь нам нужно настроить Nginx для передачи трафика в процесс.

Для начала нужно создать и открыть новый серверный блок в каталоге Nginx sites-available:
```
sudo nano /etc/nginx/sites-available/myproject
```
Откройте внутри него новый серверный блок. Вначале мы укажем, что этот блок должен прослушивать обычный порт 80, и что он должен отвечать на доменное имя или IP-адрес нашего сервера:
```
/etc/nginx/sites-available/myproject
server {
    listen 80;
    server_name server_domain_or_IP;
}
```
Затем мы укажем Nginx игнорировать любые проблемы при поиске favicon. Также мы укажем, где можно найти статичные ресурсы, собранные нами в каталоге ~/myprojectdir/static. Все эти строки имеют стандартный префикс URI «/static», так что мы можем создать блок location для соответствия этим запросам:
```
/etc/nginx/sites-available/myproject
server {
    listen 80;
    server_name server_domain_or_IP;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root /home/sammy/myprojectdir;
    }
}
```
В заключение мы создадим блок location / {} для соответствия всем другим запросам. В этот блок мы включим стандартный файл proxy_params, входящий в комплект установки Nginx, и тогда трафик будет передаваться напрямую на сокет Gunicorn:
```
/etc/nginx/sites-available/myproject
server {
    listen 80;
    server_name server_domain_or_IP;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root /home/sammy/myprojectdir;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
```
Сохраните файл и закройте его после завершения. Теперь мы можем активировать файл, привязав его к каталогу sites-enabled:
```
sudo ln -s /etc/nginx/sites-available/myproject /etc/nginx/sites-enabled
```
Протестируйте конфигурацию Nginx на ошибки синтаксиса:
```
sudo nginx -t
```
Если ошибок не будет найдено, перезапустите Nginx с помощью следующей команды:
```
sudo systemctl restart nginx
```
Нам нужна возможность открыть брандмауэр для обычного трафика через порт 80. Поскольку нам больше не потребуется доступ к серверу разработки, мы можем удалить правило и открыть порт 8000:
```
sudo ufw delete allow 8000
sudo ufw allow 'Nginx Full'
```
Теперь у вас должна быть возможность перейти к домену или IP-адресу вашего сервера для просмотра вашего приложения.

Примечание. После настройки Nginx необходимо защитить трафик на сервер с помощью SSL/TLS. Это важно, поскольку в противном случае вся информация, включая пароли, будет отправляться через сеть в простом текстовом формате.

Если у вас имеется доменное имя, проще всего будет использовать Let’s Encrypt для получения сертификата SSL для защиты вашего трафика. Следуйте указаниям этого руководства, чтобы настроить Let’s Encrypt с Nginx в Ubuntu 18.04. Следуйте процедуре, используя серверный блок Nginx, созданный нами в этом обучающем модуле.

Если у вас нет доменного имени, вы можете защитить свой сайт для тестирования и обучения с помощью сертификата SSL с собственной подписью. Следуйте процедуре, используя серверный блок Nginx, созданный нами в этом обучающем модуле.

Диагностика и устранение неисправностей Nginx и Gunicorn
Если на последнем шаге не будет показано ваше приложение, вам нужно будет провести диагностику и устранение неисправностей установки.

Nginx показывает страницу по умолчанию, а не приложение Django
Если Nginx показывает страницу по умолчанию, а не выводит ваше приложение через прокси, это обычно означает, что вам нужно изменить параметр server_name в файле /etc/nginx/sites-available/myproject, чтобы он указывал на IP-адрес или доменное имя вашего сервера.

Nginx использует server_name, чтобы определять, какой серверный блок использовать для ответа на запросы. Если вы увидите страницу Nginx по умолчанию, это будет означать, что Nginx не может найти явное соответствие запросу в серверном блоке и выводит блок по умолчанию, заданный в /etc/nginx/sites-available/default.

Параметр server_name в серверном блоке вашего проекта должен быть более конкретным, чем содержащийся в серверном блоке, выбираемом по умолчанию.

Nginx выводит ошибку 502 Bad Gateway вместо приложения Django
Ошибка 502 означает, что Nginx не может выступать в качестве прокси для запроса. Ошибка 502 может сигнализировать о разнообразных проблемах конфигурации, поэтому для диагностики и устранения неисправности потребуется больше информации.

В первую очередь эту информацию следует искать в журналах ошибок Nginx. Обычно это указывает, какие условия вызвали проблемы во время прокси-обработки. Изучите журналы ошибок Nginx с помощью следующей команды:
```
sudo tail -F /var/log/nginx/error.log
```
Теперь выполните в браузере еще один запрос, чтобы получить свежее сообщение об ошибке (попробуйте обновить страницу). В журнал будет записано свежее сообщение об ошибке. Если вы изучите его, это поможет идентифицировать проблему.

Возможно вы увидите сообщение следующего вида:

connect() to unix:/run/gunicorn.sock failed (2: No such file or directory)

Это означает, что Nginx не удалось найти файл gunicorn.sock в указанном месте. Вы должны сравнить расположение proxy_pass, определенное в файле etc/nginx/sites-available/myproject, с фактическим расположением файла gunicorn.sock, сгенерированным блоком systemd gunicorn.socket.

Если вы не можете найти файл gunicorn.sock в каталоге /run, это означает, что файл сокета systemd не смог его создать. Вернитесь к разделу проверки файла сокета Gunicorn и выполните процедуру диагностики и устранения неисправностей Gunicorn.

connect() to unix:/run/gunicorn.sock failed (13: Permission denied)

Это означает, что Nginx не удалось подключиться к сокету Gunicorn из-за проблем с правами доступа. Это может произойти, если процедуру выполнять с привилегиями root, а не с привилегиями sudo. Хотя systemd может создать файл сокета Gunicorn, Nginx не может получить к нему доступ.

Это может произойти из-за ограничения прав доступа в любом месте между корневым каталогом (/) и файлом gunicorn.sock. Чтобы увидеть права доступа и владельцев файла сокета и всех его родительских каталогов, нужно ввести абсолютный путь файла сокета как параметр команды namei:
```
namei -l /run/gunicorn.sock
```
```
Output
f: /run/gunicorn.sock
drwxr-xr-x root root /
drwxr-xr-x root root run
srw-rw-rw- root root gunicorn.sock
```
Команда выведет права доступа всех компонентов каталога. Изучив права доступа (первый столбец), владельца (второй столбец) и группового владельца (третий столбец), мы можем определить, какой тип доступа разрешен для файла сокета.

В приведенном выше примере для файла сокета и каждого из каталогов пути к файлу сокета установлены всеобщие права доступа на чтение и исполнение (запись в столбце разрешений каталогов заканчивается на r-x, а не на ---). Процесс Nginx должен успешно получить доступ к сокету.

Если для любого из каталогов, ведущих к сокету, отсутствуют глобальные разрешения на чтение и исполнение, Nginx не сможет получить доступ к сокету без включения таких разрешений или без передачи группового владения группе, в которую входит Nginx.

Django выводит ошибку: «could not connect to server: Connection refused»
При попытке доступа к частям приложения через браузер Django может вывести сообщение следующего вида:

OperationalError at /admin/login/
could not connect to server: Connection refused
    Is the server running on host "localhost" (127.0.0.1) and accepting
    TCP/IP connections on port 5432?
Это означает, что Django не может подключиться к базе данных Postgres. Убедиться в нормальной работе экземпляра Postgres с помощью следующей команды:
```
sudo systemctl status postgresql
```
Если он работает некорректно, вы можете запустить его и включить автоматический запуск при загрузке (если эта настройка еще не задана) с помощью следующей команды:
```
sudo systemctl start postgresql
sudo systemctl enable postgresql
```
Если проблемы не исчезнут, проверьте правильность настроек базы данных, заданных в файле ~/myprojectdir/myproject/settings.py.

Дополнительная диагностика и устранение неисправностей
В случае обнаружения дополнительных проблем журналы могут помочь в поиске первопричин. Проверяйте их по очереди и ищите сообщения, указывающие на проблемные места.

Следующие журналы могут быть полезными:

Проверьте журналы процессов Nginx с помощью команды: sudo journalctl -u nginx
Проверьте журналы доступа Nginx с помощью команды: sudo less /var/log/nginx/access.log
Проверьте журналы ошибок Nginx с помощью команды: sudo less /var/log/nginx/error.log
Проверьте журналы приложения Gunicorn с помощью команды: sudo journalctl -u gunicorn
Проверьте журналы сокета Gunicorn с помощью команды: sudo journalctl -u gunicorn.socket
При обновлении конфигурации или приложения вам может понадобиться перезапустить процессы для адаптации к изменениям.

Если вы обновите свое приложение Django, вы можете перезапустить процесс Gunicorn для адаптации к изменениям с помощью следующей команды:
```
sudo systemctl restart gunicorn
```
Если вы измените файл сокета или служебные файлы Gunicorn, перезагрузите демона и перезапустите процесс с помощью следующей команды:
```
sudo systemctl daemon-reload
sudo systemctl restart gunicorn.socket gunicorn.service
```
Если вы измените конфигурацию серверного блока Nginx, протестируйте конфигурацию и Nginx с помощью следующей команды:
```
sudo nginx -t && sudo systemctl restart nginx
```
Эти команды помогают адаптироваться к изменениям в случае изменения конфигурации.

Заключение
В этом руководстве мы создали и настроили проект Django в его собственной виртуальной среде. Мы настроили Gunicorn для трансляции запросов клиентов, чтобы Django мог их обрабатывать. Затем мы настроили Nginx в качестве обратного прокси-сервера для обработки клиентских соединений и вывода проектов, соответствующих запросам клиентов.

Django упрощает создание проектов и приложений, предоставляя множество стандартных элементов и позволяя сосредоточиться на уникальных. Используя описанную в этой статье процедуру, вы сможете легко обслуживать создаваемые приложения на одном сервере.


If this is your first time using Django, you’ll have to take care of
some initial setup. Namely, you’ll need to auto-generate some code that
establishes a Django project – a collection of settings for an instance
of Django, including database configuration, Django-specific options and
application-specific settings.

From the command line run the following command:

```
$ django-admin startproject mysite
```

This will create a `mysite` directory in your current directory. If it
didn’t work, see [Problems running django-admin](https://docs.djangoproject.com/en/2.1/faq/troubleshooting/#troubleshooting-django-admin).

---

### Note

You’ll need to avoid naming projects after built-in Python or Django
components. In particular, this means you should avoid using names like
`django` (which will conflict with Django itself) or `test` (which
conflicts with a built-in Python package).

---

### Where should this code live?

If your background is in plain old PHP (with no use of modern
frameworks), you’re probably used to putting code under the Web server’s
document root (in a place such as `/var/www`). With Django, you don’t do
that. It’s not a good idea to put any of this Python code within your
Web server’s document root, because it risks the possibility that people
may be able to view your code over the Web. That’s not good for
security.

Put your code in some directory outside of the document root, such as
`/home/mycode`. For this tutorial, don't worry about the location.

---

Let’s look at what `startproject` created:

```
$ ls -R1 mysite
mysite/
    manage.py
    mysite/
        __init__.py
        settings.py
        urls.py
        wsgi.py
```

These files are:

- The outer `mysite/` root directory is just a container for your
  project. Its name doesn’t matter to Django; you can rename it to
  anything you like.
- `manage.py`: A command-line utility that lets you interact with this
  Django project in various ways. You can read all the details about
  `manage.py` in [`django-admin` and `manage.py`](https://docs.djangoproject.com/en/2.1/ref/django-admin/).
- The inner `mysite/` directory is the actual Python package for your
  project. Its name is the Python package name you’ll need to use to
  import anything inside it (e.g. `mysite.urls`).
- `mysite/__init__.py`: An empty file that tells Python that this
  directory should be considered a Python package. If you’re a Python
  beginner, read more about packages in the official Python docs.
- `mysite/settings.py`: Settings/configuration for this Django project.
  Django settings will tell you all about how settings work.
- `mysite/urls.py`: The URL declarations for this Django project; a
  "table of contents" of your Django-powered site. You can read more
  about URLs in URL dispatcher.
- `mysite/wsgi.py`: An entry-point for WSGI-compatible web servers to
  serve your project. See How to deploy with WSGI for more details.
