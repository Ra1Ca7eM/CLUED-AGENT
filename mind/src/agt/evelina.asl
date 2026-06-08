{ include("playgrounds/hotel.asl") }

{ include("vesna.asl") }

/* ===== DIALOGO — Evelina (moglie di Aurelio) =====
 * Evelina dice SEMPRE la verita': risponde sincera a ogni domanda.
 * DOMANDE -> risposte dalle belief (gestore askOne di default).
 * Non sa nulla di pillole / digitalina.
 * Stessi funtori "generali" di Alberto, cosi' il routing dell'embedding e' uniforme. */

/* -- Posizione VIVA (presente): aggiornata mentre pattuglia -- */
current_position(evelina, Region) :- ntpp(evelina, Region).

/* -- Domande -> belief -- */
full_name(evelina).
your_identity(evelina, wife_of_aurelio).
profession(evelina, no_job_just_his_wife).
relationship(evelina, aurelio, married_to_him).
alibi_last_night(evelina, in_my_room_with_clarissa).
suspected_killer(aurelio, vittorio).

/* -- Medicina: sa solo che Aurelio prendeva pillole per il cuore; nulla sulla digitalina -- */
heart_pills(evelina, knew_heart_pills).
digitalis_bottle(evelina, i_know_nothing).

/* -- Accendino: non fuma; sa che Aurelio non fumava -- */
your_lighter(evelina, i_dont_smoke).
aurelio_lighter(aurelio, did_not_smoke).

/* -- Qualsiasi AFFERMAZIONE del giocatore (mittente = player) -> risposta onesta neutra.
 *    Evita il freeze della chat quando il giocatore afferma invece di chiedere.
 *    Legato ad 'player' per non intercettare i messaggi tra agenti. -- */
+!kqml_received( player, tell, _, _ )
    <-  .send( player, tell, honest_reply(evelina) ).

+!start
    :   .my_name(Me)
    <-  +ntpp(Me, salone);
        +my_room(room1);
        !startup_delay;
        !patrol_random_loop.
