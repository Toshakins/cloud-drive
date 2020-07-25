#!/bin/sh

HOST=$(terraform output | awk '{print $3}')
ansible-playbook -i "${HOST}," -u ec2-user ansible/provision.yml
