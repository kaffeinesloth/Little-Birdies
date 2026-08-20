from dotenv import load_dotenv
load_dotenv()  # Load .env trước khi import bất kỳ module nào đọc env vars

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routers import tickets, messages, documents, channels, users, webhooks

app = FastAPI(
    title="Smart Helpdesk API",
    description="Backend API for the AI-powered customer-support system.",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

# CORS — Cho phép truy cập từ tất cả origin (Store 3000 & Admin 8080)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---- Routers ----
app.include_router(tickets.router,   prefix="/api/v1/tickets",   tags=["Tickets"])
app.include_router(messages.router,  prefix="/api/v1/messages",  tags=["Messages"])
app.include_router(documents.router, prefix="/api/v1/documents", tags=["Knowledge Base"])
app.include_router(channels.router,  prefix="/api/v1/channels",  tags=["Channels"])
app.include_router(users.router,     prefix="/api/v1/users",     tags=["Users"])
app.include_router(webhooks.router,  prefix="/api/v1/webhooks",  tags=["Webhooks"])


@app.get("/", tags=["Health"])
def health_check():
    return {"status": "ok", "service": "Smart Helpdesk API"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
