# Qualys Container Security (CS) Runtime Instrumenter Service
Qualys Container Runtime Security Instrumenter Service Deployment Files and support test scripts


## Deployment files
Qualys Container Runtime Security Instrumenter Service Deployment Files
1. deploy-instrumenter-docker-compose.yml
2. deploy-instrumenter.sh
3. k8s-deploy-instrumenter.yaml
4. undeploy-instrumenter.sh 

### Usage
For more information, please refer: https://www.qualys.com/docs/qualys-container-runtime-security-user-guide.pdf for modifying the deployment file as per the deployment platform.



## Support test Scripts
This script is to check if instrumentation of the input image is supported or not.
1. check_if_image_instrumentable.sh

### Usage:
1. Print help message - 
./check_if_image_instrumentable.sh --help or -h 

2. Test if an image is instrumentable -
./check_if_image_instrumentable.sh (ImageID OR ImageName OR ImageSHA) (MANDATORY)

Provide image name or ID or SHA to the script. In case of image name and image SHA, if the image is not present on the host, it will be pulled
If the image is from a private registry, please make sure to perform docker login to the registry before running the script.
