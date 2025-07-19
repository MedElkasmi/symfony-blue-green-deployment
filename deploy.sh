#!/bin/bash

    # deploy.sh

    # --- Configuration ---
    # Define the new version you want to deploy
    NEW_VERSION="2.0" # This will be the version deployed to the inactive environment

    # Define the service names as per docker-compose.yml
    BLUE_TARGET="blue"
    GREEN_TARGET="green"

    # Paths to our configuration files
    NGINX_CONF_DIR="./nginx"
    DOCKER_COMPOSE_FILE="./docker-compose.yml"

    # Backup file for Nginx config during switch
    BACKUP_NGINX_CONF="${NGINX_CONF_DIR}/nginx.conf.bak"
    LIVE_NGINX_CONF="${NGINX_CONF_DIR}/nginx.conf"

    echo "Starting Blue-Green Deployment for Version: ${NEW_VERSION}"
    echo "---------------------------------------------------------"

    # --- Function to check if a service is running and healthy ---
    # In a real-world scenario, this would be a more robust health check,
    # e.g., curling a specific /health endpoint on the application.
    check_service_health() {
        local service_name=$1
        echo "-> Checking health of ${service_name}..."

        # Get the container ID for the service
        local container_id=$(docker compose -f ${DOCKER_COMPOSE_FILE} ps -q ${service_name})

        if [ -z "$container_id" ]; then
            echo "   Error: ${service_name} container is not found or not running. Health check failed."
            return 1
        fi

        # Check if the container is running
        if ! docker inspect -f '{{.State.Running}}' "$container_id" | grep -q "true"; then
            echo "   Error: ${service_name} container is not in a running state. Health check failed."
            return 1
        fi

        echo "   ${service_name} container is running."

        # More robust check: try to curl the /health endpoint inside the container's network
        # This requires the health endpoint to be implemented in your Symfony app (e.g., /health route)
        # and the container's internal IP to be reachable from where this script runs,
        # or by executing curl inside the container.
        # For this demo, we'll execute curl inside the container itself.
        echo "   Attempting to hit http://localhost/health inside ${service_name} container..."
        if docker compose exec -T "$service_name" curl --fail --silent http://localhost/health > /dev/null; then
            echo "   Health endpoint for ${service_name} responded successfully."
            return 0
        else
            echo "   Health endpoint for ${service_name} FAILED to respond or returned an error. Health check failed."
            return 1
        fi
    }


    # --- Determine Current Active and Inactive Environments ---
    # Read the current proxy_pass setting from Nginx config
    CURRENT_ACTIVE_ENV_FULL=$(grep 'proxy_pass http://' "${LIVE_NGINX_CONF}")
    if [[ "$CURRENT_ACTIVE_ENV_FULL" =~ proxy_pass\ http:\/\/([a-z]+)_app ]]; then
        CURRENT_ACTIVE_ENV="${BASH_REMATCH[1]}"
    else
        echo "Error: Could not determine current active environment from Nginx config. Exiting."
        exit 1
    fi

    echo "Current active environment: ${CURRENT_ACTIVE_ENV}"

    if [ "$CURRENT_ACTIVE_ENV" == "$BLUE_TARGET" ]; then
        INACTIVE_ENV=$GREEN_TARGET
        ACTIVE_ENV=$BLUE_TARGET
    else
        INACTIVE_ENV=$BLUE_TARGET
        ACTIVE_ENV=$GREEN_TARGET
    fi

    echo "Inactive environment (target for new deployment): ${INACTIVE_ENV}"
    echo ""

    # --- Step 1: Deploy New Version to Inactive Environment ---
    echo "--- Step 1: Deploying ${NEW_VERSION} to ${INACTIVE_ENV} environment ---"

    # Get the current version of the ACTIVE environment for potential rollback consistency
    # This reads the APP_VERSION from the docker-compose.yml for the ACTIVE service.
    CURRENT_ACTIVE_VERSION=$(grep -A 5 "${ACTIVE_ENV}:" "${DOCKER_COMPOSE_FILE}" | grep "APP_VERSION=" | awk -F'=' '{print $2}')
    if [ -z "$CURRENT_ACTIVE_VERSION" ]; then
        echo "Warning: Could not determine CURRENT_ACTIVE_VERSION for ${ACTIVE_ENV}. Assuming rollback to previous version is handled by the script."
        CURRENT_ACTIVE_VERSION="unknown_version" # Fallback
    fi
    echo "Current live application version (on ${ACTIVE_ENV}): ${CURRENT_ACTIVE_VERSION}"


    # Update docker-compose.yml with the new version for the inactive environment
    # Uses sed for in-place editing. macOS requires -i "", Linux -i.
    # This sed command is more robust for multiline match.
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i "" "/${INACTIVE_ENV}:/,/SYMFONY_APP_SECRET=/ s/\(- APP_VERSION=\)[0-9.]*/\1${NEW_VERSION}/" ${DOCKER_COMPOSE_FILE}
    else
        sed -i "/${INACTIVE_ENV}:/,/SYMFONY_APP_SECRET=/ s/\(- APP_VERSION=\)[0-9.]*/\1${NEW_VERSION}/" ${DOCKER_COMPOSE_FILE}
    fi

    echo "Updated ${INACTIVE_ENV} service in ${DOCKER_COMPOSE_FILE} to version ${NEW_VERSION}"

    # Bring up/recreate the inactive environment container
    # --no-deps: only recreate the specified service, not its dependencies
    # --build: rebuild the image using the latest code/Dockerfile
    docker compose up -d --no-deps --build ${INACTIVE_ENV}

    if [ $? -ne 0 ]; then
        echo "Error: Failed to bring up ${INACTIVE_ENV} with new version. Exiting deployment."
        exit 1
    fi

    echo "Waiting for ${INACTIVE_ENV} to stabilize and boot up..."
    sleep 20 # Give the new container enough time to start Apache, PHP, and Symfony cache warm-up

    echo ""
    # --- Step 2: Health Check the Inactive Environment ---
    echo "--- Step 2: Performing health check on ${INACTIVE_ENV} (Version: ${NEW_VERSION}) ---"
    if ! check_service_health "${INACTIVE_ENV}"; then
        echo "Health check failed for ${INACTIVE_ENV} (Version: ${NEW_VERSION})."
        echo "Initiating Rollback of docker-compose.yml version for ${INACTIVE_ENV}..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i "" "/${INACTIVE_ENV}:/,/SYMFONY_APP_SECRET=/ s/\(- APP_VERSION=\)[0-9.]*/\1${CURRENT_ACTIVE_VERSION}/" ${DOCKER_COMPOSE_FILE}
        else
            sed -i "/${INACTIVE_ENV}:/,/SYMFONY_APP_SECRET=/ s/\(- APP_VERSION=\)[0-9.]*/\1${CURRENT_ACTIVE_VERSION}/" ${DOCKER_COMPOSE_FILE}
        fi
        echo "Docker Compose config for ${INACTIVE_ENV} reverted to ${CURRENT_ACTIVE_VERSION} (for consistency)."
        echo "Please investigate the issues with the ${NEW_VERSION} deployment."
        exit 1
    fi
    echo "Health check passed for ${INACTIVE_ENV}."
    echo ""

    # --- Step 3: Switch Nginx Traffic ---
    echo "--- Step 3: Switching Nginx traffic from ${ACTIVE_ENV} to ${INACTIVE_ENV} ---"

    # Backup current Nginx config before modifying
    cp "${LIVE_NGINX_CONF}" "${BACKUP_NGINX_CONF}"
    echo "Backed up Nginx config to ${BACKUP_NGINX_CONF}"

    # Update Nginx config to point to the new environment
    # Replace the proxy_pass line to point to the inactive (new) environment
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i "" "s/proxy_pass http:\/\/${ACTIVE_ENV}_app;/proxy_pass http:\/\/${INACTIVE_ENV}_app;/" "${LIVE_NGINX_CONF}"
    else
      sed -i "s/proxy_pass http:\/\/${ACTIVE_ENV}_app;/proxy_pass http:\/\/${INACTIVE_ENV}_app;/" "${LIVE_NGINX_CONF}"
    fi

    echo "Nginx config updated. Reloading Nginx..."
    # Reload Nginx configuration without downtime
    docker compose exec nginx nginx -s reload

    if [ $? -ne 0 ]; then
        echo "Error: Failed to reload Nginx. Attempting to rollback Nginx config."
        # Rollback Nginx config if reload fails
        cp "${BACKUP_NGINX_CONF}" "${LIVE_NGINX_CONF}"
        docker compose exec nginx nginx -s reload
        echo "Nginx config rolled back. Traffic should still be on ${ACTIVE_ENV}. Please investigate."
        rm "${BACKUP_NGINX_CONF}" # Clean up failed backup
        exit 1
    fi
    echo "Nginx reloaded successfully. Traffic now directed to ${INACTIVE_ENV}."
    echo ""

    # --- Step 4: Validate New Live Environment ---
    echo "--- Step 4: Validating the new live environment (http://localhost) ---"
    sleep 5 # Give Nginx a moment to fully switch traffic

    echo "Please manually verify http://localhost now shows Version: ${NEW_VERSION}."
    read -p "Does the new version appear correctly? (y/n): " validation_response

    if [[ "$validation_response" =~ ^[Yy]$ ]]; then
        echo "Validation successful!"
        echo ""
        # --- Step 5: Shut down old environment ---
        echo "--- Step 5: Shutting down old environment (${ACTIVE_ENV}) ---"
        # Stop and remove the old environment container
        docker compose stop ${ACTIVE_ENV}
        docker compose rm -f ${ACTIVE_ENV} # -f to force removal without prompt

        echo "Old environment (${ACTIVE_ENV}) shut down."
        echo "---------------------------------------------------------"
        echo "Blue-Green Deployment successful! ${INACTIVE_ENV} (Version ${NEW_VERSION}) is now live."

        # Cleanup backup
        rm "${BACKUP_NGINX_CONF}"
        echo "Cleaned up Nginx config backup."

    else
        echo "Validation failed or user chose to rollback. Initiating rollback process..."
        echo "---------------------------------------------------------"
        # --- Rollback (if validation fails) ---
        echo "--- Initiating Rollback to ${ACTIVE_ENV} (previous version) ---"

        # Revert Nginx config to point back to the old environment
        echo "Reverting Nginx config to point back to ${ACTIVE_ENV}..."
        cp "${BACKUP_NGINX_CONF}" "${LIVE_NGINX_CONF}"
        docker compose exec nginx nginx -s reload
        echo "Nginx reloaded. Traffic should be back on ${ACTIVE_ENV}."
        rm "${BACKUP_NGINX_CONF}" # Clean up backup
        echo "Cleaned up Nginx config backup."

        # Revert the docker-compose.yml change for the INACTIVE_ENV (so it's ready for next attempt)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i "" "/${INACTIVE_ENV}:/,/SYMFONY_APP_SECRET=/ s/\(- APP_VERSION=\)[0-9.]*/\1${CURRENT_ACTIVE_VERSION}/" ${DOCKER_COMPOSE_FILE}
        else
            sed -i "/${INACTIVE_ENV}:/,/SYMFONY_APP_SECRET=/ s/\(- APP_VERSION=\)[0-9.]*/\1${CURRENT_ACTIVE_VERSION}/" ${DOCKER_COMPOSE_FILE}
        fi
        echo "Docker Compose config for ${INACTIVE_ENV} reverted to ${CURRENT_ACTIVE_VERSION}."


        echo "Rollback complete. ${ACTIVE_ENV} is now live again."
        echo "Please investigate issues with the ${NEW_VERSION} deployment on ${INACTIVE_ENV}."
        exit 1
    fi