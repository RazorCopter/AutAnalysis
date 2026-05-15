from fastapi import APIRouter, HTTPException, status
from typing import List
from .models import Scale, Evaluation
from .database import evaluations_collection
from datetime import datetime

router = APIRouter()

@router.get("/scales", response_model=List[Scale], tags=["Scales"])
async def get_scales():
    """Restituisce l'elenco delle scale disponibili (Mocked per la Fase 1)"""
    mocked_scale = Scale(
        id="scala_pos",
        nome="Scala POS Eterovalutativa",
        descrizione="Scala di valutazione per l'osservazione dei comportamenti autistici in vari contesti.",
        sezioni=[
            {
                "titolo_sezione": "Interazione Sociale",
                "domande": [
                    {
                        "id_domanda": "q1",
                        "testo_domanda": "Il bambino cerca attivamente il contatto visivo durante l'interazione?",
                        "tipo_risposta": "rating_1_to_5"
                    },
                    {
                        "id_domanda": "q2",
                        "testo_domanda": "Risponde al proprio nome quando viene chiamato?",
                        "tipo_risposta": "rating_1_to_5"
                    }
                ]
            },
            {
                "titolo_sezione": "Comunicazione",
                "domande": [
                    {
                        "id_domanda": "q3",
                        "testo_domanda": "Utilizza gesti per indicare ciò che desidera (pointing)?",
                        "tipo_risposta": "rating_1_to_5"
                    }
                ]
            }
        ]
    )
    return [mocked_scale]

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
