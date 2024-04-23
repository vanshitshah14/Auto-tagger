provider "google" {
  project= var.project_id
  region = var.region
  zone = var.zone
}
data "google_project" "project" {
}




#enable iam api
resource "google_project_service" "iam_api_enable" {
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

  

#enable pubsub api
resource "google_project_service" "pubsub_api_enable" {
  service = "pubsub.googleapis.com"
  disable_on_destroy = false
}


#enable sql admin api
resource "google_project_service" "sql_api_enable" {
  service = "sqladmin.googleapis.com"
  disable_on_destroy = false
}




#enable cloud run api
resource "google_project_service" "run_api_enable" {
  service = "run.googleapis.com"
  disable_on_destroy = false
}

resource "time_sleep" "wait_5_seconds" {
  create_duration = "5s"
  depends_on = [google_project_service.run_api_enable]
}



#enable eventarc api
resource "google_project_service" "eventarc_api_enable" {
  service = "eventarc.googleapis.com"
  disable_on_destroy = false
  depends_on = [time_sleep.wait_5_seconds]
}

resource "time_sleep" "wait_5_seconds_2" {
  create_duration = "15s"
  depends_on = [google_project_service.eventarc_api_enable]
}

#create custom IAM role 
resource "google_project_iam_custom_role" "autotagger_custom_role" {
  role_id     = "autotaggerrr"
  title       = "auto-taggerrr"
  permissions = ["iam.serviceAccounts.actAs", "run.services.get","run.services.update","cloudsql.instances.get","cloudsql.instances.update","bigquery.datasets.get", "bigquery.datasets.update", "bigquery.tables.get", "bigquery.tables.update", "cloudfunctions.functions.get", "cloudfunctions.functions.update", "compute.instances.get", "compute.instances.setLabels", "compute.instances.setMetadata", "compute.instances.update", "eventarc.events.receiveAuditLogWritten", "eventarc.events.receiveEvent", "storage.buckets.get", "storage.buckets.update", "storage.objects.get", "storage.objects.update"]
  depends_on = [time_sleep.wait_5_seconds_2]
}

#create Service Account 
resource "google_service_account" "autotagger_service_account" {
  account_id   = "autotaggerrr"
  display_name = "Service Account for auto-tagger" 
  depends_on = [google_project_iam_custom_role.autotagger_custom_role]
}

#Attaching custom role to service account
resource "google_project_iam_binding" "mservice_infra_binding" {
  project = data.google_project.project.project_id
  role = "projects/${data.google_project.project.project_id}/roles/${google_project_iam_custom_role.autotagger_custom_role.role_id}"

  members = [
    "serviceAccount:${google_service_account.autotagger_service_account.email}",
  ]
  depends_on = [google_service_account.autotagger_service_account]
}

#deploy cloud run 
resource "google_cloud_run_service" "cloudrun" {
  name = "auto-tagger"
  location = var.region

  template {
   spec {
       containers {
           image = var.image 
           env {
             name= "project_name"
             value = var.project_id
           }
           ports {
           container_port = 5000
           }
       }
       service_account_name = google_service_account.autotagger_service_account.email
   } 
  }
  autogenerate_revision_name = true

  traffic {
    percent  = 100
    latest_revision = true
  }

  metadata {
    
    labels = {
      creator=var.creator
      org=var.org
    }
    annotations ={
      "run.googleapis.com/ingress" = "internal"
    }
    
  }
  depends_on = [google_service_account.autotagger_service_account]
}


#create vm trigger 
resource "google_eventarc_trigger" "vm_trigger" {
  name = "ce"
  location = "global"
  matching_criteria {
    attribute = "type"
    value = "google.cloud.audit.log.v1.written"
    
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "compute.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "beta.compute.instances.insert"
  }
  destination {
    cloud_run_service{
        service = google_cloud_run_service.cloudrun.name
        region = var.region
        path = "/ce_eventarc_trigger"
    }
  }

  labels = {
    creator=var.creator
    org=var.org
  }
  service_account = google_service_account.autotagger_service_account.email
}

#create bq dataset trigger 
resource "google_eventarc_trigger" "dataset_trigger" {
  name = "dataset"
  location = "global"
  matching_criteria {
    attribute = "type"
    value = "google.cloud.audit.log.v1.written"
    
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "bigquery.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "google.cloud.bigquery.v2.DatasetService.InsertDataset"
  }
  destination {
    cloud_run_service{
        service = google_cloud_run_service.cloudrun.name
        region = var.region
        path = "/dataset_eventarc_trigger"
    }
  }

  labels = {
    creator=var.creator
    org=var.org
  }
  service_account = google_service_account.autotagger_service_account.email
  
}

#create bq table trigger 
resource "google_eventarc_trigger" "table_trigger" {
  name = "table"
  location = "global"
  matching_criteria {
    attribute = "type"
    value = "google.cloud.audit.log.v1.written"
    
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "bigquery.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "google.cloud.bigquery.v2.TableService.InsertTable"
  }
  destination {
    cloud_run_service{
        service = google_cloud_run_service.cloudrun.name
        region = var.region
        path = "/table_eventarc_trigger"
    }
  }
  labels = {
    creator=var.creator
    org=var.org
  }
  service_account = google_service_account.autotagger_service_account.email
}

#create gcs trigger 
resource "google_eventarc_trigger" "gcs_trigger" {
  name = "bucket"
  location = "global"
  matching_criteria {
    attribute = "type"
    value = "google.cloud.audit.log.v1.written"
    
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "storage.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "storage.buckets.create"
  }
  destination {
    cloud_run_service{
        service = google_cloud_run_service.cloudrun.name
        region = var.region
        path = "/storage_eventarc_trigger"
    }
  }
  labels = {
    creator=var.creator
    org=var.org
  }

  service_account = google_service_account.autotagger_service_account.email
}

#create cloud run trigger 
resource "google_eventarc_trigger" "run_trigger" {
  name = "run"
  location = "global"
  matching_criteria {
    attribute = "type"
    value = "google.cloud.audit.log.v1.written"
    
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "run.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "google.cloud.run.v1.Services.CreateService"
  }
  destination {
    cloud_run_service{
        service = google_cloud_run_service.cloudrun.name
        region = var.region
        path = "/cloudrun_eventarc_trigger"
    }
  }
  labels = {
    creator=var.creator
    org=var.org
  }

  service_account = google_service_account.autotagger_service_account.email
}


#create cloud sql trigger 
resource "google_eventarc_trigger" "sql_trigger" {
  name = "sql-trigger"
  location = "global"
  matching_criteria {
    attribute = "type"
    value = "google.cloud.audit.log.v1.written"
    
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "cloudsql.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "cloudsql.instances.create"
  }
  destination {
    cloud_run_service{
        service = google_cloud_run_service.cloudrun.name
        region = var.region
        path = "/cloudsql_eventarc_trigger"
    }
  }
  labels = {
    creator=var.creator
    org=var.org
  }

  service_account = google_service_account.autotagger_service_account.email
}


#create cloud functions trigger 
resource "google_eventarc_trigger" "functions_trigger" {
  name = "functions"
  location = "global"
  matching_criteria {
    attribute = "type"
    value = "google.cloud.audit.log.v1.written"
    
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "cloudfunctions.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "google.cloud.functions.v1.CloudFunctionsService.CreateFunction"
  }
  destination {
    cloud_run_service{
        service = google_cloud_run_service.cloudrun.name
        region = var.region
        path = "/func_eventarc_trigger"
    }
  }
  labels = {
    creator=var.creator
    org=var.org
  }

  service_account = google_service_account.autotagger_service_account.email
}

#create vm_terminal trigger 
resource "google_eventarc_trigger" "vm_terminal_trigger" {
  name = "ce-terminal"
  location = "global"
  matching_criteria {
    attribute = "type"
    value = "google.cloud.audit.log.v1.written"
    
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "compute.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "v1.compute.instances.insert"
  }
  destination {
    cloud_run_service{
        service = google_cloud_run_service.cloudrun.name
        region = var.region
        path = "/ce_terminal_eventarc_trigger"
    }
  }

  labels = {
    creator=var.creator
    org=var.org
  }
  service_account = google_service_account.autotagger_service_account.email
}


resource "google_cloud_run_service_iam_binding" "binding" {
  location = google_cloud_run_service.cloudrun.location
  project = google_cloud_run_service.cloudrun.project
  service = google_cloud_run_service.cloudrun.name
  role = "roles/run.invoker"
  members = [
    "allUsers",
  ]
}


resource "google_pubsub_topic" "autotagger_table" {
  name = "autotagger-table"
  labels = {
    creator=var.creator
    org=var.org
  }
}

resource "google_pubsub_subscription" "autotagger_table_push" {
  name = "runpush"
  topic = google_pubsub_topic.autotagger_table.name

  message_retention_duration = "600s"
  labels = {
    creator=var.creator
    org=var.org
  }

  push_config {
    push_endpoint = google_cloud_run_service.cloudrun.status[0].url
    oidc_token {
      service_account_email= google_service_account.autotagger_service_account.email
    }
  }
}

resource "google_logging_project_sink" "bqtablesink" {
  name = "autotagger-table"
  description = "sink for logs generated via table creation through query results"
  depends_on = [google_pubsub_topic.autotagger_table]
  destination = "pubsub.googleapis.com/${google_pubsub_topic.autotagger_table.id}" 
  filter = <<EOT
  protoPayload.metadata.@type="type.googleapis.com/google.cloud.audit.BigQueryAuditMetadata"
protoPayload.metadata.tableCreation.reason != NONE
protoPayload.resourceName !~"projects/${var.project_id}/datasets/_.*" 
EOT
  
 
}
