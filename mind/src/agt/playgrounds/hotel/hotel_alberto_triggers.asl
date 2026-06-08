// Trigger reattivi Alberto: patrol differito in base alla posizione del player

+digitalina_inspected( _, _ )
    <-  .print( "Player inspected digitalina — relocate mission enabled" );
        +digitalina_inspected.

+pillole_wc_inspected( _, _ )
    <-  .print( "Player inspected pillole WC — flush mission enabled" );
        +pillole_wc_inspected.

+player_entered( Room, _ )
    <-  .print( "Player entered: ", Room );
        +player_in( Room ).

+player_exited( Room, _ )
    <-  .print( "Player left: ", Room );
        -player_in( Room ).

+!alberto_relocate_digitalina
    <-  .print( "Alberto: relocating digitalina" );
        !cammina_a( cantina_boccetta );
        !grab( boccetta_digitalina );
        !cammina_a( albertoRoom_digitalina_release );
        !release( boccetta_digitalina );
        +digitalina_relocated;
        .print( "Alberto: digitalina relocated" ).

-!alberto_relocate_digitalina
    <-  .print( "Alberto: digitalina relocate failed — will retry" );
        .wait( 5000 );
        !alberto_relocate_digitalina.

+!alberto_hide_pillole_wc
    <-  .print( "Alberto: hiding pillole at WC" );
        !cammina_a( bagno_wc );
        .wait( 10000 );
        lookupArtifact( hotel_ambience, ArtId );
        focus( ArtId );
        wc_flush[ artifact_id( ArtId ) ];
        +pillole_wc_flushed;
        .print( "Alberto: pillole WC flushed" ).

-!alberto_hide_pillole_wc
    <-  .print( "Alberto: pillole WC flush failed — will retry" );
        .wait( 5000 );
        !alberto_hide_pillole_wc.

+!pick_patrol_target( Target, PlayerTriggered )
    :   player_in( room5 )
    <-  Target = albertoRoom_chiave;
        PlayerTriggered = true;
        .print( "Player-triggered patrol to ", Target ).

+!pick_patrol_target( Target, PlayerTriggered )
    :   player_in( cantina )
    <-  Target = cantina;
        PlayerTriggered = true;
        .print( "Player-triggered patrol to ", Target ).

+!pick_patrol_target( Target, PlayerTriggered )
    :   last_poi( Prev )
    <-  !pick_random_poi( Prev, Target );
        PlayerTriggered = false;
        .print( "Random patrol to ", Target ).

+!pick_patrol_target( Target, PlayerTriggered )
    <-  !pick_random_poi( none, Target );
        PlayerTriggered = false;
        .print( "Random patrol to ", Target ).

+!alberto_patrol_loop
    :   digitalina_inspected & not digitalina_relocated
    <-  !alberto_relocate_digitalina;
        !alberto_patrol_loop.

+!alberto_patrol_loop
    :   pillole_wc_inspected & not pillole_wc_flushed
    <-  !alberto_hide_pillole_wc;
        !alberto_patrol_loop.

+!alberto_patrol_loop
    :   last_poi( Prev )
    <-  !pick_patrol_target( Target, PlayerTriggered );
        !cammina_a( Target );
        if ( PlayerTriggered ) {
            .wait( 10000 );
        } else {
            .wait( 5000 );
        };
        -last_poi( Prev );
        +last_poi( Target );
        !alberto_patrol_loop.

+!alberto_patrol_loop
    :   not last_poi( _ )
    <-  !pick_patrol_target( Target, PlayerTriggered );
        !cammina_a( Target );
        if ( PlayerTriggered ) {
            .wait( 10000 );
        } else {
            .wait( 5000 );
        };
        +last_poi( Target );
        !alberto_patrol_loop.

-!alberto_patrol_loop
    <-  .print( "Alberto patrol failed — retrying in 5s" );
        .wait( 5000 );
        !alberto_patrol_loop.
