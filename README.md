## Generate Public Key

> ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

Name as your project and place in `~/.ssh`.

## Add key to ssh agent

> ssh-add ~/.ssh/private_key
