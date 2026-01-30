"""
Simple unit tests for the FastAPI application.
Used in CI/CD pipeline for validation.
"""

import pytest
from fastapi.testclient import TestClient
from app import app

# Create test client
client = TestClient(app)


def test_health_endpoint():
    """Test the health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_get_ideas():
    """Test getting all ideas"""
    response = client.get("/ideas")
    assert response.status_code == 200
    data = response.json()
    assert "ideas" in data
    assert "count" in data
    assert isinstance(data["ideas"], list)


def test_create_idea():
    """Test creating a new idea"""
    test_idea = {
        "title": "Test Idea",
        "description": "This is a test description"
    }
    response = client.post("/ideas", json=test_idea)
    assert response.status_code == 200
    data = response.json()
    assert "idea" in data
    assert data["idea"]["title"] == test_idea["title"]
    assert data["idea"]["description"] == test_idea["description"]
