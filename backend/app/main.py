from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routes import router

app = FastAPI(
    title="AutAnalysis API",
    description="API per la piattaforma Client/Server di Valutazione Clinica.",
    version="1.0.0"
)

# Configurazione CORS per permettere le chiamate dal frontend Flutter (PWA)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Modificare in prod inserendo i domini specifici
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)

@app.get("/", tags=["Health"])
async def health_check():
    return {"status": "ok", "message": "AutAnalysis Backend is running"}
