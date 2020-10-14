# Pipeline for the SO!API and the Web GIS Client

## Use credentials from Openshift secrets in Pipeline

Necessary for credential use in Jenkins is the openshift-jenkins-sync-plugin (https://github.com/openshift/jenkins-sync-plugin)
In the Openshift Jenkins the plugin is activated by default.

For using Openshift Credentials in Jenkins (eg for a private Github repo) the following steps are needed:

* Create a secret in Openshift with password and username
```
apiVersion: v1
kind: Secret
metadata:
  name: github-secret
stringData:
  username: user1
  password: password1
```
* label the secret with credential.sync.jenkins.openshift.io=true
```
oc label secret github-secret credential.sync.jenkins.openshift.io=true
```
* Now the secret should be available in Jenkins as a global credential

For further information see https://docs.openshift.com/container-platform/3.11/using_images/other_images/jenkins.html#sync-plug-in

## First setup of the openshift environment

If you setup the environment for SO!API and Web GIS Client you must first create the necessary PVCs. Please use pvc_resources.yaml to create them. 
The Persistent volumes are not part of the pipeline because they are created by the AIO in the environment of the Canton of Solothurn. They are created as nfs storage and are immutable after creation.
Though in the pipeline oc apply would fail with an error.

## Adjustments in Jenkins and agi-apps to run the pipeline

Give jenkins service account edit access to the gdi environments
```
oc policy add-role-to-user edit system:serviceaccount:agi-apps-production:jenkins -n gdi-test
oc policy add-role-to-user edit system:serviceaccount:agi-apps-production:jenkins -n gdi-integration
oc policy add-role-to-user edit system:serviceaccount:agi-apps-production:jenkins -n gdi
```

Now the the jenkins service account of the project *agi-apps-production* has edit access to the three gdi environments test,int and prod

To run the pipeline you need aconfig-generator-agent in jenkins. Run the following commands to make the config-generator-agent available in jenkins.
Use name of the project where jenkins is running for *projectname* and the tag of the config generator agent image for *tag*
```
oc project agi-apps-test
oc process -f configMap-configGenAgent.yaml -p PROJECTNAME=projectname -p IMAGE_TAG_AGENT=tag | oc apply -f-
```
