package chatbdi;

import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;

import org.json.JSONObject;

/**
 * GodotBridge exposes the ChatBDI pipeline over a small local HTTP server so the
 * Godot game chat can act as a front-end for the MAS (in addition to the Swing UI,
 * which keeps working). It is intentionally single-flight: one dialogue request at a
 * time, which is enough for a 1:1 chat with an NPC.
 *
 * Endpoints:
 *   POST /dialogue  body { "role_key": "alberto", "player_text": "..." }
 *                   -> { "ok": true, "reply_nl": "..." } | { "ok": false, "error": "..." }
 *   GET  /health    -> { "ok": true }
 *
 * @author integration bridge for the Hotel Valtieri prototype
 */
public class GodotBridge {

    private final Interpreter interpreter;
    private final Logger logger;
    private final int port;
    private HttpServer server;

    /** How long the HTTP handler waits for the agent reply before giving up.
     *  Kept high on purpose: on a slow machine the 3 LLM passes (classify + nl2log +
     *  log2nl) can take several minutes. */
    private static final int REPLY_TIMEOUT_SECONDS = 600;

    /** Single-slot mailbox: the reply translated to NL by checkMail is handed over here. */
    private final BlockingQueue<String> replyQueue = new ArrayBlockingQueue<>(1);
    /** Name of the agent we are currently waiting a reply from (null = not waiting). */
    private volatile String awaitingFrom = null;
    /** Optional machine-readable verdict (e.g. "solved"/"not_yet" from the Game Master),
     *  extracted from the raw reply term. null when the reply carries no verdict.
     *  Safe as a single field because the bridge is single-flight. */
    private volatile String lastVerdict = null;

    public GodotBridge( Interpreter interpreter, Logger logger, int port ) {
        this.interpreter = interpreter;
        this.logger = logger;
        this.port = port;
    }

    public void start() throws IOException {
        server = HttpServer.create( new InetSocketAddress( "127.0.0.1", port ), 0 );
        server.createContext( "/dialogue", new DialogueHandler() );
        server.createContext( "/health", new HealthHandler() );
        server.setExecutor( null ); // default executor
        server.start();
        logger.log( Level.INFO, "GodotBridge listening on http://127.0.0.1:" + port + " (/dialogue, /health)" );
    }

    public void stop() {
        if ( server != null )
            server.stop( 0 );
    }

    /**
     * Called by Interpreter.checkMail for every incoming agent message (already translated
     * to natural language). If a dialogue request is waiting for this sender, complete it.
     * @param verdict optional machine-readable verdict extracted from the raw term (may be null)
     */
    public void onAgentReply( String sender, String text, String verdict ) {
        String waiting = awaitingFrom;
        if ( waiting != null && waiting.equals( sender ) ) {
            lastVerdict = verdict;       // set before handing over the reply (single-flight)
            replyQueue.offer( text );    // capacity 1, non-blocking
        }
    }

    private class DialogueHandler implements HttpHandler {
        @Override
        public void handle( HttpExchange ex ) throws IOException {
            if ( !"POST".equalsIgnoreCase( ex.getRequestMethod() ) ) {
                respond( ex, 405, new JSONObject().put( "ok", false ).put( "error", "POST only" ) );
                return;
            }
            try {
                String body = new String( ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8 );
                JSONObject req = new JSONObject( body );
                String roleKey = req.optString( "role_key", "" ).trim();
                String playerText = req.optString( "player_text", "" ).trim();

                if ( roleKey.isEmpty() || playerText.isEmpty() ) {
                    respond( ex, 400, new JSONObject().put( "ok", false ).put( "error", "missing role_key/player_text" ) );
                    return;
                }

                // Single-flight: arm the mailbox for a reply coming from roleKey
                replyQueue.clear();
                lastVerdict = null;
                awaitingFrom = roleKey;

                // Route the message to the agent == automatic "@roleKey"
                List<String> receivers = new ArrayList<>();
                receivers.add( roleKey );
                interpreter.sendFromBridge( receivers, playerText );

                // Wait for the agent's reply (delivered via onAgentReply from checkMail)
                String reply = replyQueue.poll( REPLY_TIMEOUT_SECONDS, TimeUnit.SECONDS );
                String verdict = lastVerdict;
                awaitingFrom = null;

                if ( reply == null ) {
                    respond( ex, 200, new JSONObject().put( "ok", false ).put( "error", "timeout" ) );
                } else {
                    JSONObject out = new JSONObject().put( "ok", true ).put( "reply_nl", reply );
                    if ( verdict != null )
                        out.put( "verdict", verdict );
                    respond( ex, 200, out );
                }

            } catch ( Exception e ) {
                awaitingFrom = null;
                logger.log( Level.SEVERE, "GodotBridge /dialogue error: " + e.getMessage() );
                respond( ex, 500, new JSONObject().put( "ok", false ).put( "error", String.valueOf( e.getMessage() ) ) );
            }
        }
    }

    private class HealthHandler implements HttpHandler {
        @Override
        public void handle( HttpExchange ex ) throws IOException {
            respond( ex, 200, new JSONObject().put( "ok", true ) );
        }
    }

    private void respond( HttpExchange ex, int status, JSONObject body ) throws IOException {
        byte[] bytes = body.toString().getBytes( StandardCharsets.UTF_8 );
        ex.getResponseHeaders().add( "Content-Type", "application/json; charset=utf-8" );
        ex.sendResponseHeaders( status, bytes.length );
        try ( OutputStream os = ex.getResponseBody() ) {
            os.write( bytes );
        }
    }
}
