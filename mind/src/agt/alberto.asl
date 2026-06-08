{ include("playgrounds/hotel.asl") }

{ include("playgrounds/hotel/hotel_alberto_triggers.asl") }

{ include("vesna.asl") }

/* DIALOGO (Tappa 2) — posizione VIVA.
 * current_position legge la posizione corrente dell'agente (ntpp, aggiornata mentre pattuglia),
 * cosi' alla domanda "where are you now?" risponde con la stanza reale del momento.
 * Funtore deliberatamente distinto da alibi_last_night (alibi di ieri sera): i due nomi non
 * condividono parole generiche ("where/are/you"), cosi' l'embedding non li confonde. */
current_position(alberto, Region) :- ntpp(alberto, Region).

/* ===== DIALOGO (Tappa 3) — persona completa + memoria delle azioni =====
 * DOMANDE -> risposte dalle belief (gestore askOne di default).
 * AFFERMAZIONI del giocatore -> piani +!kqml_received(player, tell, ...).
 * I piani sono legati al mittente 'player' (l'interprete): cosi' NON intercettano
 * i messaggi tra agenti (officer, segnali, ecc.), che restano gestiti di default. */

/* -- Domande -> belief -- */
full_name(alberto).
your_identity(alberto, childhood_friend_of_aurelio).
profession(alberto, family_doctor).               // "what do you do" e "what's your job" -> stessa risposta unificata
relationship(alberto, aurelio, childhood_friends).
alibi_last_night(alberto, smoking_a_cigar_alone_in_my_room).
suspected_killer(aurelio, evelina).
cigar_lighter(alberto, spare_matches).             // "how did you light the cigar?"
your_lighter(alberto, mine).                       // "is the lighter yours?" -> e' suo
aurelio_lighter(aurelio, did_not_smoke).           // "was the lighter Aurelio's?" -> non fumava

/* -- Belief-esca: rendono i funtori delle affermazioni visibili al routing dei tell.
 * NB: funtori-FRASE (non nomi nudi come "evelina"/"vittorio"): un nome proprio come funtore
 * ("evelina" x4 nel preprocess) attira le domande d'identita' ("who are you") sul funtore
 * sbagliato. Le frasi descrittive agganciano l'affermazione del player senza collidere. -- */
asked_for_keys(alberto, clarissa).
met_vittorio_salon(alberto).
entered_evelina_room(alberto).
accusation(alberto, you).
digitalis_bottle(alberto, bottle).
heart_pills(alberto, nadolol).

/* -- Reazioni alle AFFERMAZIONI del giocatore (mittente = player) -- */
+!kqml_received( player, tell, asked_for_keys(_,_), _ )
    <-  .send( player, tell, admission(alberto, keys) ).

+!kqml_received( player, tell, met_vittorio_salon(_), _ )
    <-  .send( player, tell, admission(alberto, vittorio) ).

+!kqml_received( player, tell, entered_evelina_room(_), _ )
    <-  .send( player, tell, admission(alberto, evelina) ).

+!kqml_received( player, tell, accusation(_,_), _ )
    <-  .send( player, tell, defense(alberto) ).

/* MEMORIA DELLE AZIONI: la reazione su digitalina/pillole dipende SOLO dai flag VEsNA.
 * digitalina_relocated / pillole_wc_flushed sono asserite dai trigger VEsNA quando Alberto
 * sposta la boccetta / scarica le pillole nel WC (guardata prima, poi default).
 * NB: la stessa logica vale SIA per le AFFERMAZIONI (tell) SIA per le DOMANDE (askOne):
 * l'askOne viene intercettato dal piano (come fa il gamemaster), cosi' NON risponde dalla
 * belief statica e l'esito e' coerente con l'azione realmente eseguita da VEsNA. */
+!kqml_received( player, tell, digitalis_bottle(_,_), _ ) : digitalina_relocated
    <-  .send( player, tell, nervous_denial(alberto, digitalina) ).
+!kqml_received( player, tell, digitalis_bottle(_,_), _ )
    <-  .send( player, tell, calm_denial(alberto, digitalina) ).
+!kqml_received( player, askOne, digitalis_bottle(_,_), _ ) : digitalina_relocated
    <-  .send( player, tell, nervous_denial(alberto, digitalina) ).
+!kqml_received( player, askOne, digitalis_bottle(_,_), _ )
    <-  .send( player, tell, calm_denial(alberto, digitalina) ).

+!kqml_received( player, tell, heart_pills(_,_), _ ) : pillole_wc_flushed
    <-  .send( player, tell, nervous_denial(alberto, pills) ).
+!kqml_received( player, tell, heart_pills(_,_), _ )
    <-  .send( player, tell, calm_denial(alberto, pills) ).
+!kqml_received( player, askOne, heart_pills(_,_), _ ) : pillole_wc_flushed
    <-  .send( player, tell, nervous_denial(alberto, pills) ).
+!kqml_received( player, askOne, heart_pills(_,_), _ )
    <-  .send( player, tell, calm_denial(alberto, pills) ).

/* Fallback: qualsiasi altra affermazione del giocatore -> deflect (niente freeze del dialogo) */
+!kqml_received( player, tell, _, _ )
    <-  .send( player, tell, deflect(alberto) ).

+!start
    :   .my_name(Me)
    <-  +ntpp(Me, salone);
        +my_room(room5);
        !startup_delay;
        !alberto_patrol_loop.
