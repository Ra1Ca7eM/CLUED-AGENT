+!open_door( Door )

    :   .my_name( Me ) & ntpp( Me, MyRegion ) & po( MyRegion, Door )

    <-  .print( "Opening door ", Door, " from ", MyRegion );

        !use_at( Door, MyRegion );

        open;

        .wait( { +status( open ) } );

        !free( Door );

        .print( "Door ", Door, " is open." ).



+!open_door( Door )

    :   .my_name( Me ) & ntpp( Me, MyRegion ) & po( Door, MyRegion )

    <-  .print( "Opening door ", Door, " from ", MyRegion );

        !use_at( Door, MyRegion );

        open;

        .wait( { +status( open ) } );

        !free( Door );

        .print( "Door ", Door, " is open." ).



+!open_door( Door )

    :   .my_name( Me ) & ntpp( Me, MyRegion )

        & po( Adj, Door ) & ( ec( MyRegion, Adj ) | po( MyRegion, Adj ) )

    <-  .print( "Opening door ", Door, " via adjacent ", Adj );

        !use_at( Door, Adj );

        open;

        .wait( { +status( open ) } );

        !free( Door );

        .print( "Door ", Door, " is open." ).



-!open_door( Door )

    <-  .print( "Cannot open door ", Door ).

