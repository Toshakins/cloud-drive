## Generate Public Key

> ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

Name as your project and place in `~/.ssh`.

## Add key to ssh agent

> ssh-add ~/.ssh/private_key

## Install local dependencies

> pip install -r dev-requirements.txt

## Provision infrastructure

> terraform apply

## Connect

Use a SeaFile client to connect to the share.
