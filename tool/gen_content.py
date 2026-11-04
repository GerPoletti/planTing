#!/usr/bin/env python3
"""Genera assets/data/pests.json y assets/data/consultorio.json.
Los textos en español son neutros (infinitivos) para servir a es-AR y es-ES."""
import json, pathlib

ASSETS = pathlib.Path(__file__).resolve().parent.parent / "assets/data"

def T(es, it):
    return {"es": es, "it": it}

PET = T(
    "Con mascotas: evitar aceites esenciales y neem (pueden ser tóxicos para los gatos) y mantener la planta fuera de su alcance hasta que seque.",
    "Con animali domestici: evitare oli essenziali e neem (possono essere tossici per i gatti) e tenere la pianta fuori portata finché non è asciutta.",
)

def pest(id_, es, it, where, signs, prev, tasks):
    return {
        "id": id_, "names": {"es": es, "it": it}, "where": where,
        "signs": T(*signs), "prevention": T(*prev), "petNote": PET,
        "tasks": [{"day": d, "final": i == len(tasks) - 1, "text": T(*t)} for i, (d, t) in enumerate(tasks)],
        "confidence": "draft",
    }

SOAP1 = ("Primera aplicación de jabón potásico", "Prima applicazione di sapone potassico")
SOAP2 = ("Segunda aplicación de jabón potásico", "Seconda applicazione di sapone potassico")
SOAP3 = ("Tercera aplicación de jabón potásico", "Terza applicazione di sapone potassico")

pests = [
 pest("cochinilla", ["Cochinilla algodonosa"], ["Cocciniglia cotonosa"], "leaf",
  ("Masas blancas algodonosas en las axilas y el envés de las hojas, y residuo pegajoso.",
   "Masse bianche cotonose nelle ascelle e sul lato inferiore delle foglie, con residuo appiccicoso."),
  ("Revisar las axilas al regar y dejar 2 semanas en cuarentena las plantas nuevas.",
   "Controllare le ascelle delle foglie quando si annaffia e tenere 2 settimane in quarantena le piante nuove."),
  [(0, ("Aislar la planta y quitar las visibles con un hisopo en alcohol isopropílico al 70 %",
        "Isolare la pianta e rimuovere le cocciniglie visibili con un cotton fioc con alcol isopropilico al 70%")),
   (7, ("Pulverizar jabón potásico y revisar las axilas", "Nebulizzare sapone potassico e controllare le ascelle delle foglie")),
   (14, ("Pulverizar jabón potásico y revisar las axilas", "Nebulizzare sapone potassico e controllare le ascelle delle foglie")),
   (21, ("Pulverizar jabón potásico y revisar las axilas", "Nebulizzare sapone potassico e controllare le ascelle delle foglie")),
   (28, ("Revisión final: ¿quedan restos?", "Controllo finale: restano tracce?"))]),
 pest("trips", ["Trips"], ["Tripidi"], "leaf",
  ("Rayas plateadas en las hojas, puntos negros y brotes o flores deformes.",
   "Striature argentate sulle foglie, puntini neri e germogli o fiori deformati."),
  ("Mantener buena ventilación y revisar flores y brotes nuevos.",
   "Garantire una buona ventilazione e controllare fiori e germogli nuovi."),
  [(0, ("Aislar la planta y colocar trampas azules pegajosas", "Isolare la pianta e posizionare trappole cromotropiche blu")),
   (0, SOAP1), (5, SOAP2), (10, SOAP3),
   (17, ("Revisión final: ¿hay rayas plateadas nuevas?", "Controllo finale: ci sono nuove striature argentate?"))]),
 pest("acaros", ["Ácaros (araña roja)"], ["Acari (ragnetto rosso)"], "leaf",
  ("Puntitos amarillos en las hojas y telarañas finas en el envés, sobre todo con aire seco.",
   "Puntini gialli sulle foglie e sottili ragnatele sul lato inferiore, soprattutto con aria secca."),
  ("Evitar ambientes muy secos y limpiar las hojas con un paño húmedo.",
   "Evitare ambienti molto secchi e pulire le foglie con un panno umido."),
  [(0, ("Dar una ducha a las hojas y subir la humedad del ambiente", "Lavare le foglie con una doccia e aumentare l'umidità dell'ambiente")),
   (0, SOAP1), (5, SOAP2), (10, SOAP3),
   (17, ("Revisión final: ¿quedan telarañas?", "Controllo finale: restano ragnatele?"))]),
 pest("mosquito", ["Mosquito del sustrato"], ["Moscerini del terriccio"], "soil",
  ("Mosquitas pequeñas que vuelan al regar y larvas en el sustrato siempre húmedo.",
   "Piccoli moscerini che volano quando si annaffia e larve nel terriccio sempre umido."),
  ("Evitar platos con agua estancada y sustratos que retienen demasiada humedad.",
   "Evitare sottovasi con acqua stagnante e terricci che trattengono troppa umidità."),
  [(0, ("Dejar secar 3 a 5 cm de sustrato y colocar trampas amarillas", "Lasciare asciugare 3-5 cm di terriccio e posizionare trappole cromotropiche gialle")),
   (0, ("Regar con Bacillus thuringiensis israelensis (BTI)", "Annaffiare con Bacillus thuringiensis israelensis (BTI)")),
   (7, ("Cambiar las trampas y repetir el BTI", "Sostituire le trappole e ripetere il BTI")),
   (14, ("Revisar si siguen apareciendo mosquitas", "Controllare se compaiono ancora moscerini")),
   (21, ("Revisión final: ¿siguen las mosquitas?", "Controllo finale: ci sono ancora moscerini?"))]),
 pest("pulgon", ["Pulgón"], ["Afidi"], "shoot",
  ("Colonias verdes o negras en los brotes tiernos, residuo pegajoso y a veces hormigas.",
   "Colonie verdi o nere sui germogli teneri, residuo appiccicoso e talvolta formiche."),
  ("Revisar los brotes nuevos y controlar a las hormigas.",
   "Controllare i germogli nuovi e tenere sotto controllo le formiche."),
  [(0, ("Quitarlos con un chorro de agua y aplicar jabón potásico", "Rimuoverli con un getto d'acqua e applicare sapone potassico")),
   (5, ("Segunda aplicación y control de hormigas", "Seconda applicazione e controllo delle formiche")),
   (10, ("Tercera aplicación de jabón potásico", "Terza applicazione di sapone potassico")),
   (17, ("Revisión final: ¿quedan colonias?", "Controllo finale: restano colonie?"))]),
 pest("mosca_blanca", ["Mosca blanca"], ["Mosca bianca"], "leaf",
  ("Insectos blancos diminutos que vuelan al mover la planta y residuo pegajoso en el envés.",
   "Minuscoli insetti bianchi che volano quando si scuote la pianta e residuo appiccicoso sul lato inferiore."),
  ("Revisar el envés de las hojas y no apiñar las plantas.",
   "Controllare il lato inferiore delle foglie e non affollare le piante."),
  [(0, ("Colocar trampas amarillas y lavar el envés de las hojas con agua", "Posizionare trappole gialle e lavare con acqua il lato inferiore delle foglie")),
   (0, SOAP1), (5, SOAP2), (10, SOAP3),
   (17, ("Revisión final: ¿siguen volando?", "Controllo finale: volano ancora?"))]),
 pest("caparazon", ["Cochinilla de caparazón"], ["Cocciniglia a scudetto"], "shoot",
  ("Pequeños escudos marrones adheridos a tallos y hojas, y residuo pegajoso.",
   "Piccoli scudetti marroni attaccati a fusti e foglie, con residuo appiccicoso."),
  ("Revisar los tallos de las plantas nuevas antes de sumarlas a la colección.",
   "Controllare i fusti delle piante nuove prima di aggiungerle alla collezione."),
  [(0, ("Aislar la planta y retirar los escudos a mano o con un hisopo en alcohol", "Isolare la pianta e rimuovere gli scudetti a mano o con un cotton fioc con alcol")),
   (7, ("Pulverizar jabón potásico y retirar los que queden", "Nebulizzare sapone potassico e rimuovere quelli rimasti")),
   (14, ("Pulverizar jabón potásico y retirar los que queden", "Nebulizzare sapone potassico e rimuovere quelli rimasti")),
   (21, ("Pulverizar jabón potásico y retirar los que queden", "Nebulizzare sapone potassico e rimuovere quelli rimasti")),
   (28, ("Revisión final: ¿quedan escudos?", "Controllo finale: restano scudetti?"))]),
 pest("oidio", ["Oídio"], ["Oidio (mal bianco)"], "leaf",
  ("Polvillo blanco sobre hojas y tallos, a menudo con poca ventilación.",
   "Polverina bianca su foglie e fusti, spesso con scarsa ventilazione."),
  ("Evitar mojar las hojas y asegurar buena ventilación.",
   "Evitare di bagnare le foglie e garantire una buona ventilazione."),
  [(0, ("Aislar la planta, cortar las hojas más afectadas y mejorar la ventilación", "Isolare la pianta, tagliare le foglie più colpite e migliorare la ventilazione")),
   (7, ("Aplicar un fungicida apto para plantas de interior, siguiendo la etiqueta", "Applicare un fungicida adatto alle piante da appartamento, seguendo l'etichetta")),
   (14, ("Repetir la aplicación si la etiqueta lo indica", "Ripetere l'applicazione se indicato dall'etichetta")),
   (21, ("Revisión final: ¿reaparece el polvillo?", "Controllo finale: riappare la polverina?"))]),
 pest("babosas", ["Babosas y caracoles"], ["Lumache e limacce"], "all",
  ("Hojas con bordes comidos y rastros plateados, sobre todo en balcones y terrazas.",
   "Foglie con bordi rosicchiati e scie argentate, soprattutto su balconi e terrazze."),
  ("Mantener el balcón limpio y sin refugios húmedos.",
   "Tenere il balcone pulito e senza rifugi umidi."),
  [(0, ("Retirar a mano al atardecer y revisar debajo de las macetas", "Rimuovere a mano al tramonto e controllare sotto i vasi")),
   (3, ("Repetir la recolección y colocar barreras alrededor de la maceta", "Ripetere la raccolta e posizionare barriere attorno al vaso")),
   (7, ("Repetir la recolección", "Ripetere la raccolta")),
   (14, ("Revisión final: ¿hay hojas nuevas comidas?", "Controllo finale: ci sono nuove foglie rosicchiate?"))]),
]

def cause(title, why, steps, pest_id=None):
    c = {"title": T(*title), "why": T(*why), "steps": [T(*s) for s in steps]}
    if pest_id:
        c["pestId"] = pest_id
    return c

def opt(label, c):
    return {"label": T(*label), "cause": c}

WATER_STEPS = [
 ("Regar a fondo hasta que salga agua por el drenaje", "Annaffiare a fondo fino a far uscire l'acqua dal drenaggio"),
 ("Si el sustrato repele el agua, sumergir la maceta 15 minutos", "Se il terriccio respinge l'acqua, immergere il vaso per 15 minuti"),
 ("Ajustar la frecuencia al ritmo real de secado", "Adattare la frequenza al ritmo reale di asciugatura"),
]
FOLLOW = ("Seguir el tratamiento del catálogo de plagas", "Seguire il trattamento del catalogo parassiti")

symptoms = [
 {"id": "yellow", "title": T("Hojas amarillas", "Foglie gialle"), "question": T("¿Cómo está el sustrato?", "Com'è il terriccio?"), "options": [
  opt(("Húmedo o encharcado", "Umido o zuppo"), cause(
   ("Exceso de riego o mal drenaje", "Troppa acqua o drenaggio scarso"),
   ("Las raíces sin oxígeno no absorben agua ni nutrientes.", "Le radici senza ossigeno non assorbono acqua né nutrienti."),
   [("Dejar secar los primeros 3 a 4 cm antes de volver a regar", "Lasciare asciugare i primi 3-4 cm prima di annaffiare di nuovo"),
    ("Revisar el drenaje: agujeros en la maceta y plato sin agua acumulada", "Controllare il drenaggio: fori nel vaso e sottovaso senza acqua stagnante"),
    ("Si no mejora, mirar las raíces: si están blandas u oscuras, cortar lo podrido y cambiar el sustrato", "Se non migliora, controllare le radici: se sono molli o scure, tagliare le parti marce e cambiare il terriccio")])),
  opt(("Seco desde hace días", "Asciutto da giorni"), cause(
   ("Falta de agua", "Mancanza d'acqua"),
   ("La planta sacrifica hojas para ahorrar agua.", "La pianta sacrifica foglie per risparmiare acqua."), WATER_STEPS)),
  opt(("Normal, y solo se amarillean hojas viejas de abajo", "Normale, e ingialliscono solo le foglie vecchie in basso"), cause(
   ("Envejecimiento natural o falta de nutrientes", "Invecchiamento naturale o carenza di nutrienti"),
   ("Perder alguna hoja vieja es normal; si son muchas, suele faltar nitrógeno.", "Perdere qualche foglia vecchia è normale; se sono molte, spesso manca azoto."),
   [("Quitar las hojas amarillas", "Rimuovere le foglie gialle"),
    ("Fertilizar con dosis suaves en primavera y verano", "Concimare con dosi leggere in primavera ed estate"),
    ("Revisar si la planta necesita una maceta más grande", "Verificare se la pianta ha bisogno di un vaso più grande")])),
 ]},
 {"id": "tips", "title": T("Puntas marrones", "Punte marroni"), "question": T("¿Cómo es el ambiente?", "Com'è l'ambiente?"), "options": [
  opt(("Aire seco o calefacción", "Aria secca o riscaldamento"), cause(
   ("Humedad ambiente baja", "Umidità ambientale bassa"),
   ("Las puntas pierden agua más rápido de lo que la reciben.", "Le punte perdono acqua più in fretta di quanto ne ricevano."),
   [("Agrupar plantas o usar un humidificador", "Raggruppare le piante o usare un umidificatore"),
    ("Alejar la planta de estufas y aire acondicionado", "Allontanare la pianta da stufe e aria condizionata"),
    ("Recortar las puntas secas con tijera limpia", "Tagliare le punte secche con forbici pulite")])),
  opt(("Riego irregular o agua con mucho sarro", "Annaffiature irregolari o acqua molto calcarea"), cause(
   ("Sales acumuladas o riego irregular", "Accumulo di sali o annaffiature irregolari"),
   ("Las sales se concentran en las puntas y las queman.", "I sali si concentrano nelle punte e le bruciano."),
   [("Lavar el sustrato con abundante agua", "Lavare il terriccio con abbondante acqua"),
    ("Usar agua reposada o de lluvia", "Usare acqua lasciata decantare o piovana"),
    ("Regar de forma pareja", "Annaffiare in modo regolare")])),
  opt(("Fertilizo seguido", "Concimo spesso"), cause(
   ("Exceso de fertilizante", "Eccesso di concime"),
   ("Demasiado abono quema raíces y puntas.", "Troppo concime brucia radici e punte."),
   [("Suspender el abono 1 o 2 meses", "Sospendere il concime per 1-2 mesi"),
    ("Lavar el sustrato con abundante agua", "Lavare il terriccio con abbondante acqua"),
    ("Retomar con la mitad de la dosis", "Riprendere con metà dose")])),
 ]},
 {"id": "droop", "title": T("Hojas caídas o flácidas", "Foglie afflosciate o cadenti"), "question": T("¿Cómo está el sustrato?", "Com'è il terriccio?"), "options": [
  opt(("Seco", "Asciutto"), cause(("Falta de agua", "Mancanza d'acqua"),
   ("Las hojas pierden firmeza sin agua.", "Le foglie perdono turgore senza acqua."), WATER_STEPS)),
  opt(("Húmedo y con mal olor", "Umido e con cattivo odore"), cause(
   ("Pudrición de raíces", "Marciume radicale"),
   ("El exceso de agua mata las raíces y la planta se marchita igual.", "L'eccesso d'acqua uccide le radici e la pianta appassisce lo stesso."),
   [("Sacar la planta de la maceta y cortar las raíces podridas", "Estrarre la pianta dal vaso e tagliare le radici marce"),
    ("Usar sustrato nuevo con perlita y una maceta con drenaje", "Usare terriccio nuovo con perlite e un vaso con drenaggio"),
    ("Regar menos hasta que se recupere", "Annaffiare meno finché non si riprende")])),
  opt(("La cambié de lugar o la trasplanté", "L'ho spostata o rinvasata"), cause(
   ("Estrés por el cambio", "Stress da cambiamento"),
   ("Es una reacción normal de adaptación.", "È una normale reazione di adattamento."),
   [("Mantenerla estable 2 o 3 semanas", "Mantenerla stabile per 2-3 settimane"),
    ("Evitar corrientes de aire y sol directo nuevo", "Evitare correnti d'aria e nuovo sole diretto"),
    ("No fertilizar hasta que se recupere", "Non concimare finché non si riprende")])),
 ]},
 {"id": "spots", "title": T("Manchas en las hojas", "Macchie sulle foglie"), "question": T("¿Cómo son las manchas?", "Come sono le macchie?"), "options": [
  opt(("Secas, marrones o blancas, donde da el sol", "Secche, marroni o bianche, dove batte il sole"), cause(
   ("Quemadura solar", "Scottatura solare"),
   ("Recibe más luz de la que tolera.", "Riceve più luce di quella che tollera."),
   [("Mover la planta a luz filtrada", "Spostare la pianta in luce filtrata"),
    ("Medir su luz en la sección Medir", "Misurare la sua luce nella sezione Misura"),
    ("Acostumbrarla de a poco a más luz", "Abituarla gradualmente a più luce")])),
  opt(("Oscuras, húmedas, con halo amarillo", "Scure, umide, con alone giallo"), cause(
   ("Hongo o bacteria", "Fungo o batterio"),
   ("Suele deberse a hojas mojadas y poca ventilación.", "Di solito è dovuto a foglie bagnate e scarsa ventilazione."),
   [("Aislar la planta y cortar las hojas afectadas", "Isolare la pianta e tagliare le foglie colpite"),
    ("No mojar el follaje y mejorar la ventilación", "Non bagnare il fogliame e migliorare la ventilazione"),
    ("Si avanza, usar un fungicida apto, siguiendo la etiqueta", "Se avanza, usare un fungicida adatto seguendo l'etichetta")])),
  opt(("Puntitos finos o telaraña", "Puntini sottili o ragnatele"), cause(
   ("Posible plaga de ácaros", "Possibili acari"),
   ("Pican las células de la hoja y dejan puntos amarillos.", "Pungono le cellule della foglia e lasciano puntini gialli."),
   [("Mirar el envés de las hojas con una lupa", "Guardare il lato inferiore delle foglie con una lente"),
    ("Dar una ducha a las hojas y subir la humedad", "Fare una doccia alle foglie e aumentare l'umidità"), FOLLOW], "acaros")),
 ]},
 {"id": "leggy", "title": T("Crece larga y pálida", "Cresce lunga e pallida"), "question": T("¿Dónde está?", "Dove si trova?"), "options": [
  opt(("Lejos de la ventana o en un lugar oscuro", "Lontana dalla finestra o in un posto buio"), cause(
   ("Poca luz (etiolación)", "Poca luce (eziolamento)"),
   ("Se estira buscando luz.", "Si allunga cercando la luce."),
   [("Acercarla a una ventana luminosa", "Avvicinarla a una finestra luminosa"),
    ("Medir su luz y compararla con lo que necesita", "Misurare la sua luce e confrontarla con quella necessaria"),
    ("Si no alcanza, sumar una lámpara de cultivo unas 12 horas por día", "Se non basta, aggiungere una lampada da coltivazione per circa 12 ore al giorno")])),
  opt(("Cerca de una ventana con buena luz", "Vicino a una finestra con buona luce"), cause(
   ("Falta de nutrientes o frío", "Carenza di nutrienti o freddo"),
   ("Sin abono o con temperaturas bajas, el crecimiento es débil.", "Senza concime o con temperature basse, la crescita è debole."),
   [("Fertilizar con dosis suaves en la temporada de crecimiento", "Concimare con dosi leggere nella stagione di crescita"),
    ("Mantener la temperatura por encima del mínimo de la especie", "Mantenere la temperatura sopra il minimo della specie"),
    ("Revisar si las raíces llenaron la maceta", "Verificare se le radici hanno riempito il vaso")])),
 ]},
 {"id": "bugs", "title": T("Bichos o algo pegajoso", "Insetti o qualcosa di appiccicoso"), "question": T("¿Qué se ve?", "Cosa si vede?"), "options": [
  opt(("Algodoncito blanco", "Cotone bianco"), cause(("Cochinilla algodonosa", "Cocciniglia cotonosa"),
   ("Se alimenta de la savia y deja residuo pegajoso.", "Si nutre della linfa e lascia residuo appiccicoso."),
   [("Aislar la planta", "Isolare la pianta"), ("Quitar las visibles con un hisopo en alcohol", "Rimuovere quelle visibili con un cotton fioc con alcol"), FOLLOW], "cochinilla")),
  opt(("Mosquitas que salen del sustrato", "Moscerini che escono dal terriccio"), cause(("Mosquito del sustrato", "Moscerini del terriccio"),
   ("Las larvas viven en sustratos siempre húmedos.", "Le larve vivono in terricci sempre umidi."),
   [("Dejar secar la capa superior del sustrato", "Lasciare asciugare lo strato superficiale del terriccio"), ("Colocar trampas amarillas", "Posizionare trappole gialle"), FOLLOW], "mosquito")),
  opt(("Grupos verdes o negros en los brotes", "Gruppi verdi o neri sui germogli"), cause(("Pulgón", "Afidi"),
   ("Chupa la savia de los brotes tiernos.", "Succhia la linfa dei germogli teneri."),
   [("Quitarlos con un chorro de agua", "Rimuoverli con un getto d'acqua"), ("Aplicar jabón potásico", "Applicare sapone potassico"), FOLLOW], "pulgon")),
  opt(("Manchas plateadas y puntos negros", "Macchie argentate e puntini neri"), cause(("Trips", "Tripidi"),
   ("Raspan la hoja y dejan excrementos negros.", "Raschiano la foglia e lasciano escrementi neri."),
   [("Aislar la planta", "Isolare la pianta"), ("Colocar trampas azules pegajosas", "Posizionare trappole cromotropiche blu"), FOLLOW], "trips")),
  opt(("Insectos blancos que vuelan al mover la planta", "Insetti bianchi che volano scuotendo la pianta"), cause(("Mosca blanca", "Mosca bianca"),
   ("Chupa la savia desde el envés de las hojas.", "Succhia la linfa dal lato inferiore delle foglie."),
   [("Aislar la planta", "Isolare la pianta"), ("Colocar trampas amarillas", "Posizionare trappole gialle"), FOLLOW], "mosca_blanca")),
 ]},
]

(ASSETS / "pests.json").write_text(json.dumps({"version": 1, "pests": pests}, ensure_ascii=False, indent=1), encoding="utf-8")
(ASSETS / "consultorio.json").write_text(json.dumps({"version": 1, "symptoms": symptoms}, ensure_ascii=False, indent=1), encoding="utf-8")
print(len(pests), "plagas,", len(symptoms), "síntomas")
