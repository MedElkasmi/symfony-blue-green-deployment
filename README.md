# Symfony Blue-Green Deployment with Docker

This project demonstrates a robust deployment strategy called **Blue-Green Deployment** for a Symfony application, using Docker and Docker Compose. It ensures seamless updates to your live application with zero downtime.

## What is Blue-Green Deployment?

Blue-Green Deployment is a technique that reduces downtime and risk by running two identical production environments, "Blue" and "Green."

* **Blue Environment:** This is your current live production environment.
* **Green Environment:** This is the new, identical environment where you deploy and test your new application version.

Once the "Green" environment is fully tested and ready, traffic is quickly switched from "Blue" to "Green." If any issues arise, you can immediately switch back to "Blue," allowing for quick and safe rollbacks.

## Project Features

* **Symfony Application:** A basic Symfony 6/7 application serving as the example.
* **Dockerized:** The application runs inside Docker containers, providing a consistent and isolated environment.
* **Docker Compose:** Used to define and run the multi-container Docker application (web server, PHP-FPM).
* **Automated Deployment Script (`deploy.sh`):** A shell script that automates the entire Blue-Green deployment process.
* **Zero Downtime Updates:** Users experience no interruption during deployments.
* **Automated Health Checks:** Ensures the new "Green" environment is fully operational before traffic is switched.
* **Easy Rollback:** Quick return to the previous stable version if needed.

## Prerequisites

Before you begin, make sure you have the following software installed on your system:

* **Git:** For cloning the repository.
    * [Install Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* **Docker:** The platform for running containers.
    * [Install Docker Engine](https://docs.docker.com/engine/install/)
* **Docker Compose:** For defining and running multi-container Docker applications.
    * [Install Docker Compose](https://docs.docker.com/compose/install/) (Note: For Docker Desktop users, Compose is usually included).

## Getting Started

Follow these steps to set up and deploy the project:

### 1. Clone the Repository

First, clone this project to your local machine:

```bash
git clone [https://github.com/MedElkasmi/symfony-blue-green-deployment.git](https://github.com/MedElkasmi/symfony-blue-green-deployment.git)
cd symfony-blue-green
