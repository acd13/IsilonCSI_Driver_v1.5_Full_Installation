# IsilonCSI_Driver_v1.4_Full_Installation
#README
#Author: Anjan Dave
#Version: 1.0

Disclaimer:
Everything provided in this git repository is for non-production use. It's provided as-is, use it for getting the DellEMC Isilon CSI Driver installed and then run some tests. The goal of the script is to allow you to focus on the tests and not on the underlying docker/k8s functionality.

Pre-requisites for running the scripts:
----------------------------------------
1. Have a RHEL or CentOS 7.7 (7.x should be fine i have not tested other versions) with full install - i.e., install GNOME Desktop version with dev tools, admin tools, etc installed
2. If it's going to be a VM, make sure you have 3GB memory and 2 CPUs minimum allocated
3. Have an Isilon cluster ready (real or virtual), OneFS version - anything above 8.x would be good
4. Some kubernetes background would help if the script doesn't work for you as intended!
5. All this is valid for the Isilon CSI Driver 1.4 version only

There are three scripts provided here:
1. docker_install.sh
This script installs latest version of docker on the provided Linux host
2. install_k8s_1.19.sh
This script will install the Kubernetes 1.19.8 version for you which is what the Isilon CSI Driver currently supports
3. Install_Isilon_CSI_Driver_v1.4.sh
This script will install the Dell PowerScale CSI Driver v1.4

Procedure:
--------------
1. Login as root to your CentOS/RHEL 7.7 VM host
2. Install git (yum install git)
3. Make sure swap is off (vi /etc/hosts and swapoff -a)
4. Ensure your VM host name resolves to correct IP and make sure your Isilon cluster can revolve your kubernetes node name
5. cd /root
6. git clone https://github.com/acd13/IsilonCSI_Driver_v1.4_Full_Installation.git
7. cd IsilonCSI_Driver_v1.4_Full_Installation
8. cp *.sh /root/
9. chmod 755 *.sh
10. Install docker first: ./docker_install.sh (it's interactive script, complete it to get docker working)
11. Install Kubernetes next: ./install_k8s_1.19.sh (it's interactive script, compleete it to get kubernetes master node working at 1.19.8)
12. Install the CSI driver next: ./Install_Isilon_CSI_Driver_v1.4.sh (Follow the script prompts, or just decipher the commands and run them by hand)

Follow the official DellEMC Isilon CSI Driver 1.4 documentation at: https://github.com/dell/csi-isilon to download the offical installation guide. Note - this github page by default will always reflect the latest driver version, which as of 4/13/2021 is v1.5
