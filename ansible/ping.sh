#!/bin/sh

HOST=$(terraform output | awk '{print $3}')
ansible all -i "${HOST}," -m ping -u ec2-user
