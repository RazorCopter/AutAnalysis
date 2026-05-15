from fastapi import APIRouter, HTTPException, status
from typing import List
from .models import Scale, Evaluation
from .database import evaluations_collection, database
from datetime import datetime

router = APIRouter()

scales_collection = database.get_collection("scales")

@router.get("/scales", response_model=List[Scale], tags=["Scales"])
async def get_scales():
    """Restituisce l'elenco delle scale disponibili interrogando MongoDB"""
    cursor = scales_collection.find({})
    scales = await cursor.to_list(length=100)
    return scales

@router.get("/patients/{id_patient}/evaluations/{year}", response_model=List[Evaluation], tags=["Evaluations"])
async def get_evaluations(id_patient: str, year: int):
    """Restituisce l'elenco delle valutazioni compilate da un paziente in un determinato anno"""
    cursor = evaluations_collection.find({"id_paziente": id_patient, "anno": year})
    evaluations = await cursor.to_list(length=100)
    return evaluations

@router.post("/evaluations", response_model=Evaluation, status_code=status.HTTP_201_CREATED, tags=["Evaluations"])
async def create_evaluation(evaluation: Evaluation):
    """Salva una nuova valutazione compilata nel database"""
    # Convertiamo il modello in dict per salvarlo su mongo
    eval_dict = evaluation.model_dump()
    result = await evaluations_collection.insert_one(eval_dict)
    
    if not result.inserted_id:
        raise HTTPException(status_code=500, detail="Errore nel salvataggio della valutazione")
        
    return evaluation
