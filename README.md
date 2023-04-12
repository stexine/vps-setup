VPS Server Initial Setup Script
===

Description
---

 This script setups china gfw proxies, docker, webmin and certbot, configure sshd to use port 10012, webmin to use port 10011
 and open firewall ports for common server services. It works for Ubuntu 16.04 & 18.04

 steps:

 bbr: 2 -> no for kernel removeal -> restart 
 after reboot, rerun tcp.sh in /root and select 7 to activate bbrplus

