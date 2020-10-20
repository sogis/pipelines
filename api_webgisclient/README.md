# Pipeline for SO!API and Web GIS Client

## First setup of the openshift environment

If you setup the environment for SO!API and Web GIS Client you must first create the necessary PVCs. Please use pvc_resources.yaml to create them. 
The Persistent volumes are not part of the pipeline because they are created by the AIO in the environment of the Canton of Solothurn. They are created as nfs storage and are immutable after creation.
Though in the pipeline oc apply would fail with an error.

## Adjustments in Jenkins and agi-apps to run the pipeline
All the subsequent mentioned commands create the objects in the test environment *agi-apps-test*. For other environments replace *agi-apps-test* in the commands.

### Give jenkins service account edit access to the gdi environments
```
oc policy add-role-to-user edit system:serviceaccount:agi-apps-test:jenkins -n gdi-test
oc policy add-role-to-user edit system:serviceaccount:agi-apps-test:jenkins -n gdi-integration
oc policy add-role-to-user edit system:serviceaccount:agi-apps-test:jenkins -n gdi
```

Now the the jenkins service account of the project *agi-apps-test* has edit access to the three gdi environments test,int and prod

### Install Config Generator Agent
To run the pipeline you need a config-generator-agent in jenkins. Run the following commands to make the config-generator-agent available in jenkins.
Use name of the project where jenkins is running for *projectname* and the tag of the config generator agent image for *tag*
```
oc project agi-apps-test
oc process -f template-configGenAgent.yaml -p PROJECTNAME=projectname -p IMAGE_TAG_AGENT=tag | oc apply -f-
```
The config-generator-agent pod requires a secret named config-generator-agent-pg-service. The secret definition is saved in H:\BJSVW\Agi\GDI\Betrieb\Openshift\Pipelines\secret-config-generator-agent-pg-service.yaml
Create the secret
```
oc project agi-apps-test
oc create -f secret-config-generator-agent-pg-service.yaml
```

### Upload the pipeline Jobs in Jenkins
Get the pipeline Jobs from https://github.com/sogis/jenkins and upload them in the jenkins pod
```
git clone https://github.com/sogis/jenkins.git
cd jenkins
oc project agi-apps-test
oc rsync jobs/ podname:/var/lib/jenkins/jobs/
```

### Create necessary Secrets for using as global credentials in Jenkins
Create the secrets in the same Openshift project where jenkins pod is running.
You can find all the secrets in H:\BJSVW\Agi\GDI\Betrieb\Openshift\Pipelines. Copy them in your local dir and run the following commands:
```
oc apply -f secret-jenkins-pw-imdas-db-user.yaml
oc apply -f secret-jenkins-pw-mswrite.yaml
oc apply -f secret-jenkins-pw-ogc-server.yaml
oc apply -f secret-jenkins-pw-report-server.yaml
oc apply -f secret-jenkins-pw-sogis-service.yaml
oc apply -f secret-jenkins-pw-sogis-service-write.yaml
```
Therefor the *secrets* can be used in Jenkins as *global credentials* they have to be labeled with *credential.sync.jenkins.openshift.io=true*
```
oc label secret pw-imdas-db-user credential.sync.jenkins.openshift.io=true
oc label secret pw-mswrite credential.sync.jenkins.openshift.io=true
oc label secret pw-ogc-server credential.sync.jenkins.openshift.io=true
oc label secret pw-report-server credential.sync.jenkins.openshift.io=true
oc label secret pw-sogis-service credential.sync.jenkins.openshift.io=true
oc label secret pw-sogis-service-write credential.sync.jenkins.openshift.io=true
```

**Every of these steps needs a restart of the jenkins pod**

### Activate 'Projektbasierte Matrix-Zugriffssteuerung'
To start a build of the  *WebGISClient* Job as anonymous user from outside the Jenkins Server via the API you have to do the following steps.
* Go to *Jenkins verwalten/Globale Sicherheit konfigurieren* activate *Projektbasierte Matrix-Zugriffssteuerung*.
* Then go to *WebGISClient/Konfigurieren* and activate *Projektbasierte Sicherheit aktivieren*
* Give *Anonymous Users* and *Authenticated Users* *Build* Access
* Go to *Benutzer/YourUserName/Einstellungen* and click *Add new Token*
* Name it with a descriptive name, for here we use exemplary *tokenName*, and click generate. Save the token in H:\BJSVW\Agi\KeePass\GDI_Passwort.kdbx
* Go to *WebGISClient/Konfigurieren/Build Triggers* and activate *Builds von ausserhalb starten*.
* In *Authentifizerungstoken* add the name of the generated Token.
* Now you could start the build with https://jenkins-agi-apps-test.dev.so.ch/job/WebGISClient/buildWithParameters?token=tokenName&build=ja&namespace=gdi-test&replicas=1&rolloutAll=nein

### Install and use of the Config Generator Agent

=> https://github.com/sogis/config-generator-jenkins-agent/blob/main/README.md
