### Build a Image
Set env variable
``
export PROJECT_ID=<<PROJECT_ID>> 
``

To build 
```buildoutcfg
gcloud builds submit --tag gcr.io/$PROJECT_ID/frontend-app
```
where PROJECT-ID is your GCP project ID. You can get it by running gcloud config get-value project.

### Push a Image
If you have not yet configured Docker to use the gcloud command-line tool to authenticate requests to Container Registry, do so now using the command:

```
 gcloud auth configure-docker
```

You need to do this before you can push or pull images using Docker. You only need to do it once.
```buildoutcfg
 docker push gcr.io/$PROJECT_ID/frontend-app
```

### Deploy the Docker container

```buildoutcfg
gcloud run deploy frontend-app --image gcr.io/$PROJECT_ID/frontend-app --platform=managed --region=us-central1 --allow-unauthenticated
```