{ include("playgrounds/hotel.asl") }

{ include("vesna.asl") }

/* ===== DIALOGO — Vittorio (architetto, amico di vecchia data) =====
 * Vittorio dice SEMPRE la verita': risponde sincero a ogni domanda.
 * DOMANDE -> risposte dalle belief (gestore askOne di default).
 * Non sa nulla di pillole / digitalina.
 * Stessi funtori "generali" di Alberto, cosi' il routing dell'embedding e' uniforme. */

/* -- Posizione VIVA (presente): aggiornata mentre pattuglia -- */
current_position(vittorio, Region) :- ntpp(vittorio, Region).

/* -- Domande -> belief -- */
full_name(vittorio).
your_identity(vittorio, architect_old_friend_of_aurelio).
profession(vittorio, architect).
relationship(vittorio, aurelio, old_friends).
alibi_last_night(vittorio, restless_in_the_salon_then_argued_with_aurelio).
suspected_killer(aurelio, clarissa).

/* -- Non sa nulla di pillole / digitalina -- */
heart_pills(vittorio, i_know_nothing).
digitalis_bottle(vittorio, i_know_nothing).

/* -- Accendino: non fuma; sa che Aurelio non fumava -- */
your_lighter(vittorio, i_dont_smoke).
aurelio_lighter(aurelio, did_not_smoke).

/* -- Qualsiasi AFFERMAZIONE del giocatore (mittente = player) -> risposta onesta neutra. -- */
+!kqml_received( player, tell, _, _ )
    <-  .send( player, tell, honest_reply(vittorio) ).

+!start
    :   .my_name(Me)
    <-  +ntpp(Me, salone);
        +my_room(room3);
        !startup_delay;
        !patrol_random_loop.
