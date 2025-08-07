#!/bin/bash
#
# AppFlowy Start Script for Dokploy Deployment
# This script handles the build and run process for AppFlowy in a containerized environment
#

set -e

echo "====================================="
echo "AppFlowy Deployment Script"
echo "====================================="

# Check if we're in Docker/container environment
if [ -f /.dockerenv ] || [ -n "$DOCKER_CONTAINER" ]; then
    echo "Running in container environment..."
    
    # If the app is already built, just start it
    if [ -f "/home/appflowy/appflowy/AppFlowy" ]; then
        echo "AppFlowy already built, starting application..."
        exec /start.sh
    else
        echo "Building AppFlowy from source..."
        # This would be handled by the Dockerfile
        exec /start.sh
    fi
else
    echo "Running in development/local environment..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if docker-compose is installed
    if ! command -v docker-compose &> /dev/null; then
        echo "docker-compose is not installed. Please install docker-compose first."
        exit 1
    fi
    
    echo "Building and starting AppFlowy with Docker Compose..."
    docker-compose up --build -d
    
    echo ""
    echo "====================================="
    echo "AppFlowy is starting..."
    echo "Access the application at: http://localhost:6080"
    echo "====================================="
    echo ""
    echo "To stop AppFlowy, run: docker-compose down"
    echo "To view logs, run: docker-compose logs -f"
fi