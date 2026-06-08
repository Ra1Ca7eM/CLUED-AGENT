package vesna;

import cartago.Artifact;
import cartago.OPERATION;
import jason.infra.local.LocalAgArch;

import java.util.List;
import java.util.ArrayList;

import org.json.JSONObject;

public class SituatedArtifact extends Artifact {

    private String art_name;
    private int limit;
    private List<String> using;
    private List<String> allowed_regions;

    public String get_art_name() {
        return this.art_name;
    }

    public void init( String region, int limit ) {
        this.limit = limit;
        using = new ArrayList<String>();
        allowed_regions = new ArrayList<String>();
        allowed_regions.add( region );
        this.art_name = getId().getName();
        log( "Artifact name: " + art_name );
        log( "Init finished!" );
    }

    protected void add_region( String region ) {
        if ( ! allowed_regions.contains( region ) ) {
            allowed_regions.add( region );
        }
    }

    protected boolean is_allowed_region( String ag_region ) {
        return allowed_regions.contains( ag_region );
    }

    @OPERATION
    public void use( String ag_region ) {

        if ( ! is_allowed_region( ag_region ) ) {
            failed( "You cannot use this artifact: it is in another region!" );
        }

        String ag_name = getCurrentOpAgentId().getAgentName();
        // Idempotenza: se QUESTO agente sta gia' usando l'artifact e' un riuso legittimo (p.es.
        // riattraversa una porta che non ha ancora liberato dopo il teleport del portale) -> ok,
        // nessun fallimento. Questo controllo DEVE precedere quello di capacita', altrimenti un
        // riuso dello stesso agente fallirebbe sul limite (sintomo: "I cannot use door_B4 at giardino").
        if ( using.contains( ag_name ) ) {
            log( "Agent " + ag_name + " is already using the artifact!" );
            return;
        }

        if ( using.size() >= limit )
            failed( "You cannot use " + art_name + " because it is already used by other agent(s)" );

        using.add( ag_name );
        log( ag_name + " can use " + this.art_name );

        JSONObject action = new JSONObject();
        action.put( "sender", ag_name );
        action.put( "receiver", "body" );
        action.put( "type", "interact" );
        JSONObject data = new JSONObject();
        data.put( "type", "use" );
        data.put( "art_name", art_name );
        action.put( "data", data );

        LocalAgArch ag_arch = jason.infra.local.RunLocalMAS.getRunner().getAg( ag_name );
        VesnaAgent ag = ( VesnaAgent ) ag_arch.getTS().getAg();

        ag.perform( action.toString() );
    }

    @OPERATION
    public void free( ) throws Exception {

        String ag_name = getCurrentOpAgentId().getAgentName();
        if ( ! using.contains( ag_name ) ) {
            log( "Agent " + ag_name + " was not using the artifact!" );
            return;
        }

        using.remove( ag_name );
        log( ag_name + " frees " + art_name );

        JSONObject action = new JSONObject();
        action.put( "sender", ag_name );
        action.put( "receiver", "body" );
        action.put( "type", "interact" );
        JSONObject data = new JSONObject();
        data.put( "type", "free" );
        data.put( "art_name", art_name );
        action.put( "data", data );

        LocalAgArch ag_arch = jason.infra.local.RunLocalMAS.getRunner().getAg( ag_name );
        VesnaAgent ag = ( VesnaAgent ) ag_arch.getTS().getAg();

        ag.perform( action.toString() );
    }

    public boolean is_using( String ag_name ) {
        return using.contains( ag_name );
    }

}
