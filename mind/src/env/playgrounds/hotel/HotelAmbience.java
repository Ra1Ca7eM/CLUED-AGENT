package vesna.playgrounds.hotel;

import cartago.Artifact;
import cartago.OPERATION;

import jason.infra.local.LocalAgArch;
import jason.infra.local.RunLocalMAS;

import org.json.JSONObject;

import vesna.VesnaAgent;

public class HotelAmbience extends Artifact {

    @OPERATION
    public void wc_flush() throws Exception {
        String ag_name = getCurrentOpAgentId().getAgentName();
        log( ag_name + " triggers WC flush effect" );

        JSONObject action = new JSONObject();
        action.put( "sender", ag_name );
        action.put( "receiver", "body" );
        action.put( "type", "interact" );
        JSONObject data = new JSONObject();
        data.put( "type", "wc_flush_pillole" );
        action.put( "data", data );

        LocalAgArch ag_arch = jason.infra.local.RunLocalMAS.getRunner().getAg( ag_name );
        VesnaAgent ag = ( VesnaAgent ) ag_arch.getTS().getAg();

        ag.perform( action.toString() );
    }

}
