from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import os

router = APIRouter()

class GenerateRequest(BaseModel):
    prompt: str

@router.post("/v1/llm/generate")
async def generate(req: GenerateRequest):
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="Missing GEMINI_API_KEY")
    # Placeholder implementation
    return {"choices": [{"message": {"content": f"LLM response to: {req.prompt}"}}]}

class ExecuteRequest(BaseModel):
    command: str

@router.post("/v1/execute")
async def execute(req: ExecuteRequest):
    # Placeholder implementation
    return {"status": "executed", "command": req.command}
