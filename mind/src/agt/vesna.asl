// RCC Rules
po( X, Y ) :- map_po( X, Y ).
po( Y, X ) :- map_po( X, Y ).

ntpp( X, Y ) :- map_ntpp( X, Y ).
ntppi( Y, X ) :- map_ntpp( X, Y ).

ec( X, Y ) :- map_ec( X, Y ).
ec( Y, X ) :- map_ec( X, Y ).

same_region( Region1, Region2 ) :- ntpp( Region1, SuperRegion ) & ntpp( Region2, SuperRegion ).

// Già nella zona target (ntpp simbolico allineato)
+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, Target )
    <-  .print( "Already at ", Target, " (ntpp), nothing to do." ).

// Zone portal
+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & not ntpp( Me, Target )
        & portal_zone( Target )
        & portal_entry( Target, EntryRegion, _ ) & not ntpp( Me, EntryRegion )
    <-  .print( "Portal entry to ", Target, " via ", EntryRegion );
        !go_to( EntryRegion );
        !go_to( Target ).

+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & not ntpp( Me, Target )
        & portal_zone( MyRegion )
        & portal_exit( MyRegion, ExitRegion, _ ) & not ntpp( Me, ExitRegion )
        & not Target == ExitRegion
    <-  .print( "Portal exit from ", MyRegion, " via ", ExitRegion );
        !go_to( ExitRegion );
        !go_to( Target ).

// Porta + walk al centro (destinazione esplicita o POI)
+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & not ntpp( Me, Target )
        & map_ntpp( Target, hotel ) & requires_door( MyRegion, Target, Door )
        & needs_center_walk( Target )
    <-  .print( "Going to ", Target, " via door ", Door, " (center walk)" );
        -crossing_context( _, _ );
        +crossing_context( Door, Target );
        vesna.walk( Door, _ );
        .wait( { +movement( completed, destination_reached ) } );
        .wait( 2000 );
        !open_door( Door );
        vesna.walk( Target, _ );
        .wait( { +movement( completed, destination_reached ) } );
        -ntpp( Me, _ );
        +ntpp( Me, Target );
        -crossing_context( Door, Target );
        .print( "Arrived at ", Target, "." ).

// Porta + arrivo simbolico (transito verso altra nav_goal)
+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & not ntpp( Me, Target )
        & map_ntpp( Target, hotel ) & requires_door( MyRegion, Target, Door )
        & not needs_center_walk( Target )
    <-  .print( "Going to ", Target, " via door ", Door, " (symbolic after door)" );
        -crossing_context( _, _ );
        +crossing_context( Door, Target );
        vesna.walk( Door, _ );
        .wait( { +movement( completed, destination_reached ) } );
        .wait( 2000 );
        !open_door( Door );
        .print( "Past door ", Door, " — symbolic arrival at ", Target );
        -ntpp( Me, _ );
        +ntpp( Me, Target );
        -crossing_context( Door, Target );
        .print( "Arrived at ", Target, " (symbolic)." ).

// ec + centro zona (destinazione esplicita)
+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & not ntpp( Me, Target )
        & map_ntpp( Target, hotel ) & ec( MyRegion, Target )
        & needs_center_walk( Target )
    <-  .print( "Vado a ", Target, " (navmesh, ec)" );
        vesna.walk( Target, _ );
        .wait( { +movement( completed, destination_reached ) } );
        -ntpp( Me, _ );
        +ntpp( Me, Target );
        .print( "Arrivato a ", Target, "." ).

// ec transito simbolico
+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & not ntpp( Me, Target )
        & map_ntpp( Target, hotel ) & ec( MyRegion, Target )
        & not needs_center_walk( Target )
    <-  .print( "Ec transit ", MyRegion, " → ", Target, " (symbolic, no center walk)" );
        -ntpp( Me, _ );
        +ntpp( Me, Target );
        .print( "Arrivato a ", Target, " (symbolic)." ).

+!go_to( Target )
    :   .my_name( Me ) & same_region( Me, Target )
    <-  .print( "I want to go to ", Target, " and we are in the same region" );
        vesna.walk( Target, _ );
        .wait( {+movement( completed, destination_reached ) } );
        -at( Me, _ );
        +at( Me, Target );
        .print( "I arrived to ", Target ).

// POI oltre porta
+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & ntpp( Target, TargetRegion )
        & po( MyRegion, Door ) & po( Door, TargetRegion ) & poi_target( Target )
    <-  .print( "Going to POI ", Target, " via door ", Door );
        -crossing_context( _, _ );
        +crossing_context( Door, Target );
        vesna.walk( Door, _ );
        .wait( { +movement( completed, destination_reached ) } );
        .wait( 2000 );
        !open_door( Door );
        vesna.walk( Target, _ );
        .wait( { +movement( completed, destination_reached ) } );
        -ntpp( Me, _ );
        +ntpp( Me, TargetRegion );
        .print( "Arrived at POI ", Target ).

// Zona oltre porta + centro esplicito
+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & ntpp( Target, TargetRegion )
        & po( MyRegion, Door ) & po( Door, TargetRegion )
        & not poi_target( Target ) & needs_center_walk( TargetRegion )
    <-  .print( "Going to ", TargetRegion, " via door ", Door, " (center)" );
        -crossing_context( _, _ );
        +crossing_context( Door, TargetRegion );
        vesna.walk( Door, _ );
        .wait( { +movement( completed, destination_reached ) } );
        .wait( 2000 );
        !open_door( Door );
        vesna.walk( TargetRegion, _ );
        .wait( { +movement( completed, destination_reached ) } );
        -ntpp( Me, _ );
        +ntpp( Me, TargetRegion );
        -crossing_context( Door, TargetRegion );
        .print( "Arrived at ", TargetRegion ).

// Zona oltre porta transito simbolico
+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & ntpp( Target, TargetRegion )
        & po( MyRegion, Door ) & po( Door, TargetRegion )
        & not poi_target( Target ) & not needs_center_walk( TargetRegion )
    <-  .print( "Symbolic entry to ", TargetRegion, " via ", Door );
        -crossing_context( _, _ );
        +crossing_context( Door, TargetRegion );
        vesna.walk( Door, _ );
        .wait( { +movement( completed, destination_reached ) } );
        .wait( 2000 );
        !open_door( Door );
        -ntpp( Me, _ );
        +ntpp( Me, TargetRegion );
        -crossing_context( Door, TargetRegion );
        .print( "Arrived at ", TargetRegion, " (symbolic)." ).

+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & ntpp( Target, TargetRegion )
        & ec( MyRegion, Corridor) & ec( Corridor, TargetRegion )
    <-  .print( "Via corridor ", Corridor, " to ", TargetRegion );
        Path = [ Corridor, TargetRegion ];
        !follow_path( Path );
        !go_to( Target ).

// BFS pathfinding
+!go_to( Target )
    :   .my_name( Me ) & ntpp( Me, MyRegion ) & ntpp( Target, TargetRegion )
        & not ntpp( Me, Target )
        & not ( portal_entry( Target, EntryRegion, _ ) & not ntpp( Me, EntryRegion ) )
        & not ( portal_exit( MyRegion, ExitRegion, _ ) & not ntpp( Me, ExitRegion ) )
    <-  .print( "I am really far away, I have to reason a bit logically..." );
        // Cammino PIU' CORTO (non il primo della DFS): enumero tutti i cammini semplici, li
        // accoppio con la loro lunghezza e prendo il minimo. Cosi' verso la cantina sceglie la
        // scala diretta (es. ovest) invece di un giro piu' lungo (est + attraversamento).
        if ( poi_target( Target ) ) {
            .findall( pair( L, P ), ( find_path_recursive( MyRegion, TargetRegion, [ MyRegion ], P ) & .length( P, L ) ), Pairs );
            .min( Pairs, pair( _, RPath ) );
            PathDest = TargetRegion;
        } else {
            .findall( pair( L, P ), ( find_path_recursive( MyRegion, Target, [ MyRegion ], P ) & .length( P, L ) ), Pairs );
            .min( Pairs, pair( _, RPath ) );
            PathDest = Target;
        }
        .delete( MyRegion, RPath, LPath );
        .reverse( LPath, Path );
        .print( "Route plan from ", MyRegion, " to ", PathDest, " (goal ", Target, "): ", Path );
        !follow_path( Path );
        !finish_route_to( Target ).

+!finish_route_to( Target )
    :   poi_target( Target )
    <-  !go_to( Target ).

+!finish_route_to( Target )
    :   needs_center_walk( Target )
    <-  !go_to( Target ).

+!finish_route_to( Target )
    :   not poi_target( Target ) & not needs_center_walk( Target ) & not ntpp( Me, Target )
    <-  -ntpp( Me, _ );
        +ntpp( Me, Target );
        .print( "Route complete — ", Target, " reached symbolically." ).

+!finish_route_to( Target )
    :   ntpp( Me, Target )
    <-  .print( "Route complete — already at ", Target, "." ).

-!go_to( Target )
    <-  .print( "Cannot go_to ", Target, " — no applicable plan." ).

+!follow_path( [] )
    <-  .print( "Destination reached" ).

// Porta con nav_goal attivo (recovery verso destinazione finale)
+!follow_path( [ Head | Tail ] )
    :   .my_name( Me ) & door_art( Head ) & nav_goal( Goal )
    <-  .print( "Moving to door ", Head, " (goal ", Goal, ") : ", Tail );
        -crossing_context( _, _ );
        +crossing_context( Head, Goal );
        vesna.walk( Head );
        .wait( {+movement( completed, destination_reached ) } );
        .wait( 2000 );
        !open_door( Head );
        if ( not Tail == [] ) {
            ?door_passage_region( Head, Tail, Passage );
            -ntpp( Me, _ );
            +ntpp( Me, Passage );
        }
        !follow_path( Tail ).

// Porta senza nav_goal (transito)
+!follow_path( [ Head | Tail ] )
    :   .my_name( Me ) & door_art( Head ) & not nav_goal( _ ) & not Tail == []
    <-  .print( "Moving to door ", Head, " : ", Tail );
        ?door_passage_region( Head, Tail, Passage );
        -crossing_context( _, _ );
        +crossing_context( Head, Passage );
        vesna.walk( Head );
        .wait( {+movement( completed, destination_reached ) } );
        .wait( 2000 );
        !open_door( Head );
        -ntpp( Me, _ );
        +ntpp( Me, Passage );
        !follow_path( Tail ).

// Porta ultima nel path
+!follow_path( [ Head | Tail ] )
    :   .my_name( Me ) & door_art( Head ) & not nav_goal( _ ) & Tail == []
    <-  .print( "Moving to door ", Head, " : ", Tail );
        vesna.walk( Head );
        .wait( {+movement( completed, destination_reached ) } );
        .wait( 2000 );
        !open_door( Head );
        !follow_path( Tail ).

+!follow_path( [ Head | Tail ] )
    :   .my_name( Me ) & not door_art( Head )
        & ( stair_zone( Head ) | nav_goal( _ ) )
    <-  .print( "Walking through ", Head, " → ", Tail );
        vesna.walk( Head, _ );
        .wait( { +movement( completed, destination_reached ) } );
        -ntpp( Me, _ );
        +ntpp( Me, Head );
        !follow_path( Tail ).

+!follow_path( [ Head | Tail ] )
    :   .my_name( Me ) & not door_art( Head )
        & not stair_zone( Head ) & not nav_goal( _ )
    <-  .print( "Transiting symbolically through ", Head, " → ", Tail );
        -ntpp( Me, _ );
        +ntpp( Me, Head );
        !follow_path( Tail ).

// ARTIFACT INTERACTIONS
+!use_at( ArtName, Region )
    <-  lookupArtifact( ArtName, ArtId );
        focus( ArtId );
        use( Region )[ artifact_id( ArtId ) ].

-!use_at( ArtName, Region )
    <-  .print( "I cannot use ", ArtName, " at ", Region ).

+!use( ArtName )
    :   .my_name( Me ) & ntpp( Me, MyRegion )
    <-  lookupArtifact( ArtName, ArtId );
        focus( ArtId );
        use( MyRegion )[ artifact_id( ArtId ) ].

-!use( ArtName )
    <-  .print( "I cannot use ", ArtName ).

+!free( ArtName )
    <-  lookupArtifact( ArtName, ArtId );
        stopFocus( ArtId );
        free[ artifact_id( ArtId ) ].

+!grab( ArtName )
    :   .my_name( Me ) & ntpp( Me, MyRegion )
    <-  lookupArtifact( ArtName, ArtId );
        grab( MyRegion )[ artifact_id( ArtId ) ].

-!grab( ArtName )
    <-  .print( "I cannot grab ", ArtName ).

+!release( ArtName )
    :   .my_name( Me ) & ntpp( Me, MyRegion )
    <-  lookupArtifact( ArtName, ArtId );
        release( MyRegion )[ artifact_id( ArtId ) ].

-!release( ArtName )
    <-  .print( "Cannot release ", ArtName ).

find_path( Start, Target, Path ) :- find_path_recursive( Start, Target, [ Start ], Path ).

find_path_recursive( Target, Target, Visited, Visited ).
find_path_recursive( Current, Target, Visited, Path ) :- ( po( Current, Next ) | ec( Current, Next ) ) & not .member( Next, Visited ) & find_path_recursive( Next, Target, [ Next | Visited ], Path ).

path_has_door( From, To ) :-
    find_path( From, To, Path )
    & .member( D, Path )
    & door_art( D ).

{ include("$jacamoJar/templates/common-cartago.asl") }
{ include("$jacamoJar/templates/common-moise.asl") }
