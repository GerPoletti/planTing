#!/usr/bin/env python3
"""Genera assets/data/species.json a partir de una tabla compacta.
Todos los datos están marcados como borrador hasta verificarlos con fuentes."""
import json, pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets/data/species.json"

# id, científico, nombres es, nombres it, lugar, DLI min, DLI max, riego (días), temp mín °C, humedad mín %, tóxica para perros/gatos
R = [
("monstera_deliciosa","Monstera deliciosa",["Costilla de Adán","Monstera"],["Monstera","Costola di Adamo"],"indoor",6,15,7,15,50,True),
("epipremnum_aureum","Epipremnum aureum",["Potus","Pothos"],["Pothos"],"indoor",4,10,7,12,40,True),
("dracaena_trifasciata","Dracaena trifasciata",["Lengua de suegra","Sansevieria"],["Sansevieria","Lingua di suocera"],"indoor",2,15,14,10,30,True),
("echeveria_elegans","Echeveria elegans",["Echeveria"],["Echeveria"],"both",15,30,14,5,20,False),
("aloe_vera","Aloe vera",["Aloe vera","Sábila"],["Aloe vera"],"both",14,30,14,8,20,True),
("chlorophytum_comosum","Chlorophytum comosum",["Cinta","Mala madre"],["Falangio","Pianta ragno"],"indoor",6,14,7,10,40,False),
("calathea_orbifolia","Calathea orbifolia",["Calathea"],["Calathea"],"indoor",4,10,6,16,55,False),
("peperomia_obtusifolia","Peperomia obtusifolia",["Peperomia"],["Peperomia"],"indoor",4,12,10,12,40,False),
("nephrolepis_exaltata","Nephrolepis exaltata",["Helecho de Boston"],["Felce di Boston"],"indoor",4,10,4,12,60,False),
("ficus_lyrata","Ficus lyrata",["Ficus lira"],["Ficus lyrata","Fico lira"],"indoor",10,20,8,12,40,True),
("ficus_elastica","Ficus elastica",["Gomero","Ficus elástica"],["Albero della gomma","Ficus elastica"],"indoor",8,20,8,10,40,True),
("philodendron_hederaceum","Philodendron hederaceum",["Filodendro de hoja de corazón"],["Filodendro","Philodendron"],"indoor",4,12,7,15,45,True),
("zamioculcas_zamiifolia","Zamioculcas zamiifolia",["Zamioculcas","Planta ZZ"],["Zamioculcas","Pianta ZZ"],"indoor",2,10,18,12,30,True),
("spathiphyllum_wallisii","Spathiphyllum wallisii",["Cuna de Moisés","Espatifilo"],["Giglio della pace","Spatifillo"],"indoor",3,9,6,13,50,True),
("dieffenbachia_seguine","Dieffenbachia seguine",["Dieffenbachia"],["Dieffenbachia"],"indoor",5,12,7,15,50,True),
("crassula_ovata","Crassula ovata",["Árbol de jade"],["Albero di giada","Crassula"],"both",14,25,14,5,20,True),
("haworthia_attenuata","Haworthia attenuata",["Haworthia"],["Haworthia"],"indoor",6,15,14,8,20,False),
("dypsis_lutescens","Dypsis lutescens",["Palma areca"],["Palma areca"],"indoor",8,18,7,12,45,False),
("chamaedorea_elegans","Chamaedorea elegans",["Palma de salón"],["Palma da salotto","Camedorea"],"indoor",4,10,7,12,45,False),
("phalaenopsis","Phalaenopsis",["Orquídea mariposa","Orquídea"],["Orchidea","Phalaenopsis"],"indoor",4,10,7,15,50,False),
("saintpaulia_ionantha","Saintpaulia ionantha",["Violeta africana"],["Violetta africana"],"indoor",5,10,6,15,50,False),
("schlumbergera_truncata","Schlumbergera truncata",["Cactus de Navidad"],["Cactus di Natale"],"indoor",6,14,10,10,40,False),
("aspidistra_elatior","Aspidistra elatior",["Aspidistra"],["Aspidistra"],"indoor",1,6,10,5,30,False),
("fittonia_albivenis","Fittonia albivenis",["Fittonia"],["Fittonia"],"indoor",3,8,4,15,60,False),
("hoya_carnosa","Hoya carnosa",["Flor de cera"],["Fiore di cera","Hoya"],"indoor",8,20,12,12,40,False),
("senecio_rowleyanus","Senecio rowleyanus",["Rosario","Collar de perlas"],["Rosario","Filo di perle"],"indoor",14,25,14,8,25,True),
("aglaonema_commutatum","Aglaonema commutatum",["Aglaonema"],["Aglaonema"],"indoor",3,9,8,15,50,True),
("codiaeum_variegatum","Codiaeum variegatum",["Croton"],["Croton","Codiaeum"],"indoor",14,25,7,15,50,True),
("dracaena_marginata","Dracaena marginata",["Drácena"],["Dracena","Dracaena marginata"],"indoor",6,16,10,12,35,True),
("yucca_elephantipes","Yucca elephantipes",["Yuca de interior"],["Yucca"],"both",12,25,12,5,25,True),
("cyclamen_persicum","Cyclamen persicum",["Ciclamen"],["Ciclamino"],"both",8,14,5,5,45,True),
("begonia_rex","Begonia rex",["Begonia"],["Begonia"],"indoor",8,16,6,13,55,True),
("anthurium_andraeanum","Anthurium andraeanum",["Anturio"],["Anthurium","Anturio"],"indoor",6,14,6,15,55,True),
("tradescantia_zebrina","Tradescantia zebrina",["Amor de hombre","Tradescantia"],["Tradescantia"],"indoor",6,15,6,10,40,True),
("guzmania","Guzmania",["Bromelia"],["Bromelia","Guzmania"],"indoor",8,16,7,15,50,False),
("tillandsia","Tillandsia",["Clavel del aire","Tillandsia"],["Tillandsia"],"indoor",6,16,5,10,50,False),
("pachira_aquatica","Pachira aquatica",["Árbol del dinero","Pachira"],["Pachira","Albero del denaro"],"indoor",8,18,10,12,40,False),
("maranta_leuconeura","Maranta leuconeura",["Maranta","Planta de la oración"],["Maranta"],"indoor",4,10,6,15,55,False),
("pilea_peperomioides","Pilea peperomioides",["Pilea","Planta del dinero chino"],["Pilea"],"indoor",6,14,8,10,40,False),
("alocasia_amazonica","Alocasia × amazonica",["Alocasia"],["Alocasia"],"indoor",8,18,6,16,55,True),
("strelitzia_reginae","Strelitzia reginae",["Ave del paraíso"],["Strelitzia","Uccello del paradiso"],"both",15,30,7,8,40,True),
("beaucarnea_recurvata","Beaucarnea recurvata",["Pata de elefante"],["Beaucarnea","Palma elefante"],"indoor",14,25,14,8,25,False),
("ocimum_basilicum","Ocimum basilicum",["Albahaca"],["Basilico"],"both",20,30,3,10,40,False),
("mentha","Mentha",["Menta"],["Menta"],"both",12,20,3,0,40,True),
("rosmarinus_officinalis","Rosmarinus officinalis",["Romero"],["Rosmarino"],"both",20,30,10,-5,30,False),
("lavandula_angustifolia","Lavandula angustifolia",["Lavanda"],["Lavanda"],"both",20,35,10,-5,25,True),
]

# Medio de cultivo distinto de la tierra: cambia cómo se revisa la humedad.
MEDIUM = {"tillandsia": "air", "phalaenopsis": "bark"}

species = []
for (i, sci, es, it, place, dmin, dmax, water, tmin, hmin, toxic) in R:
    species.append({
        "id": i, "scientific": sci,
        "names": {"es": es, "it": it},
        "place": place,
        "dliMin": dmin, "dliMax": dmax,
        "waterDays": water, "tempMin": tmin, "humidityMin": hmin,
        "toxicToPets": toxic,
        "medium": MEDIUM.get(i, "soil"),
        "confidence": "draft",
    })
OUT.write_text(json.dumps({"version": 1, "species": species}, ensure_ascii=False, indent=1), encoding="utf-8")
print(len(species), "especies")
