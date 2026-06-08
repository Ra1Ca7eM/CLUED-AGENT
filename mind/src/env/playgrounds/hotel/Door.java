package vesna.playgrounds.hotel;

import vesna.SituatedArtifact;

import org.json.JSONObject;

import static jason.asSyntax.ASSyntax.*;

import cartago.*;

public class Door extends SituatedArtifact {

    public void init( String region_a, String region_b, int limit ) {
        super.init( region_a, limit );
        add_region( region_b );
        DoorBridge.getInstance().register( this );
        defineObsProperty( "status", "closed" );
    }

    void onBridgeSignal( JSONObject data ) {
        log( data.toString() );
        try {
            handle_event( data );
        } catch ( Exception e ) {
            e.printStackTrace();
        }
    }

    @INTERNAL_OPERATION
    private void handle_event( JSONObject data ) throws Exception {
        String type = data.getString( "type" );
        String status = data.getString( "status" );
        if ( type.equals( "interaction" ) && status.equals( "completed" ) ) {
            beginExtSession();
            updateObsProperty( "status", createLiteral( "open" ) );
            endExtSession();
        }
    }

    @OPERATION
    public void open() throws Exception {
        updateObsProperty( "status", "opening" );

        String ag_name = getCurrentOpAgentId().getAgentName();

        JSONObject envelope = new JSONObject();
        envelope.put( "sender", get_art_name() );
        envelope.put( "receiver", "artifact" );
        envelope.put( "type", "interaction" );
        JSONObject data = new JSONObject();
        data.put( "type", "open" );
        data.put( "agent", ag_name );
        envelope.put( "data", data );

        if ( ! DoorBridge.getInstance().send( envelope.toString() ) ) {
            failed( "Door bridge not connected on port 8096 — start Godot first!" );
        }
    }

    @OPERATION
    public void close_door() {
        updateObsProperty( "status", "closed" );
    }

}
