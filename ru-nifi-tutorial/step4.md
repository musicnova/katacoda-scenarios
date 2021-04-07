To provision the mesosctl "cluster" (which consists of one node in this default configuration), run `cluster provision --verbose`{{execute}}

This can take around 5-10 minutes, because the appropriate Docker images for the Mesos master and agent, as well as Marathon and Mesos DNS have to be downloaded. You'll probably see the "interruption" at the `Starting task registry : Copy pull_and_push.sh file` step. Please do not close the window.

After the provisioning is finished, you can query the cluster status with `cluster status`{{execute}} Please give Mesos DNS a few seconds to start serving queries as well.