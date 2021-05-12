#!/bin/bash
#Author: Anjan Dave
#Version: 1.3
printf "\n\tThis interactive script installs the CSI Driver v1.5. Try to run it once only as there's not a ton of logic built-in to check for already installed components if you re-run the script.\n"
printf "\n Do NOT use this script to Upgrade from previous version, the script does not have the logic for that, see upgrade steps listed below \n"
printf "\nPlease, do NOT use this to install a PRODUCTION environment, this is just to play with the CSI driver!!!!! \n"
printf "\nNOTE: We are only working with a k8s cluster with just master node, no workers \n"
printf "\nNOTE: We are going to install the CSI driver files in /root and as root\n"
printf "\nNOTE: Kubernetes 1.18 or 1.19 is expected, if you used my other scripts in the repo to install docker & kubernetes, you should be fine \n\n"
printf "\n If you're upgrading from v1.4 to v1.5, do the following:
1. stop all running application pods, clear all PVs and PVCs related to the CSI driver
2. uninstall the 1.4 driver (./csi-uninstall --namespace isilon)
3. remove default storageclass isilon (kubectl delete sc isilon)
4. remove secret isilon-creds - as v1.5 creates a new kind of it with same name (kubectl delete secret isilon-creds -n isilon)
5. You may try to use this script once above steps are done \n"
sleep 10 


function main
{


#Install GIT if not already done 
printf "Let's first check if git is installed, and if not we'll install it \n\n"
git version
sleep 3
if [ $? -eq 0 ]
then
	printf "Looks like git is installed, moving on\n\n"
else
	printf "Installing git...make sure you type yes if asked by yum\n"
	yum install git
fi


#Let's get the driver first. Using wget to get the driver. You could also use git clone if you'd like...command below.
#git clone https://github.com/dell/csi-powerscale.git
#Keep in mind, git cloning the CSI Driver works for the latest version only. 
printf "\nNext, we get the CSI driver, it will unzip in /root/csi-powerscale. \n"
sleep 4
cd /root
if [ -d "/root/csi-powerscale" ]
then
        printf "\nThe csi-powerscale directory exists already. If you want to install the driver using this script, rename that directory first, quitting...\n"
        sleep 3
	exit 0
else
        printf "\n We will use wget to grab the driver v1.4 package and unzip it in /root/csi-powerscale directory\n"
	wget https://github.com/dell/csi-powerscale/archive/refs/heads/release-1.5.0.zip /root/
	unzip release-1.5.0.zip
	mv csi-powerscale-release-1.5.0 /root/csi-powerscale
        printf "\nCheck below if you see the csi-powerscale directory listed\n"
        ls /root/csi-isilon
fi

sleep 4
printf "Next, we will download the docker.service configuration file from github. This avoids the step wherein you'd have to edit several files, which is error-prone process.\n\n"
printf "NOTE: The path for this file is based on where docker is installed. If you intalled docker using my scripts you're fine. Otherwise, if those paths are different for you, then hit ctrl+c NOW as we could fail. The paths for files we will work on are: \n"
printf "/etc/systemd/system/multi-user.target.wants/docker.service \n"
sleep 10


#We bkp existing files, no harm in repeating this step
printf "\nNext, we backup the existing files in /root/csi-bkp-files \n"
mydate=`date +%F`
/bin/mkdir -p /root/csi-bkp-files
cp /etc/systemd/system/multi-user.target.wants/docker.service /root/csi-bkp-files/docker.service.$mydate
printf "\nBackup of configuration files done, check below listing: \n"
ls -l /root/csi-bkp-files
sleep 4

printf "Now copying files from IsilonCSI_Driver_v1.4_Full_Installation to various paths \n"
cp /root/IsilonCSI_Driver_v1.5_Full_Installation/docker.service /etc/systemd/system/multi-user.target.wants/
printf "\nDone."


#No harm in restarting below items repeatedly, it just needs more sleep time afterwards to wait for PODs to come on
printf "\nNow restarting docker and kubernetes...waiting for 45 seconds to let everything settle\n\n"
systemctl daemon-reload
systemctl restart docker
#systemctl restart kubelet
sleep 45
echo ""


} #End of main function

#Call the main function defined above
main



printf "\nNext, we create the isilon & the test namespace in the k8s cluster \n"
kubectl create namespace isilon
kubectl create namespace test
sleep 4


printf "\n\nNext, we install helm3 - will download it in root home and will copy it into /usr/local/bin \n"
sleep 5
cd /root
wget https://get.helm.sh/helm-v3.5.2-linux-amd64.tar.gz
gunzip helm-v3.5.2-linux-amd64.tar.gz
tar -xvf helm-v3.5.2-linux-amd64.tar
cd linux-amd64/
cp helm /usr/local/bin/
helm list



#Below function is to handle the secret.yaml file mainly
function secretstuff
{

kubectl get secret -n isilon | grep isilon-creds
if [ $? -eq 0 ]
then
        printf "Looks like the secret is already created, skipping... \n"
        :
else
        printf "Let's edit the secret.json file first which is in /root/csi-powerscale/helm  \n"
        sleep 4
        printf "Enter Isilon username for CSI Driver (that has all the privs): \n"
        read isiuser
        printf "Enter the password for this account: \n"
        read isipasswd
        printf "Enter the cluster IP address for API calls: \n"
        read clusterip
        printf "Enter the name of the cluster: \n"
        read clustername

        sed -i 's/cluster1/'$clustername'/' /root/csi-powerscale/helm/secret.json
        sed -i 's/user/'$isiuser'/' /root/csi-powerscale/helm/secret.json
        sed -i 's/password/'$isipasswd'/' /root/csi-powerscale/helm/secret.json
        sed -i 's/1.2.3.4/'$clusterip'/' /root/csi-powerscale/helm/secret.json
        kubectl create secret generic isilon-creds -n isilon --from-file=config=/root/csi-powerscale/helm/secret.json
        printf "\n Below is the secret.yaml file, created in the cluster now:\n"
        kubectl get secret -n isilon | grep isilon-creds
        sleep 3

fi
} End of function secretstuff


#Call the secretstuff function defined above
secretstuff


printf "\n Now creating an empty secret as per official CSI driver instructions"
printf "\n Note, v1.5 creates a different secret name called isilon-certs-0"
kubectl create -f /root/csi-powerscale/helm/emptysecret.yaml


printf "We setup the secret isilon-creds earlier that has the cluster name, and cluster IP, so that is not needed in the valyes.yaml file now \n"
printf "\n For the next step, following should be ready
1. A path such as /ifs/blah/csi-volumes already created on cluster
2. No of controller PODs of driver (choose 1 if this is a single node cluster) \n"

printf "If you're ready with above things, type yes, otherwise no to quit: \n\n"
read ready
if [ $ready = yes ]
then
        :
else
        exit 0
fi


#Now copying values.yaml to myvalues.yaml
#Below will simply fail if you run this script more than once due to -n argument to cp
printf "\nCopying /root/csi-powerscale/helm/csi-isilon/values.yaml to /root/csi-powerscale/dell-csi-helm-installer/myvalues.yaml \n"
cp -n /root/csi-powerscale/helm/csi-isilon/values.yaml /root/csi-powerscale/dell-csi-helm-installer/myvalues.yaml
printf "\nDone.\n\n"
sleep 3

printf "Existing IP and Path parameters in the /root/csi-isilon/helm/myvalues.yaml are as shown below \n\n"
cat /root/csi-powerscale/dell-csi-helm-installer/myvalues.yaml | egrep "allowedNetworks|controllerCount:|isiPath"
echo ""

printf "\n\nDo you want to modify myvalues.yaml file? Asking because just in case you are running this script again? yes/no: \n"
read modifyans
if [ $modifyans = yes ]
then
	printf "Enter the export network of the Isilon cluster in 1.2.3.4/xx format: \n"
	read networkip
	printf "Enter the Isilon path (e.g. /ifs/cluster/csi) for CSI driver to create it's volumes THIS PATH MUST EXIST ON ISILON: \n"
	read isilonpath
	printf "How many controller PODs? - choose 1 if it's a single node cluster, otherwise type 2: \n"
	read contpods
	printf "Enforce nfsV3? - recommended, type ->true<-, otherwise type false make sure v4 is setup on the Isilon cluster: \n"
	read nfsversion
	sleep 4
	printf "Now changing the myvalues.yaml file for the IP and the path you supplied \n\n" 
	sed -i 's/allowedNetworks: []/allowedNetworks: ['$networkip']/' /root/csi-isilon/dell-csi-helm-installer/myvalues.yaml
	sed -i 's#/ifs/data/csi#'$isilonpath'#' /root/csi-isilon/dell-csi-helm-installer/myvalues.yaml
	sed -i 's#controllerCount: 2#controllerCount: '$contpods'#' /root/csi-isilon/dell-csi-helm-installer/myvalues.yaml
	sed -i 's#nfsV3: "true"#nfsV3: '$nfsversion'#' /root/csi-isilon/dell-csi-helm-installer/myvalues.yaml
	#printf "Now changing volumesnapshotclass.yaml file for the path \n"
	#sed -i 's#/ifs/data/csi#'$isilonpath'#' /root/csi-isilon/helm/volumesnapshotclass.yaml
	printf "\nCheck below if i changed the network and path correctly, else modify the /root/csi-isilon/helm/myvalues.yaml files by hand \n"
	cat /root/csi-isilon/dell-csi-helm-installer/myvalues.yaml | egrep "allowedNetworks|controllerCount:|isiPath"
	echo ""
	#cat /root/csi-isilon/helm/volumesnapshotclass.yaml | grep IsiPath
fi


printf "\nNext, applyin the snapshot-CRDs and controller\n"
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v3.0.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v3.0.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v3.0.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

printf "\nNext, applying the snapshot-controller \n"
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v3.0.2/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v3.0.2/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

sleep 10

#Last step - verify the kubernetes script that comes with the CSI Driver files we cloned in the beginning of script
#No problem in running the verify.kubernetes every time we're called upon, nothing changes
printf "\n\nModifying permissions to executable on /root/csi-isilon/dell-csi-helm-installer/verify.sh \n"
chmod 755 /root/csi-powerscale/dell-csi-helm-installer/*.sh


echo "----------------------------------------------------------------------"
printf "\n\nNext, we run the verify.sh script
You should get a successful verification message prior to installing the CSI Driver PODs \n"
echo "----------------------------------------------------------------------"
echo ""
sleep 3
/root/csi-powerscale/dell-csi-helm-installer/verify.sh --namespace isilon --values /root/csi-powerscale/dell-csi-helm-installer/myvalues.yaml


printf "\nBefore we install the driver, we will take the NoSchedule taint away from the master node - Continue? yes/no: "
read taintans
if [ $taintans = yes ]
then
	nodename=`kubectl get nodes --no-headers | awk '{print $1}'`
	kubectl taint nodes $nodename node-role.kubernetes.io/master-
fi


#Last step - install the CSI Driver!!!
printf "\nNext, and last step of this script is to run the csi-install.sh script that will install the 2 CSI Driver related pods \n"
printf "This step can take about a minute or two and it will run the verify.kubernetes script again, so supply the credentials for this host, twice\n"
sleep 8
printf "\nContinue? Type no if you have the driver running, obviously...yes/no: "
read csicontinue
if [ $csicontinue = yes ]
then
	cd /root/csi-powerscale/dell-csi-helm-installer
	chmod 755 csi-install.sh
	/root/csi-powerscale/dell-csi-helm-installer/csi-install.sh --namespace isilon --values /root/csi-powerscale/dell-csi-helm-installer/myvalues.yaml

else
exit 0
fi


echo ""
kubectl get pods -A
printf "\nIf you don't see the two PODS related to CSI Driver in isilon namespace in Running state, give it a couple of minutes \n"
printf "\nIf you DO see the two PODS in isilon name space in Running status, this completes the installation \n\n"
printf "Goodbye!\n"
