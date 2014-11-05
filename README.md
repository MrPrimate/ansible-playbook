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

_more to come_
