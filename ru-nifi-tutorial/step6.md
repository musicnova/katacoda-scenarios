To see all available commands, have a look at the [command reference](https://github.com/mesoshq/mesosctl#command-reference). 

For example, you can show the current leading Mesos master: `cluster get leader`{{execute}}

Or you can list the Marathon tasks: `marathon task list`{{execute}}

To show the actual Mesos tasks, you can do a `task list`{{execute}}. 

To dive into the Mesos sandbox's files, you can use a task id from the last step and do a  `task ls <taskId>`{{execute}} (where <taskId> is the real task id).