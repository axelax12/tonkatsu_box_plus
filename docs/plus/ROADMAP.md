# Tonkatsu Box Plus — Roadmap

Fork personale di [Tonkatsu Box](https://github.com/hacan359/tonkatsu_box) (MIT), pensato per **Android**.
Obiettivo: un unico posto per giochi, libri, film, anime e manga, che non si limita a catalogare
ma racconta il tuo rapporto con le opere.

## Principi

- **Solo Android.** Le build e i test riguardano Android. Il codice resta condiviso con desktop e web
  solo perché l'app originale è fatta così: non lo rompiamo, ma non sviluppiamo per quelle piattaforme.
- **Prima i dati, poi le schermate.** Ogni funzione nasce da un modello dati solido, con migrazioni
  del database solo in aggiunta (mai modificare quelle esistenti) e test automatici.
- **Locale e privato.** Niente account e niente cloud obbligatori, come nell'app originale.
- **Anti-spoiler di default.** Tutto ciò che può rovinare una sorpresa è nascosto finché non lo chiedi.
- **Vicini all'originale.** Le nostre funzioni vivono in moduli separati, così possiamo continuare a
  riallinearci con gli aggiornamenti di Tonkatsu Box.

## Fase 0 — Infrastruttura ✅

- [x] Fork e identità Android separata (`com.axelax12.tonkatsuboxplus`): si installa accanto all'app originale.
- [x] CI su GitHub Actions: analisi, test, generazione del codice, APK pubblicato come release.
- [ ] Chiave di firma nei segreti GitHub, così ogni aggiornamento si installa sopra il precedente.
- [x] Interfaccia: resta in inglese (scelta di novembre 2026).

## Fase 1 — Il diario (fondamenta) ✅

Quasi tutto il resto si appoggia qui: ore giocate, riepilogo annuale, widget con timer, "dove ero rimasto".

1. **Diario delle esperienze.** Una timeline per ogni opera e una generale: sessioni, note, citazioni,
   screenshot e impressioni datate. Ogni voce può essere marcata come spoiler.
2. **Sessioni con timer.** Avvia e ferma una sessione (gioco, lettura, visione); il tempo totale e le
   statistiche nascono dalle sessioni invece che da un numero inserito a mano. Streak e calendario a heatmap.
3. **Più passaggi per opera.** Ogni playthrough, rilettura o rewatch ha date, piattaforma, voto e
   recensione propri, così puoi confrontare la prima volta con quella di anni dopo.
4. **"Dove ero rimasto?"** Un segnalibro strutturato per riprendere dopo mesi: punto raggiunto, note,
   personaggi ed eventi annotati. Per i giochi: missione attuale, comandi da ricordare, prossimo
   obiettivo. In futuro, eventuali riassunti automatici useranno solo contenuti fino al punto raggiunto.

## Fase 2 — Obiettivi e numeri ✅

5. **Obiettivi annuali** (stile StoryGraph): opere finite per tipo, ore, pagine, backlog smaltito.
   Più obiettivi in parallelo, con anello di avanzamento in home.
6. **Salute del backlog.** Età media del backlog, ritmo con cui lo smaltisci, stima del tempo per
   finirlo tutto usando i tempi di completamento di IGDB e la tua velocità reale.
7. **Riepilogo dell'anno** (stile Wrapped). Statistiche più racconto: le opere che hanno segnato
   l'anno, citazioni e impressioni dal diario. Condivisibile come immagine, partendo dalla share card esistente.

## Fase 3 — Collezioni intelligenti e home ✅ (la home passa alla Fase 8)

8. **Collezioni automatiche con regole.** Liste che si aggiornano da sole, ad esempio:
   - giochi posseduti, mai iniziati, completabili in meno di 10 ore;
   - anime interrotti a meno di cinque episodi dalla fine;
   - libri di autori giapponesi ancora da leggere.

   Qualsiasi ricerca filtrata si può salvare come collezione dinamica.
9. **Home personalizzabile a sezioni.** Scegli, ordini e nascondi le sezioni: riprendi, obiettivi,
   collezioni automatiche, uscite, salute del backlog.

## Fase 4 — Il collezionista ✅

10. **Collezione fisica.** Edizione, condizione, prezzo pagato, dove e quando l'hai comprato,
    prestiti agli amici con promemoria di restituzione.
11. **Stanza del collezionista.** Vista opzionale con scaffali personalizzabili, copertine, oggetti e
    piccoli ricordi sbloccati completando opere. Toccando una copertina apri la scheda; la stanza si
    può esportare come immagine da condividere.

## Fase 5 — Android e integrazioni ✅

12. **Widget per la home di Android.** Opera in corso con avvia/ferma sessione, obiettivi dell'anno.
13. **Notifiche.** Uscite delle opere in wishlist, timer di sessione attivo, prestiti in scadenza.
14. **Achievement Steam.** Oltre a quelli di RetroAchievements già supportati.
15. **Prezzi della wishlist** tramite IsThereAnyDeal, con avviso al minimo storico.

## Fase 6 — Universi tra media diversi ✅

16. **Universi e percorsi.** Collega libri, film, anime, manga e giochi dello stesso universo, con ordine
    di pubblicazione, cronologico e consigliato ("Voglio iniziare Gundam: da dove parto?").
    Ogni percorso ha avanzamento complessivo, tappe facoltative e collegamenti nascosti per evitare
    spoiler. Include i progressi nelle saghe. Si parte dai dati di IGDB (franchise), TMDB (collezioni)
    e AniList (relazioni), più percorsi creati a mano ed esportabili.
17. **Esplorazione per temi.** Percorsi come "horror cosmico", "intrighi politici nello spazio" o
    "Giappone rurale", con opere di media diversi e una motivazione per ciascuna. Da un titolo amato
    scegli cosa ritrovare: atmosfera, ambientazione, temi o struttura narrativa.

Stato: percorsi con i tre ordini, tappe facoltative e spoiler, suggerimenti per titolo dalla libreria,
sezione nella scheda opera ed esplorazione per aspetto (generi più tag personali), proposte dei giochi
della stessa serie da franchise e collezioni IGDB, dei film della stessa collezione TMDB e degli
anime/manga collegati dalle relazioni AniList, condivisione dei percorsi come testo da incollare in chat
e importazione.

## Fase 7 — Insieme ✅ (club esclusi)

18. **Modalità "Scegliamo insieme".** Selezioni due o più profili e l'app propone titoli che nessuno
    ha già visto, compatibili con gusti e tempo disponibile; ognuno vota o scarta.
19. **Club** di lettura, visione o gioco, con progressi individuali e discussioni protette dagli spoiler.
    Richiede una forma di sincronizzazione tra dispositivi: da valutare dopo la Fase 6.

Stato: "Scegliamo insieme" legge in sola lettura le librerie degli altri profili sullo stesso telefono,
accetta ospiti senza profilo e si vota passandosi il telefono. I club restano in attesa della sincronizzazione.

## Fase 8 — Restyling "copertine protagoniste" 🚧

Dopo le funzioni, un restyling unico e coerente in stile GameTrack/Letterboxd: copertine grandi,
sfondi sfocati presi dalla copertina, colori che si adattano all'opera. Risolve i punti segnalati:

- **Troppe opzioni ovunque:** menu e impostazioni ridotti all'essenziale, il resto in "Avanzate".
- **Scheda opera caotica:** gerarchia chiara (copertina, stato, diario, avanzamento), sezioni secondarie raccolte.
- **Home poco utile:** nuova home con "In corso", anello degli obiettivi, riprendi e uscite.
- **Cercare e aggiungere:** ricerca più diretta e aggiunta in un tocco con stato già impostato.

Stato (prima tranche): home "Oggi" su telefono con opera in corso in primo piano (copertina sfocata,
"dove ero rimasto", avvio sessione), obiettivi, prossime tappe, uscite, backlog e liste, con sezioni da
ordinare e nascondere; nella scheda opera le sezioni del fork riunite in una riga di schede; stato
predefinito per le nuove aggiunte e scorciatoia dopo l'aggiunta; impostazioni rare raccolte in "Avanzate";
colore d'accento della scheda preso dalla copertina; copertina sfocata come sfondo per le opere senza artwork.

## Come lavoriamo

- Ogni funzione vive su un branch `feature/<nome>`. A ogni push la CI genera il codice, lancia analisi
  e test e pubblica un APK di prova nella pagina Releases del fork.
- Quando la funzione è pronta e provata sul telefono, il branch confluisce in `main`.
- I log completi della CI finiscono nel branch `ci-results/<branch>`.
