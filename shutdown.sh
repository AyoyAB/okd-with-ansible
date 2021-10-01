ansible -i hosts masters --become  -a "/usr/sbin/shutdown now"
ansible -i hosts nodes --become  -a "/usr/sbin/shutdown now"
