export ANSIBLE_NOCOWS=1
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i production site.yml 

