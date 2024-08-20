#!/bin/sh

HOST=$(terraform output | awk '{print $3}')
ANSIBLE_HOST_KEY_CHECKING=False ansible all -i "${HOST}," -m ping -u ec2-user
