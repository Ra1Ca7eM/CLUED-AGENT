package vesna.playgrounds.hotel;

import vesna.WsClient;
import vesna.WsClientMsgHandler;

import java.net.URI;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import org.json.JSONObject;

public class DoorBridge {

    private static final String BRIDGE_URI = "ws://localhost:8096";
    private static final int CONNECT_TIMEOUT_SEC = 15;

    private static DoorBridge instance;

    private final Map<String, Door> doors = new HashMap<>();
    private WsClient client;

    private DoorBridge() {
    }

    public static synchronized DoorBridge getInstance() {
        if ( instance == null ) {
            instance = new DoorBridge();
        }
        return instance;
    }

    public synchronized void register( Door door ) {
        doors.put( door.get_art_name(), door );
        ensureConnected();
    }

    public synchronized boolean send( String json ) {
        if ( !ensureConnected() ) {
            return false;
        }
        client.send( json );
        return true;
    }

    private synchronized boolean ensureConnected() {
        try {
            if ( client != null && client.isOpen() ) {
                return true;
            }
            if ( client == null ) {
                client = new WsClient( new URI( BRIDGE_URI ) );
                client.setMsgHandler( new WsClientMsgHandler() {
                    @Override
                    public void handle_msg( String msg ) {
                        dispatchMessage( msg );
                    }

                    @Override
                    public void handle_error( Exception ex ) {
                        System.err.println( "[DoorBridge] WS error: " + ex.getMessage() );
                    }
                } );
            }
            boolean connected = client.connectBlocking( CONNECT_TIMEOUT_SEC, TimeUnit.SECONDS );
            if ( connected && client.isOpen() ) {
                System.out.println( "[DoorBridge] connected to " + BRIDGE_URI );
                return true;
            }
        } catch ( Exception e ) {
            System.err.println( "[DoorBridge] connect failed: " + e.getMessage() );
        }
        return false;
    }

    private void dispatchMessage( String msg ) {
        try {
            JSONObject envelope = new JSONObject( msg );
            if ( ! envelope.getString( "type" ).equals( "signal" ) ) {
                return;
            }
            String receiver = envelope.getString( "receiver" );
            Door door = doors.get( receiver );
            if ( door == null ) {
                return;
            }
            door.onBridgeSignal( envelope.getJSONObject( "data" ) );
        } catch ( Exception e ) {
            System.err.println( "[DoorBridge] dispatch error: " + e.getMessage() );
        }
    }

}
