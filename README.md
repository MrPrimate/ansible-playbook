ansible-playbook
================

Ansible playbook for provisioning cloud based CentOS machines.

I found several things that annoyed me, or found no clear explanation of when I started using Ansible. Here are some of the questions to help you out:  

I want to connect initially and:  

* change the hostname
* disable root user
* create my own user
* add a public key to my user
* lock down SSH a bit, maybe disable passwords via SSH
* I would like to run this playbook multiple times


One of the problems I found was that as the users change and the old, password based method becomes redundant, this playbook errors. How do I get around that? Well read on...

I imagine a lot of cloud system use various cloud-init scripts or other bits to maybe boot strap their servers into shape before the application provisioning begins. But say like me, your tight, your just messing around, and you want a VM for a few bucks a month, not a day. Well, they tend not to have such great provisioning support. You get a server, a user and a password.

Or maybe you want to use ansible on the more traditional server setup, or maybe you don't like cloud-init, or have reached its limitations. Well, I hear ya.

I have tried to organise the content as per <a href=http://docs.ansible.com/playbooks_best_practices.html>Ansible Best Practices</a>. 

==So what do we have here then==

Working assumptions:  

* initial user is root
* the intial user has a password not a SSH key
* only tested on CentOS, although most of this will work on other distributions with minimal changes

Lets get started open group_vars/all and lets take a look at whats in there:  

* ansible_ssh_user - the user you wish to create, in this instance ansibler
* initial_ssh_user - default user, in this instance roo

Typically we would have lists of servers in production, uat, dev etc - I have just production servers here, feel free to create your own inventory, or use a system to pull tehse variables. In production I have:  

```YAML
[mailservers]
alias ansible_ssh_host=90.xxx.xxx.XXX server_name=beta.example.come initial_ssh_pass=secretPass
```

In here I have an alias to use, typically this will be the same as the servername, but it might not be, the ansible_ssh_host is the IP address of the server, you cloud server may not have a DNS entry resolving to it, server_name will be used to set the server_name of the box, and initial_ssh_pass will be the root (in our example) users password. So it may look something like:

```YAML
[mailservers]
beta.example.com ansible_ssh_host=90.xxx.xxx.XXX server_name=beta.example.com initial_ssh_pass=secretPass
```
If you really wanted you could move most of these to host_vars/server_name (where server_name is the alias), if the password is consistent across all your servers, then you could add it to group_vars/all.

In my hypothetical example here I'm setting up a mailserver - I have a common role and a mail role. At the moment the mail server bits are not included in this example, however for fullnesss bits are - for example:

site.yml is the master yml file it contains:

```YAML
---
# file: site.yml
- include: mailservers.yml
```

mailservers.yml contains: 

```YAML
---
# file: mailservers.yml
- hosts: mailservers
  roles:
    - common
    - mail
```

You will note in my production file the example server is tagged in the mailservers group.

We have a single handler to restart sshd:

```YAML
---
# file: roles/common/handlers/main.yml
- name: restart sshd
  service: name=sshd state=restarted
  sudo: yes
```

And the meat of this is the tasks:  

```YAML

```

_more to come_
