package chatbdi;

import java.util.List;
// // import java.util.Map;
import java.util.logging.Level;
// // import java.util.logging.Logger;
// // import java.util.HashMap;
// // import java.util.Set;
// // import java.util.HashSet;
// // import java.util.ArrayList;
import java.util.Collection;
import java.util.Queue;
import java.util.UUID;

import jason.asSyntax.*;
// // import jason.asSemantics.*;
import jason.architecture.AgArch;
import static jason.asSyntax.ASSyntax.*;
import jason.asSemantics.Agent;
import jason.asSemantics.Message;
import jason.infra.local.RunLocalMAS;
// // import jason.runtime.RuntimeServices;
import jason.runtime.Settings;
import jason.bb.BeliefBase;
import jason.pl.PlanLibrary;

import jason.asSyntax.parser.ParseException;
import java.net.ConnectException;
import java.io.IOException;
import java.rmi.RemoteException;

/**
 * Interpreter is an Agent Architecture that enables the user to interact with the agents in the mas
 * @author Andrea Gatti
 */
public class Interpreter extends AgArch {

    /** Supported Illocutionary forces for the classifier */
    private final String[] SUPPORTED_ILF = { "tell", "askOne", "askAll" };

    /** Ollama manages the connection with the daemon */
    private Ollama ollama;
    /** ChatUI manages the GUI */
    private ChatUI chatUI;
    /** EmbeddingSpace manages the embedding space */
    private EmbeddingSpace embSpace;
    /** GodotBridge exposes the pipeline over HTTP for the Godot game (additive; Swing stays) */
    private GodotBridge godotBridge;

    /** Game Master agent name (final accusation channel, separate from NPC dialogue). */
    private static final String GAMEMASTER = "gamemaster";
    /** Routing decoy for solution/3 — must match gamemaster.asl belief-esca. */
    private static final Literal GM_SOLUTION_NEAREST = createLiteral(
            "solution", createAtom( "suspect" ), createAtom( "poison" ), createAtom( "motive" ) );

    /**
     * Initializes all what is needed for the interpreter:
     * <ul>
     * <li> the Ollama client </li>
     * <li> the embedding space </li>
     * <li> the chat UI </li>
     * </ul>
     */
    @Override
    public void init() throws Exception {
        super.init();
        logFine( "init: supported ilfs: " + SUPPORTED_ILF );
        try {
            Settings stts = getTS().getSettings();
            ollama = new Ollama( SUPPORTED_ILF, getAgName(), stts );
            logInfo( "Initializing Ollama models" );
            embSpace = new EmbeddingSpace( ollama );
            initEmbeddingSpace();
            logInfo( "Initializing the Embedding Space" );
            chatUI = new ChatUI( getTS().getLogger(), getAgName() );
            // Start the Godot HTTP bridge alongside the Swing UI (additive: Swing keeps working).
            // A failure here must not prevent the chat from working.
            try {
                int bridgePort = 8090;
                String portParam = stts.getUserParameter( "bridge_port" );
                if ( portParam != null )
                    bridgePort = Integer.parseInt( portParam );
                godotBridge = new GodotBridge( this, getTS().getLogger(), bridgePort );
                godotBridge.start();
            } catch ( Exception be ) {
                logSevere( "Cannot start GodotBridge: " + be.getMessage() );
            }
        } catch ( ConnectException ce ) {
            logSevere( ce.getMessage() );
            logFine( ce.getStackTrace().toString() );
        } catch ( RemoteException re ) {
            logSevere( "REMOTE EXCEPTION! " + re.getMessage() );
            logFine( re.getStackTrace().toString() );
        }
    }

    /**
     * Interpreter overwrites the checkMail method: 
     * every message received by the agent triggers a translation to Natural Language and displays it on the chat.
     */
    @Override
    public void checkMail() {
        super.checkMail();

        Queue<Message> mbox = getTS().getC().getMailBox();

        if ( mbox.isEmpty() )
            return;
        
        while( !mbox.isEmpty() ) {
            Message m = mbox.poll();
            new Thread( () -> {
                String sender = m.getSender();
                UUID id = chatUI.genUUID();
                chatUI.showMsg( id, sender );
                String msg = kqml2nl( m );
                chatUI.setMsg( id ,msg );
                // Also hand the translated reply (and any machine-readable verdict) to the
                // Godot bridge (if one is waiting for it).
                if ( godotBridge != null )
                    godotBridge.onAgentReply( sender, msg, extractVerdict( m ) );
            }).start();
        }
    }

    /**
     * Extracts a machine-readable verdict from a raw reply term of the form
     * result(gamemaster, V) (V = solved | not_yet). Returns null for any other message,
     * so the Godot front-end can decide when to reveal the full story.
     * @param m the incoming KQML message
     * @return "solved" / "not_yet", or null if the message carries no verdict
     */
    private String extractVerdict( Message m ) {
        try {
            Object content = m.getPropCont();
            if ( content instanceof Literal ) {
                Literal lit = (Literal) content;
                if ( "result".equals( lit.getFunctor() ) && lit.getArity() == 2
                        && "gamemaster".equals( lit.getTerm( 0 ).toString() ) )
                    return lit.getTerm( 1 ).toString();
            }
        } catch ( Exception e ) {
            logFine( "extractVerdict failed: " + e.getMessage() );
        }
        return null;
    }

    /**
     * Translates and send a user message to the agents
     * @param receivers the list of receiver agents
     * @param msg the message written on the chat
     * @throws Exception if broadcast or sendMsg raise it
     */
    protected int handleUserMsg( UUID id, List<String> receivers, String msg ) throws Exception, ParseException {
        Collection<String> agNames = getRuntimeServices().getAgentsNames();
        logInfo("Starting");

        // NB (integrazione mind/): NON ricloniamo BB/PL degli agenti ad ogni messaggio.
        // Gli agenti VEsNA pattugliano e modificano di continuo le loro belief: clonarle qui
        // (da un altro thread) provocava corse concorrenti e il freeze di tutti gli agenti.
        // L'indicizzazione fatta una volta in initEmbeddingSpace() basta per il routing; il
        // valore VIVO (es. posizione corrente) lo risolve l'agente interrogando la sua BB.
        // updateEmbeddingSpace();

        boolean partial = false;
        if ( !receivers.isEmpty() ) {
            logInfo("There are receivers" );
            for ( int i=0; i<receivers.size(); i++ ) {
                if ( !agNames.contains( receivers.get(i) ) ) {
                    logInfo("The agent " + receivers.get(i) + " does not exist" );
                    partial = true;
                    chatUI.showAgentNotFoundNotice( id, receivers.get(i) );
                    receivers.remove( receivers.get(i) );
                }
            }
            if ( receivers.isEmpty() ) {
                logInfo("Receivers is now empty!");
                return -1;
            }
        }
        // Translates the message into a KQML Message
        logInfo("Translating the message");
        Message m = nl2kqml( receivers, msg );

        if ( m == null ) {
            logInfo( "The generated message is null");
            return -1;
        }
        // show the generated KQML translation under the user's message
        try {
            if ( chatUI != null )
                chatUI.setKQML( id, m.getIlForce(), m.getPropCont().toString() );
        } catch ( Exception e ) {
            logSevere( "Cannot show KQML translation: " + e.getMessage() );
        }
        // Broadcast if no receivers are set
        if ( receivers.isEmpty() ) {
            logInfo("Broadcasting the message");
            broadcast( m );
            return 1;
        }
        // Send it to all receivers
        for ( String receiver : receivers ) {
            if ( agNames.contains( receiver ) ) {
                m.setReceiver( receiver );
                sendMsg( m );
            }
        }
        if ( partial )
            return 0;
        return 1;
    }

    /**
     * Entry point used by the GodotBridge: shows the incoming game message in the Swing chat
     * (so the window stays a useful debug view) and routes it to the given receivers, reusing
     * the same translation/sending pipeline as the Swing UI.
     * @param receivers the target agents (e.g. ["alberto"]) — this is the automatic "@receiver"
     * @param text the player's message
     * @throws Exception if the underlying handleUserMsg fails
     */
    void sendFromBridge( List<String> receivers, String text ) throws Exception {
        if ( isGamemasterOnly( receivers ) )
            ensureAgentIndexed( GAMEMASTER );
        // Prepend the "@receiver" mention(s) so the Swing chat shows the message exactly as if
        // it had been typed by hand. nl2kqml strips the "@..." before translation, so the reply
        // is unaffected; routing still uses the explicit receivers list.
        StringBuilder mentioned = new StringBuilder();
        for ( String r : receivers )
            mentioned.append( "@" ).append( r ).append( " " );
        String displayText = mentioned + text;

        UUID id = ( chatUI != null ) ? chatUI.showUserMsg( displayText ) : UUID.randomUUID();
        handleUserMsg( id, receivers, displayText );
    }

    /**
     * Translates a user message into a KQML Message object
     * @param receivers the list of receiver agents
     * @param msg the message written on the chat
     * @return the KQML Message
     * @throws ParseException if the resulting translation is not syntactically correct
     * @throws Exception if it fails sending or broadcasting the message
     */
    protected Message nl2kqml( List<String> receivers, String msg ) throws Exception, ParseException {
        // If the message is empty return
        if ( msg.trim().isEmpty() )
            return null;
        // Classify the message
        Literal ilf = ollama.classify( msg );
        // Generate the final term
        Literal term = generateTerm( receivers, ilf, msg );
        // If the computed ilf is an askHow add the triggering +! part to the term
        if ( ilf.equalsAsStructure( createLiteral( "askHow" ) ) )
            term = new Trigger( Trigger.TEOperator.add, Trigger.TEType.achieve, term );
        logInfo( "Generated: \n ilf: " + ilf + "\n term: " + term );

        return new Message( ilf.toString(), this.getAgName(), null, term );
    }

    /**
     * This method translates KQML into Natural Language
     * @param m the KQML Message
     * @return the translation
     */
    protected String kqml2nl( Message m ) {
        try {
            return ollama.generate( m );
        } catch ( IOException ioe ) {
            logSevere( ioe.getMessage() );
        }
        return "Error showing the message";
    }

    /**
     * Generates the final term to send 
     * @param receivers who will receive the message: we will use their BB and PL for translation
     * @param ilf the Illocutionary Force classified
     * @param msg the message sent by the user
     * @return the term generated from the message
     * @throws ParseException if the generated term is not syntactically correct
     */
    private Literal generateTerm( List<String> receivers, Literal ilf, String msg ) throws ParseException {
        msg = msg.replaceAll( "\\s*@\\S+", "" );
        try {
            // Game Master: never run nearest-neighbour over NPC functors (evelina/keys/...).
            // Always extract into solution/3 using the GM decoy and nl2log solution rules.
            if ( isGamemasterOnly( receivers ) ) {
                ensureAgentIndexed( GAMEMASTER );
                System.out.println( "[LOG] gamemaster routing -> " + GM_SOLUTION_NEAREST );
                List<Literal> examples = embSpace.getExamples( ilf, GM_SOLUTION_NEAREST );
                return ollama.generate( msg, GM_SOLUTION_NEAREST, ilf, examples );
            }
            String subSpace = "terms";
            if ( ilf.equals( "achieve" ) )
                subSpace = "plans";
            Literal nearest = embSpace.findNearest( receivers, subSpace, msg );
            System.out.println( "[LOG] " + nearest );
            List<Literal> examples = embSpace.getExamples( ilf, nearest );
            return ollama.generate( msg, nearest, ilf, examples );
        } catch( IOException ioe ) {
            throw new IllegalArgumentException( "Prompt loading caused a IO Exception: check the file path. Full error: " + ioe.getMessage() );
        }
    }

    private boolean isGamemasterOnly( List<String> receivers ) {
        return receivers.size() == 1 && GAMEMASTER.equals( receivers.get( 0 ) );
    }

    /** Index an agent into the embedding space if initEmbeddingSpace missed it (e.g. late start). */
    private void ensureAgentIndexed( String agName ) {
        if ( embSpace.isAgentIndexed( agName ) )
            return;
        try {
            Agent ag = RunLocalMAS.getRunner().getAg( agName ).getTS().getAg();
            BeliefBase bb = ag.getBB().clone();
            PlanLibrary pl = ag.getPL().clone();
            embSpace.update( agName, bb, pl );
            logInfo( "Late-indexed agent " + agName + " for embedding routing" );
        } catch ( Exception e ) {
            logSevere( "Cannot index agent " + agName + ": " + e.getMessage() );
        }
    }

    /**
     * Inititalizes the embedding space
     * @throws RemoteException if the agent fails accessing BB or PL of another agent
     */
    private void initEmbeddingSpace() throws RemoteException {
        logInfo( "Initializing content of the Embedding Space" );
        Collection<String> agNames = getRuntimeServices().getAgentsNames();
        for ( String agName : agNames ) {
            logInfo( "Considering " + agName );
            try {
                Agent ag = RunLocalMAS.getRunner().getAg( agName ).getTS().getAg();
                BeliefBase bb = ag.getBB().clone();
                PlanLibrary pl = ag.getPL().clone();
                embSpace.update( agName, bb, pl );
            } catch ( Exception e ) {
                // Un agente occupato (pattuglia) puo' far fallire la clonazione: non e' fatale.
                logSevere( "Cannot index agent " + agName + ": " + e.getMessage() );
            }
        }
        embSpace.print();
        // gamemaster may start after player; index it now if init missed it.
        ensureAgentIndexed( GAMEMASTER );
    }

    private void updateEmbeddingSpace() throws RemoteException {
        logInfo( "Updating content of the Embedding Space" );
        Collection<String> agNames = getRuntimeServices().getAgentsNames();
        for ( String agName : agNames ) {
            logInfo( "Considering " + agName );
            Agent ag = RunLocalMAS.getRunner().getAg( agName ).getTS().getAg();
            BeliefBase bb = ag.getBB().clone();
            PlanLibrary pl = ag.getPL().clone();
            embSpace.update( agName, bb, pl );
        }
    }


    /** Prints ERROR on the agent log
     * @param msg what to print
     */
    protected void logSevere( String msg ) {
        getTS().getLogger().log( Level.SEVERE, msg );
    }

    protected void logWarning( String msg ) {
        getTS().getLogger().log( Level.WARNING, msg );
    }

    /** Prints INFO on the agent log 
     * @param msg what to print
    */
    protected void logInfo( String msg ) {
        getTS().getLogger().log( Level.INFO, msg );
    }

    protected void logConfig( String msg ) {
        getTS().getLogger().log( Level.CONFIG, msg );
    }

    protected void logFine( String msg ) {
        getTS().getLogger().log( Level.FINE, msg );
    }

    protected void logFiner( String msg ) {
        getTS().getLogger().log( Level.FINER, msg );
    }

    protected void logFinest( String msg ) {
        getTS().getLogger().log( Level.FINEST, msg );
    }

}