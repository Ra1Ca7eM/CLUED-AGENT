/* Game Master - final-accusation agent (no VEsNA body, like player).
 *
 * The player presses ESC in Godot and states the final accusation: WHO did it,
 * WITH WHAT, and WHY. ChatBDI extracts it into solution(Who, What, Why) and the
 * interpreter (player) routes it here as a tell. This agent does the REASONING:
 * it scores the accusation against the canonical solution and replies with a
 * verdict result(gamemaster, solved | not_yet | retry).
 *
 * EVERYTHING IN ENGLISH (functor, atoms, plans, player input): all-minilm is weak
 * on Italian, so same-language routing works (see alberto.asl).
 *
 * ROUTING NOTE: ChatBDI routes a tell by searching the embedding TERMS subspace (beliefs)
 * and ALSO indexes plan CONTEXTS, but NOT plan bodies. So:
 *   - the ONLY indexable belief here is the routing-decoy solution/3, with NEUTRAL atoms
 *     (no_who/no_what/no_why): it guarantees the accusation is routed to this agent, never
 *     earns a point, and avoids the "poison trap" (the extractor can't copy a meaningful value);
 *   - the accepted synonyms (alberto/digitalina/poison/...) live INSIDE plan BODIES (.member
 *     lists), which are NOT indexed, so accusation words never pollute routing. Putting them in
 *     beliefs or plan contexts would make e.g. "poison" steal the routing from solution/3.
 */

/* ---------- ROUTING-DECOY BELIEF (the only indexable, accusation-like functor) ---------- */
solution(no_who, no_what, no_why).

/* ---------- EVALUATION PLAN: the accusation arrives as a tell from player ----------
 * Scoring weights: who=50 (naming the killer is mandatory), what=25, why=25; pass at 70.
 * who alone = 50 (< 70 -> not_yet); who + any one extra = 75 (>= 70 -> solved). */
+!kqml_received( player, tell, solution(Who, What, Why), _ )
    <-  !score_who( Who, SW );
        !score_what( What, SH );
        !score_why( Why, SY );
        Total = SW + SH + SY;
        if ( Total >= 70 ) {
            .send( player, tell, result(gamemaster, solved) );
        } else {
            .send( player, tell, result(gamemaster, not_yet) );
        }.

/* Per-slot scoring. The accepted-value lists are in the BODY (not indexed for routing).
 * .ground guards a missing argument (extracted as an unbound "_") so it scores 0. */
+!score_who( G, S )
    <-  if ( .ground(G) & .member( G, [alberto] ) ) { S = 50; } else { S = 0; }.
+!score_what( G, S )
    <-  if ( .ground(G) & .member( G, [digitalina, digitalis, poison, foxglove, digoxin] ) ) { S = 25; } else { S = 0; }.
+!score_why( G, S )
    <-  if ( .ground(G) & .member( G, [avoid_denunciation, denunciation, reported, exposed, discovered, embezzlement, fraud, theft] ) ) { S = 25; } else { S = 0; }.

/* Anti-garbage: if the accusation was misclassified as askOne, Jason answers it from the BB
 * (the neutral decoy) WITHOUT running the scoring plan; intercept it and ask to restate. */
+!kqml_received( player, askOne, solution(_,_,_), _ )
    <-  .send( player, tell, result(gamemaster, retry) ).

/* Fallback (anti-freeze): extraction failed or off-topic message -> ask to restate. */
+!kqml_received( player, tell, _, _ )
    <-  .send( player, tell, result(gamemaster, retry) ).
