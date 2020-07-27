output "frontend-url" {
  value = google_cloud_run_service.front-end.status[0].url
}


output "restendpoint-url" {
  value = google_cloud_run_service.restapi.status[0].url
}