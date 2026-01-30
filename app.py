"""
Minimal FastAPI Application for DevOps Case Study

This is a simple backend API with three endpoints:
- GET /health: Health check endpoint
- GET /ideas: Returns list of ideas
- POST /ideas: Creates a new idea

No database - uses in-memory storage for simplicity.
"""

from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional

# Initialize FastAPI app
app = FastAPI(
    title="Ideas API",
    description="A simple API for managing ideas",
    version="1.0.0"
)

# In-memory storage for ideas (no database needed)
ideas_storage = [
    {"id": 1, "title": "Build microservices architecture", "description": "Modern cloud-native approach"},
    {"id": 2, "title": "Implement CI/CD pipeline", "description": "Automate deployments"},
    {"id": 3, "title": "Add monitoring and observability", "description": "Track application metrics"},
]


class Idea(BaseModel):
    """Pydantic model for idea creation"""
    title: str
    description: Optional[str] = None


@app.get("/health")
async def health_check():
    """
    Health check endpoint for Kubernetes liveness and readiness probes.
    Returns simple status to indicate service is running.
    """
    return {"status": "ok"}


@app.get("/ideas")
async def get_ideas():
    """
    Get all ideas from in-memory storage.
    Returns list of ideas and total count.
    """
    return {
        "ideas": ideas_storage,
        "count": len(ideas_storage)
    }


@app.post("/ideas")
async def create_idea(idea: Idea):
    """
    Create a new idea.
    Accepts JSON with title and optional description.
    Returns the created idea with auto-generated ID.
    """
    # Generate new ID (simple increment logic)
    new_id = max([i["id"] for i in ideas_storage], default=0) + 1
    
    # Create new idea object
    new_idea = {
        "id": new_id,
        "title": idea.title,
        "description": idea.description or ""
    }
    
    # Add to storage
    ideas_storage.append(new_idea)
    
    return {
        "message": "Idea created successfully",
        "idea": new_idea
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
