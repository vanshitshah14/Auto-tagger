# Steps to deploy auto-tagger into the GCP project

### 1. Enable cloud resource manager API in the GCP project

### 2. Provide below mentioned permissions to Account which is gonna run Terraform

#### required Permissions
```
Cloud Run Admin
Eventarc Developer
Logging Admin
Project IAM Admin
Pub/Sub Editor
Role Administrator
Service Account Admin
Service Account User
```


### 3.  Open Cloud Shell in GCP project and clone the auto-tagger repository 
```
git clone https://github.com/vanshitshah14/Auto-tagger.git
```


### 4. change directory to Auto-tagger/
```
cd auto-tagger/
```

### 5. update all the variables related to project name and region in the var.tf file
```
nano var.tf
```

### 6. run the terraform command to deploy auto-tagger in the GCP project
```
terraform init
terraform plan
terraform apply
```


### 7. you can check from GCP console that auto-tagger will be deployed in Cloud run service

