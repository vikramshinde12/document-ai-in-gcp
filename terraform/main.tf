provider "google" {
  project = var.project_name
  region = var.region
  zone = var.zone
}

#-------------------------------------------------------
# Enable APIs
#    - Cloud Function
#    - Pub/Sub
#    - Firestore
#    - Cloud run
#-------------------------------------------------------

module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "3.3.0"

  project_id    = var.project_name
  activate_apis =  [
    "cloudresourcemanager.googleapis.com",
    "cloudfunctions.googleapis.com",
    "pubsub.googleapis.com",
    "firestore.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "documentai.googleapis.com"
  ]

  disable_services_on_destroy = false
  disable_dependent_services  = false
}

#-------------------------------------------------------
# Create Pub/Sub
#    - Topic
#    - Subscriber (Echo for test)
#-------------------------------------------------------

resource "google_pubsub_topic" "alert-topic" {
  name = "emp-notification"
  depends_on = [module.project_services]
}

resource "google_pubsub_subscription" "echo" {
  name = "echo"
  topic = google_pubsub_topic.alert-topic.name
}


#--------------------------------------------------------------------------------
# Event Collection Function
#  - Create source bucket
#  - Copy code from local into bucket
#  - Create function using source code and trigger based on pub/sub
#--------------------------------------------------------------------------------

resource "google_storage_bucket" "bucket" {
  name = "${var.project_name}-source-bucket"
}

resource "google_storage_bucket" "archive" {
  name = "${var.project_name}-archive-bucket"
}


resource "google_storage_bucket_object" "archive" {
  name = "document-processor.zip"
  bucket = google_storage_bucket.archive.name
  source = "./document-processor.zip"
}

resource "google_cloudfunctions_function" "function" {
  name = "document-processor"
  runtime = "python37"
  source_archive_bucket = google_storage_bucket.archive.name
  source_archive_object = google_storage_bucket_object.archive.name

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource = google_storage_bucket.bucket.name
  }
  entry_point = "main"
  labels = {
    app = "document-ai"
  }

  environment_variables = {
    ALERT_TOPIC = google_pubsub_topic.alert-topic.name
  }
  depends_on = [google_pubsub_topic.alert-topic]
}

#----------------------------------------------------------------------------------------------
#  CLOUD RUN
#      - Enable API
#      - Create Service
#      - Expose the service to the public
#----------------------------------------------------------------------------------------------

resource "google_cloud_run_service" "front-end" {
  name = "frontend-app"
  location = var.region

  template  {
    spec {
    containers {
            image = "gcr.io/iot-demo-281606/frontend-app"
            env {
            name = "CLOUD_STORAGE_BUCKET"
            value = google_storage_bucket.bucket.name
        }
    }
  }

  }
}

resource "google_cloud_run_service_iam_member" "allUsers" {
  service  = google_cloud_run_service.front-end.name
  location = google_cloud_run_service.front-end.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}


#----------------------------------------------------------------------------------------------
#  CLOUD RUN
#      - Create Service for API endpoint
#----------------------------------------------------------------------------------------------

resource "google_cloud_run_service" "restapi" {
  name = "restapi"
  location = var.region

  template  {
    spec {
    containers {
            image = "gcr.io/iot-demo-281606/restapi"
    }
  }
  }
}

resource "google_cloud_run_service_iam_member" "allUsers2" {
  service  = google_cloud_run_service.restapi.name
  location = google_cloud_run_service.restapi.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}


#----------------------------------------------------------------------------------------------
#  Subscriber Cloud Function
#      - Copy code from local into existing source bucket
#      - Create function using source code and trigger based on Pub/Sub
#----------------------------------------------------------------------------------------------


resource "google_storage_bucket_object" "archive2" {
  bucket = google_storage_bucket.archive.name
  name = "id-cards"
  source = "id-cards.zip"
}


resource "google_cloudfunctions_function" "id-cards" {
  name = "id-cards"
  runtime = "python37"
  source_archive_bucket = google_storage_bucket.archive.name
  source_archive_object = google_storage_bucket_object.archive2.name

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource = google_pubsub_topic.alert-topic.name
  }
  entry_point = "hello_pubsub"
  environment_variables = {
    SERVICE_URL = google_cloud_run_service.restapi.status[0].url
  }

  depends_on = [google_cloud_run_service.restapi]
}
