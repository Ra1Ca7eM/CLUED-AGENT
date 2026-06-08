{ include("playgrounds/hotel.asl") }

{ include("vesna.asl") }

/* ===== DIALOGO — Clarissa (direttrice dell'hotel) =====
 * Clarissa dice SEMPRE la verita': risponde sincera a ogni domanda.
 * DOMANDE -> risposte dalle belief (gestore askOne di default).
 * Non sa nulla di pillole / digitalina.
 * Stessi funtori "generali" di Alberto, cosi' il routing dell'embedding e' uniforme. */

/* -- Posizione VIVA (presente): aggiornata mentre pattuglia -- */
current_position(clarissa, Region) :- ntpp(clarissa, Region).

/* -- Domande -> belief -- */
full_name(clarissa).
your_identity(clarissa, hotel_director).
profession(clarissa, manages_the_hotel).
relationship(clarissa, aurelio, his_employee).
alibi_last_night(clarissa, gave_evelina_a_letter_then_stayed_with_her).
suspected_killer(aurelio, alberto).

/* -- Non sa nulla di pillole / digitalina -- */
heart_pills(clarissa, i_know_nothing).
digitalis_bottle(clarissa, i_know_nothing).

/* -- Accendino: non fuma; sa che Aurelio non fumava -- */
your_lighter(clarissa, i_dont_smoke).
aurelio_lighter(aurelio, did_not_smoke).

/* -- Qualsiasi AFFERMAZIONE del giocatore (mittente = player) -> risposta onesta neutra. -- */
+!kqml_received( player, tell, _, _ )
    <-  .send( player, tell, honest_reply(clarissa) ).

+!start
    :   .my_name(Me)
    <-  +ntpp(Me, salone);
        +my_room(room4);
        !startup_delay;
        !patrol_random_loop.
