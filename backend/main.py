from fastapi import FastAPI, APIRouter
from llm_proxy import router as llm_router

app = FastAPI()

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/metrics")
async def metrics():
    return "requests_total 0"

api_router = APIRouter(prefix="/api")
api_router.include_router(llm_router)
app.include_router(api_router)
