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

## So what do we have here then ##

Working assumptions:  

* initial user is root
* the initial user has a password not a SSH key
* only tested on CentOS, although most of this will work on other distributions with minimal changes

Lets get started open group_vars/all and lets take a look at what's in there:  

* ansible_ssh_user - the user you wish to create, in this instance ansibler
* initial_ssh_user - default user, in this instance root

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

In my hypothetical example here I'm setting up a mailserver - I have a common role and a mail role. At the moment the mail server bits are not included in this example, however for fullness bits are - for example:

site.yml is the master yaml file it contains:

```YAML
---
# file: site.yml
- include: mailservers.yml
  gather_facts: False
```

Fact gathering is disabled, if you need facts, manually enable them for each set of tasks you wish to run.

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

And the meat of this is the tasks, the main task file calls two sub task files as follows:   

```YAML
---
# file: roles/common/tasks/main.yml

- include: initial_user.yml
  gather_facts: False 
  vars:
    normal_ssh_user: "{{ansible_ssh_user}}"
    normal_ssh_key: "{{normal_ssh_user}}_id.pub"
    ansible_ssh_user: "{{initial_ssh_user}}"
    ansible_ssh_pass: "{{initial_ssh_pass}}"


# Now continue to run tasks as the normal user rather than root
# from this point we log in as the normal user and disable SSH for root and lock it down

- include: secure.yml
  gather_facts: True
  remote_user: "{{ansible_ssh_user}}"
```

So what do we have here? 

The initial include turns of fact gathering, as we don't want the facts to run here, as they will try to run as the user - and this may not work, and would error. More details in a bit, but hold this in mind.

We pass in a few variables, we set a 'normal' ssh user and key. This is the user we want to connect to the box as ansibled in this case, but you can use what ever you want. Plus the name of the public SSH key that will be used by this user, this is in the common/files dir as {{normal_ssh_user}}_id.pub format in this case ansibler_id.pub.

The ansible defaults are then set from the initial values that are in the inventory, group_vars or host_vars locations.

The second task runs as the 'proper'/ansibler user and performs tasks as that user rather than initial/root user.

So what does initial_user.yml include?

```YAML
---
# file: roles/common/tasks/initial_user.yml

- name: test root access with pw
  local_action: shell sshpass -p '{{ansible_ssh_pass}}' ssh {{initial_ssh_user}}@{{ansible_ssh_host}} "echo success"
  ignore_errors: true
  register: initialuser

- name: ensure user group exists
  group: name={{normal_ssh_user}} state=present
  when: initialuser|success
  sudo: yes

- name: ensure normal_ssh_user created
  user: name={{normal_ssh_user}} groups={{normal_ssh_user}},wheel
  when: initialuser|success
  sudo: yes

- name: set ssh key for normal user
  authorized_key: user={{normal_ssh_user}} key="{{ lookup('file', normal_ssh_key ) }}"
  when: initialuser|success
  sudo: yes

- name: create sudoers file for user
  shell: "touch /etc/sudoers.d/{{normal_ssh_user}}"
  args:
    chdir: /etc/sudoers.d
    creates: "{{normal_ssh_user}}"
  when: initialuser|success
  sudo: yes

- name: add normal user password less sudo to their sudoers file
  lineinfile: >
    dest="/etc/sudoers.d/{{normal_ssh_user}}"
    state=present
    regexp='^#?{{ item.key }}'
    line='{{ item.key }} {{ item.value }}'
    validate='visudo -cf %s'
  with_items:
    - { key: "{{normal_ssh_user}}", value: 'ALL=(ALL) NOPASSWD: ALL' }
  when: initialuser|success
  sudo: yes

```

There's quite a lot going on here, so the general idea of this bit is to:  

* check to see if we can access the server with initial/root account and password

If we can:  

* create a user and group
* ensure the user has a sudoers file and password free sudo access

So how do we check:

```YAML
- name: test root access with pw
  local_action: shell sshpass -p '{{ansible_ssh_pass}}' ssh {{initial_ssh_user}}@{{ansible_ssh_host}} "echo success"
  ignore_errors: true
  register: initialuser
```

If we can connect then success is echoed which is stored into the register initaluser. This indicates the connection was open and the rest of the tasks should be run. If it errors, then it is ignored, but the initaluser register is not set to success.

The "when: initialuser|success" check ensures that the rest of the tasks are run when the condition is met.

The final task file, secure.yml, locks down SSH and disables root and password access:

```YAML
---
# file: roles/common/tasks/secure.yml

- name: Strict SSH access
  lineinfile: >
    dest=/etc/ssh/sshd_config
    state=present
    regexp='^#?{{ item.key }}'
    line='{{ item.key }} {{ item.value }}'
    validate='/usr/sbin/sshd -t -f %s'
  with_items:
    - { key: 'PermitRootLogin',        value: 'no'}
    - { key: 'PasswordAuthentication', value: 'no'}
    - { key: 'LoginGraceTime',         value: "60"}
    - { key: 'MaxSessions',            value: "5"}
    - { key: 'MaxStartups',            value: "10:30:60"}
  sudo: yes
  notify: restart sshd

- name: set servername
  hostname: name={{server_name}}
  sudo: yes
```

I hope this playbook is of some use to you.
