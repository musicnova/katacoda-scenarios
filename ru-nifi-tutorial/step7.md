mesosctl supports DC/OS universe packages! Therefore, you have to install the repository locally:

`repository install`{{execute}}

You can later also update the repository's contents via `repository update`{{execute}}. 

Once you've installed the repository, you can use the `package` commands to for example search for or install a package. For example, if you want to search the repository for packages which are related to "web", you could issue the command `package search web`{{execute}}. This will give you a list of packages. 

If you're interested to learn more about a specific package, for example "nginx", you can run `package describe nginx`{{execute}}, which will show you the details of this package.

To actually install "nginx", do a `package install nginx`{{execute}}.


