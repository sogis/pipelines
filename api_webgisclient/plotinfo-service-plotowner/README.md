# Additional Info for Plotinfo Service

The plotinfo Service needs a secret for the recaptcha keys.
You can find the secret template on H:\BJSVW\Agi\GDI\Betrieb\Openshift\Pipelines\recaptcha-plotinfo-secret.yaml

Create the secret with
```
oc project projectname
oc apply -f path_to_secret.yaml
```
