// Comportamenti navigazione Hotel Valtieri (equivalente playgrounds/office/officer.asl)

// nav_goal(Target) = destinazione esplicita di questo spostamento (walk al centro solo se nav_goal o POI)

+!cammina_a( Target )
    <-  +nav_goal( Target );
        !go_to( Target );
        -nav_goal( Target ).

+!vado_in_giardino
    <-  !cammina_a( giardino ).

+!vado_in_cantina
    <-  !cammina_a( cantina ).

+!vado_in_cucina
    <-  !cammina_a( cucina ).

+!vado_in_room1
    <-  !cammina_a( room1 ).

+!vado_in_room3
    <-  !cammina_a( room3 ).

+!vado_in_room4
    <-  !cammina_a( room4 ).

+!vado_in_room5
    <-  !cammina_a( room5 ).

+!vado_in_room6
    <-  !cammina_a( room6 ).

+!startup_delay
    <-  .random( R );
        .wait( 2000 + R * 18000 ).

+!pick_random_poi( Exclude, Target )
    <-  .findall( P, walk_poi( P ), All );
        if ( .member( Exclude, All ) ) {
            .delete( Exclude, All, Pool );
        } else {
            Pool = All;
        };
        .length( Pool, N );
        .random( R );
        I = math.floor( R * N );
        .nth( I, Pool, Target ).

+!patrol_random_loop
    :   not last_poi( _ )
    <-  !pick_random_poi( none, Target );
        .print( "Patrol target: ", Target );
        !cammina_a( Target );
        .wait( 5000 );
        +last_poi( Target );
        !patrol_random_loop.

+!patrol_random_loop
    :   last_poi( Prev )
    <-  !pick_random_poi( Prev, Target );
        .print( "Patrol target: ", Target );
        !cammina_a( Target );
        .wait( 5000 );
        -last_poi( Prev );
        +last_poi( Target );
        !patrol_random_loop.

-!patrol_random_loop
    <-  .print( "Patrol failed — retrying in 5s" );
        .wait( 5000 );
        !patrol_random_loop.
