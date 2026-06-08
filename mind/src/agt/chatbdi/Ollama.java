package chatbdi;

import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.ConnectException;
import java.net.URI;
import java.io.IOException;
import java.util.List;
import java.util.ArrayList;
import java.util.Set;
import java.util.HashSet;
import java.util.Map;

import java.nio.file.Files;
import java.nio.file.Path;

import org.json.JSONObject;
import org.json.JSONArray;

import jason.asSyntax.*;
import jason.asSemantics.Message;
import static jason.asSyntax.ASSyntax.*;

import jason.asSyntax.parser.ParseException;
import jason.infra.local.RunLocalMAS;
import jason.runtime.Settings;
import jason.NoValueException;

import static chatbdi.Tools.*;

/**
 * The Ollama class provides an API to call the Ollama models
 * @author Andrea Gatti
 */
public class Ollama {
	/** The url at which the Ollama server listens */
    private String URL = "http://localhost:11434/api/";
	/** The embedding model to use */
    protected String EMB_MODEL;
	/** The generation model to use */
    protected String GEN_MODEL;
	/** The name that will be assigned to the model that translates KQML to NL */
    private final String LOG2NL_MODEL = "logic-to-nl";
	/** The name that will be assigned to the model that translates NL to KQML */
    private final String NL2LOG_MODEL = "nl-to-logic";
	/** The name that will be assigned to the model that classifies the Illocutionary Force */
    private final String CLASS_MODEL = "classify-ilf";

	/** The temperature for the generation models */
    private float TEMPERATURE = 0.0f;
	/** The seed for the generation models (to be reproducible) */
    private int SEED = 42;

	/** The Agent name (for log printing) */
	private String agName;

    private String NL2LOG_PROMPT;
    private String LOG2NL_PROMPT;
    private String NL2LOG_MODELFILE;
    private String LOG2NL_MODELFILE;
    private String CLASS_MODELFILE ;

	// ===== CONFIG OLLAMA CLOUD — modifica QUI, non servono variabili d'ambiente =====
	// Interruttore robusto e indipendente dalla shell (le env var venivano ignorate dal daemon
	// di Gradle). Per tornare locale: USE_OLLAMA_CLOUD = false e ricompilare. Nulla viene rimosso.
	// PREREQUISITO: 'ollama signin' una volta sola (i modelli cloud passano dall'Ollama locale).
	/** true = usa Ollama Cloud per la GENERAZIONE; false = tutto locale come prima. */
	private static final boolean USE_OLLAMA_CLOUD = true;
	/** Nome ESATTO del modello cloud (quello che funziona con `ollama run <nome>` dopo il signin). */
	private static final String  CLOUD_GEN_MODEL  = "gpt-oss:120b-cloud";
	/** API key diretta (opzionale): "" => uso 'ollama signin' (consigliato, nessuna chiave nel repo). */
	private static final String  CLOUD_API_KEY    = "";

	// ===== Stato runtime della modalita' di generazione (derivato da CONFIG + env override) =====
	/** Endpoint per la GENERAZIONE (default = URL locale; in cloud diventa l'endpoint remoto). */
	private String GEN_URL;
	/** API key per Ollama Cloud (header Authorization: Bearer). null = nessun header (default/locale). */
	private String API_KEY = null;
	/** true = salta /api/create e passa il system prompt inline ad ogni chiamata (modalita' cloud). */
	private boolean inlineSystem = false;
	/** Contenuti dei modelfile, letti una volta sola in modalita' inline (system prompt da iniettare). */
	private String CLASS_SYS, NL2LOG_SYS, LOG2NL_SYS;

	/**
	 * List of the supported Illocutionary Forces
	 */
	private final String[] SUPPORTED_ILF;
	/**
	 * The HTTP client for the requests
	 */
	private final HttpClient client = HttpClient.newHttpClient();

	/**
	 * Creates a new Ollama object
	 * @param supportedIlfs the list of supported Illocuctionary Forces
	 * @throws ConnectException if the ollama server is not available
	 */
	public Ollama( String[] supportedIlfs, String agName, Settings stts ) throws ConnectException {

		this.agName = agName;
		// Integrated build (mind/): config may not come from .mas2j agent options, so each
		// parameter falls back to a sensible default if the user-parameter is absent.
		// Paths are relative to the mind/ run dir (src/agt/chatbdi/modelfiles/...).
		NL2LOG_PROMPT = paramOrDefault( stts, "nl2log_prompt", "src/agt/chatbdi/modelfiles/nl2logPrompt.txt" );
		LOG2NL_PROMPT = paramOrDefault( stts, "log2nl_prompt", "src/agt/chatbdi/modelfiles/log2nlPrompt.txt" );
		NL2LOG_MODELFILE = paramOrDefault( stts, "nl2log_model", "src/agt/chatbdi/modelfiles/nl2log.txt" );
		LOG2NL_MODELFILE = paramOrDefault( stts, "log2nl_model", "src/agt/chatbdi/modelfiles/log2nl.txt" );
		CLASS_MODELFILE = paramOrDefault( stts, "class_model", "src/agt/chatbdi/modelfiles/classifier.txt" );
		GEN_MODEL = paramOrDefault( stts, "gen_model", "qwen2.5:3b-instruct" );
		EMB_MODEL = paramOrDefault( stts, "emb_model", "nomic-embed-text" );
		String sttsTemperature = stts.getUserParameter( "temperature" );
		if ( sttsTemperature != null )
			TEMPERATURE = Float.parseFloat(sttsTemperature);
		String sttsSeed = stts.getUserParameter( "seed" );
		if ( sttsSeed != null )
			SEED = Integer.parseInt(sttsSeed);
		String sttsUrl = stts.getUserParameter( "ollama_url" );
		if ( sttsUrl != null )
			URL = sttsUrl;

		// ===== Ollama Cloud: attivato dal CONFIG in cima (USE_OLLAMA_CLOUD); env come override =====
		// Default locale: GEN_URL = URL, nessuna chiave, create() attivo => IDENTICO a prima.
		// Gli embedding restano SEMPRE locali (usano URL).
		GEN_URL = URL;
		inlineSystem = USE_OLLAMA_CLOUD || "1".equals( System.getenv( "OLLAMA_CLOUD" ) );
		if ( inlineSystem ) {
			// Modello: env OLLAMA_GEN_MODEL ha precedenza, altrimenti il CLOUD_GEN_MODEL del CONFIG.
			String envGenModel = System.getenv( "OLLAMA_GEN_MODEL" );
			GEN_MODEL = ( envGenModel != null ) ? envGenModel : CLOUD_GEN_MODEL;
			// API key: env OLLAMA_API_KEY, altrimenti CLOUD_API_KEY; vuota/assente => proxy 'ollama signin'.
			String envKey = System.getenv( "OLLAMA_API_KEY" );
			if ( envKey != null && !envKey.isEmpty() )
				API_KEY = envKey;
			else if ( !CLOUD_API_KEY.isEmpty() )
				API_KEY = CLOUD_API_KEY;
			if ( API_KEY != null )
				GEN_URL = "https://ollama.com/api/";   // accesso DIRETTO con API key
			// altrimenti GEN_URL resta locale (URL): la generazione passa dall'Ollama locale (signin proxy)
			String envGenUrl = System.getenv( "OLLAMA_GEN_URL" );
			if ( envGenUrl != null )
				GEN_URL = envGenUrl;                   // override manuale dell'endpoint di generazione
		}

		// Store the supported Illocutionary Forces
		SUPPORTED_ILF = new String[ supportedIlfs.length ];
		for ( int i = 0; i < supportedIlfs.length; i++ )
			SUPPORTED_ILF[i] = supportedIlfs[i];

		// Check if the Ollama server is online at the given address (serve sempre per gli embedding)
		if ( !is_online() ) {
			throw new ConnectException( "The Ollama Server is offline or the address is not correct." );
		}

		if ( inlineSystem ) {
			// MODALITA' CLOUD: /api/create non e' disponibile sul cloud, quindi NON creiamo i modelli
			// derivati; leggiamo i modelfile una volta e li iniettiamo come system prompt ad ogni
			// chiamata (vedi generateRaw). Stessi file, stesso risultato, solo calcolato altrove.
			try {
				CLASS_SYS  = Files.readString( Path.of( CLASS_MODELFILE ) );
				NL2LOG_SYS = Files.readString( Path.of( NL2LOG_MODELFILE ) );
				LOG2NL_SYS = Files.readString( Path.of( LOG2NL_MODELFILE ) );
			} catch ( IOException e ) {
				e.printStackTrace();
			}
			System.out.println( "[ChatBDI] GENERAZIONE = OLLAMA CLOUD -> model='" + GEN_MODEL
				+ "' url='" + GEN_URL + "' auth=" + ( API_KEY != null )
				+ "  (embedding LOCALE: '" + EMB_MODEL + "')" );
		} else {
			// MODALITA' LOCALE (default, invariata): cuoce i modelfile nei modelli derivati.
			System.out.println( "[ChatBDI] GENERAZIONE = LOCALE -> model='" + GEN_MODEL
				+ "'  (embedding LOCALE: '" + EMB_MODEL + "')" );
			System.out.println( "Initializing generation models" );
			create( GEN_MODEL, NL2LOG_MODEL, TEMPERATURE, NL2LOG_MODELFILE, SEED );
			create( GEN_MODEL, LOG2NL_MODEL, TEMPERATURE, LOG2NL_MODELFILE, SEED );
			create( GEN_MODEL, CLASS_MODEL, TEMPERATURE, CLASS_MODELFILE, SEED );
		}
	}

	/** Returns the user-parameter for key, or def if it is not set. */
	private static String paramOrDefault( Settings stts, String key, String def ) {
		String v = stts.getUserParameter( key );
		return ( v != null ) ? v : def;
	}

	/**
	 * Checks if Ollama is online
	 * @return true if available and ready (status code: 200), false otherwise
	 * Can handle:
	 * <ul>
	 * <li> ConnectExcept if the server is not reachable </li>
	 * <li> IOException if the message cannot be send </li>
	 * <li> InterruptedException if the connection is interrupted </li>
	 * </ul>
	 */
	private boolean is_online() {
		try {
		HttpRequest req = HttpRequest.newBuilder()
			.uri( URI.create( URL.replaceAll( "/api/", "" ) ) )
			.header( "Content-Type", "application/json" )
			.GET()
			.build();

			HttpResponse<String> res = client.send( req, HttpResponse.BodyHandlers.ofString() );
			return res.statusCode() == 200;
		} catch( ConnectException e ) {
			return false;
		} catch( IOException e ) {
			Interpreter ag = (Interpreter) RunLocalMAS.getRunner().getAg( agName ).getTS().getAgArch();
			ag.logSevere(e.getMessage());
		} catch( InterruptedException e ) {
			Interpreter ag = (Interpreter) RunLocalMAS.getRunner().getAg( agName ).getTS().getAgArch();
			ag.logSevere(e.getMessage());
		}
		return false;
	}

	/**
	 * Generates the embedding of a string
	 * @param str the string to embed
	 * @return a list of double (the embedding vector). The size depends on the model used.
	 */
	public List<Double> embed( String str ) {
		// Build the JSON object
		JSONObject json = new JSONObject();
		json.put( "model", EMB_MODEL );
		json.put( "input", str );
		json.put( "stream", false );

		// Build the request
		HttpRequest req = HttpRequest.newBuilder()
			.uri( URI.create( URL + "embed" ) )
			.header( "Content-Type", "application/json" )
			.POST( HttpRequest.BodyPublishers.ofString( json.toString() ) )
			.build();

		try {
			// Send the message
			HttpResponse<String> res = client.send( req, HttpResponse.BodyHandlers.ofString() );
			// Load the content inside a JSONObject
			JSONObject emb_json = new JSONObject( res.body() );
			// Get the embedding array
			JSONArray vec = emb_json.getJSONArray( "embeddings" ).getJSONArray(0);
			// Copy the JSONArray into a Java List
			List<Double> list = new ArrayList<>();
			for( int i = 0; i < vec.length(); i++ ) {
				list.add( vec.getDouble( i ) );
			}
			return list;
		} catch ( IOException e ) {
			e.printStackTrace();
		} catch ( InterruptedException e ) {
			e.printStackTrace();
		}
		return null;
	}

	/**
	 * Computes the embedding of a Literal term.
	 * nomic-embed-text is trained with task prefixes: domain terms (the "documents" we index)
	 * are prefixed with "search_document: " so the asymmetric retrieval matches the query side
	 * (see embedQuery). Removing the prefix reverts to the previous behaviour.
	 * @param term the Literal to embed
	 * @return a list of double (the embedding vector). The size depends on the model used.
	 */
	public List<Double> embed( Literal term ) {
		return embed( "search_document: " + preprocess( term ) );
	}

	/**
	 * Embeds a user query (the natural-language sentence to route). Uses nomic-embed-text's
	 * "search_query: " prefix, the counterpart of the "search_document: " prefix used when
	 * indexing the domain terms. This asymmetric prefixing improves nearest-term retrieval.
	 * @param str the user message
	 * @return the embedding vector
	 */
	public List<Double> embedQuery( String str ) {
		return embed( "search_query: " + str );
	}

	/**
	 * This function calls the GENERATE API for the model with input str
	 * @param model the model to use
	 * @param str the input message
	 * @return the body of the answer
	 */
	private String generate( String model, String str ) {
		return generateRaw( model, str, null, null );
	}

	/**
	 * Unified GENERATE call (used by all paths).
	 * LOCALE (default): si comporta esattamente come prima — POST {model, prompt, [format]}
	 * al server locale, senza system, senza options, senza auth.
	 * CLOUD (inlineSystem=true): punta a GEN_URL, inietta il system prompt inline e le options
	 * temperature/seed (perche' i modelli derivati via /api/create sono saltati sul cloud), e
	 * aggiunge l'header Authorization quando e' configurata una API key.
	 * @param model the model to use
	 * @param prompt the input message
	 * @param format optional JSON schema for the output (null = none)
	 * @param system optional system prompt to inject inline (null = none; usato solo in cloud)
	 * @return the body of the answer
	 */
	private String generateRaw( String model, String prompt, JSONObject format, String system ) {
		JSONObject json = new JSONObject();
		json.put( "model", model );
		json.put( "prompt", prompt );
		json.put( "stream", false );
		if ( format != null )
			json.put( "format", format );
		if ( system != null )
			json.put( "system", system );
		if ( inlineSystem ) {
			// I modelli derivati cuocevano temperature/seed via /api/create; in inline li passiamo qui.
			JSONObject options = new JSONObject();
			options.put( "temperature", TEMPERATURE );
			options.put( "seed", SEED );
			json.put( "options", options );
		}

		HttpRequest.Builder builder = HttpRequest.newBuilder()
			.uri( URI.create( GEN_URL + "generate" ) )
			.header( "Content-Type", "application/json" )
			.POST( HttpRequest.BodyPublishers.ofString( json.toString() ) );
		if ( API_KEY != null )
			builder.header( "Authorization", "Bearer " + API_KEY );
		HttpRequest req = builder.build();

		try {
			HttpResponse<String> res = client.send( req, HttpResponse.BodyHandlers.ofString() );
			return res.body();
		} catch( IOException e ) {
			e.printStackTrace();
		} catch ( InterruptedException e ) {
			e.printStackTrace();
		}
		return null;
	}

	/**
	 * This function classifies a message Illocutionary Force
	 * @param msg the input message
	 * @return the Literal correspondent to the Illocutionary Force
	 */
	public Literal classify( String msg ) {
		// Build a JSON Schema with the available Illocutionary Forces
        JSONObject ilf = new JSONObject();
        ilf.put( "type", "string" );
        ilf.put( "enum", SUPPORTED_ILF );
        JSONObject properties = new JSONObject();
        properties.put( "Illocutionary Force", ilf );
        JSONObject json = new JSONObject();
        json.put( "type", "object" );
        json.put( "properties", properties );
        json.put( "required", new JSONArray().put( "Illocutionary Force" ) );

		// Generate the answer and load it inside a JSON Object.
		// Locale: modello derivato CLASS_MODEL (classifier.txt gia' cotto). Cloud: GEN_MODEL + system inline.
        String classModel = inlineSystem ? GEN_MODEL : CLASS_MODEL;
        String classSys   = inlineSystem ? CLASS_SYS : null;
        JSONObject ans = new JSONObject( generateRaw( classModel, msg, json, classSys ) );
		// Postprocess
        String ilfObjStr = ans.getString( "response" )
            .replaceAll( "```json\\s*", "" )
            .replaceAll( "```\\s*$", "" )
            .trim();
        JSONObject ilfObj = new JSONObject( ilfObjStr );
		// Return the literal
        return createLiteral( ilfObj.getString( "Illocutionary Force" ).trim() );
	}

	/**
	 * This function translates a user message to a Literal
	 * To get better results the terms are translated in Json, for example:
	 * p(a, b, 1) -> { "functor": p, "arg0": "a", "arg1": "b", "arg2": 1 }
	 * @param msg the input message
	 * @param nearest the nearest term in the embedding space
	 * @param ilf the classified Illocutionary Force
	 * @param examples a list of all the terms with same functor and arity of the nearest
	 * @return the nearest literal
	 * @throws IOException if fails reading the NL2LOG_PROMPT file
	 * @throws ParseException if the provided answer is not a valid Jason term
	 */
	public Literal generate( String msg, Literal nearest, Literal ilf, List<Literal> examples ) throws IOException, ParseException {

        List<JSONObject> jsonExamples = new ArrayList<>();
		List<Map<String, Term>> mapExamples = new ArrayList<>();
		System.out.println("[LOG] nearest: " + nearest );
		// Translate the term in JSON
        Map<String, Term> nearestJson = termToMap( nearest );
		System.out.println("[LOG] nearest json: " + nearestJson );
		// Translate all the examples
        for ( Literal example : examples ) {
			try {
				Map<String, Term> mapExample = termToMap( example );
				mapExamples.add( mapExample );
				jsonExamples.add( mapToJson( mapExample ) );
			} catch ( NoValueException nve ) {
				nve.printStackTrace();
			}
		}
		// Generate a schema with types provided in the examples for each arg
        JSONObject schema = genJSONSchema( mapExamples );
		System.out.println( "[LOG] Sentence: " + msg + ", nearest: " + nearestJson + ", ilf: " + ilf + ", examples: " + jsonExamples );
		// Read the prompt and replace needed placeholders
        String prompt = Files.readString( Path.of( NL2LOG_PROMPT ) )
            .replace( "SENTENCE", msg )
            .replace( "NEAREST_JSON", nearestJson.toString() )
            .replace( "ILF", ilf.toString() )
            .replace( "EXAMPLES", jsonExamples.toString() );
		// // List variable names: they may have meaningful names
        // // List<Set<Term>> varNames = getVarNames( examples );
        // // for ( int i = 0; i < varNames.size(); i++ )
        // //     if ( !varNames.get( i ).isEmpty() )
        // //         prompt += " - arg" + i + " should contain " + varNames.get( i ) +
        // //         "; if this piece of information is in the sentence place it here, otherwise place underscore or null";
        
		// Generate the new term.
		// Locale: NL2LOG_MODEL (modello derivato che cuoce nl2log.txt come system prompt) — NON il
		// GEN_MODEL grezzo, altrimenti le regole di nl2log.txt (inclusa l'estrazione "solution") non
		// arriverebbero al modello. Cloud: GEN_MODEL + nl2log.txt iniettato come system inline.
        String nlModel = inlineSystem ? GEN_MODEL : NL2LOG_MODEL;
        String nlSys   = inlineSystem ? NL2LOG_SYS : null;
        JSONObject answer = new JSONObject( generateRaw( nlModel, prompt, schema, nlSys ) );
        JSONObject response = new JSONObject( answer.getString( "response" ) );
		try {
			Literal responseTerm = jsonToTerm( response );
			return responseTerm;
		} catch ( ParseException pe ) {
			throw new ParseException( "LLM error! Generated: " + response + ". It is not a valid Jason term." );
		}
	}

	/**
	 * This function translates a Jason message in Natural Language
	 * @param msg the KQML message
	 * @return the natural language translation
	 * @throws IOException if fails to open LOG2NL_PROMPT
	 */
	public String generate( Message msg ) throws IOException {
		String prompt = Files.readString( Path.of( LOG2NL_PROMPT ) )
			.replace( "SENDER", msg.getSender() )
			.replace( "ILFORCE", msg.getIlForce() )
			.replace( "CONTENT", msg.getPropCont().toString() );
		// Locale: modello derivato LOG2NL_MODEL (log2nl.txt cotto). Cloud: GEN_MODEL + system inline.
		String l2nModel = inlineSystem ? GEN_MODEL : LOG2NL_MODEL;
		String l2nSys   = inlineSystem ? LOG2NL_SYS : null;
		JSONObject answer = new JSONObject( generateRaw( l2nModel, prompt, null, l2nSys ) );
		String response = answer.getString( "response" ).replaceAll( "(?s)<think>.*?</think>", "" ).trim();
		// Leak-guard: il Cloud non e' deterministico e puo' ignorare la Regola #7, restituendo il
		// termine logico grezzo (es. "I your_lighter(aurelio,mine)"). In quel caso NON mostrare atomi
		// al giocatore: sostituisci con una frase di cortesia in prima persona.
		if ( looksLikeLogicTerm( response, msg.getPropCont().toString() ) ) {
			System.out.println( "[LOG] " + agName + " log2nl leak-guard: risposta sospetta, uso fallback. Raw=" + response );
			return "I'm not sure I follow — could you ask me that differently?";
		}
		return response;
	}

	/**
	 * Heuristica anti-leak per log2nl: true se la risposta del LLM "sembra" un termine logico grezzo
	 * (functor con parentesi, oppure contiene il termine di CONTENT) invece di una frase naturale.
	 * @param response la risposta del modello (gia' ripulita da &lt;think&gt;)
	 * @param content il termine logico originale (CONTENT), da non far trapelare
	 * @return true se va sostituita col fallback di cortesia
	 */
	private boolean looksLikeLogicTerm( String response, String content ) {
		if ( response == null || response.isEmpty() )
			return true;
		// functor(...) eventualmente preceduto da "I " — pattern tipico del leak della Regola #7
		if ( response.matches( "(?s)^\\s*[Ii]?\\s*[a-z][A-Za-z0-9_]*\\s*\\([^)]*\\).*" ) )
			return true;
		// contiene letteralmente il termine di CONTENT (o la sua parte-functor prima della parentesi)
		if ( content != null && ! content.isEmpty() ) {
			String functor = content.replaceAll( "\\(.*$", "" ).trim();
			if ( response.contains( content ) || ( ! functor.isEmpty() && response.contains( functor + "(" ) ) )
				return true;
		}
		return false;
	}

	/**
	 * This function translates a message using model and following format
	 * @param model the model to use
	 * @param str the input message
	 * @param format the Json Schema for the output
	 * @return the JSON string received (to handle)
	 */
	private String generate( String model, String str, JSONObject format ) {
		return generateRaw( model, str, format, null );
	}

	/**
	 * Creates a prompted model
	 * @param from the starting model
	 * @param model the final model name
	 * @param t the temperature
	 * @param sys_file the path to a system file
	 */
	public void create( String from, String model, float t, String sys_file ) {
		JSONObject params = new JSONObject();
		params.put( "temperature", t );
		JSONObject json = new JSONObject();
		json.put( "from", from );
		json.put( "model", model );
		json.put( "stream", false );
		json.put( "parameters", params );
		try {
			json.put( "system", Files.readString( Path.of(sys_file ) ) );
			HttpRequest request = HttpRequest.newBuilder()
				.uri( URI.create( URL + "create" ) )
				.header( "Content-Type", "application/json" )
				.POST( HttpRequest.BodyPublishers.ofString( json.toString() ) )
				.build();

			HttpResponse<String> httpResponse = client.send(request, HttpResponse.BodyHandlers.ofString());
		} catch ( IOException e ) {
			e.printStackTrace();
		} catch ( InterruptedException e ) {
			e.printStackTrace();
		}
	}

	/**
	 * Creates a prompted model
	 * @param from the starting model
	 * @param model the final model name
	 * @param t the temperature
	 * @param sys_file the path to a system file
	 * @param seed the seed for generation
	 */
	public void create( String from, String model, float t, String sys_file, int seed ) {
		JSONObject params = new JSONObject();
		params.put( "temperature", t );
		params.put( "seed", seed );
		JSONObject json = new JSONObject();
		json.put( "from", from );
		json.put( "model", model );
		json.put( "stream", false );
		json.put( "parameters", params );
		try {
			json.put( "system", Files.readString( Path.of(sys_file ) ) );
			HttpRequest request = HttpRequest.newBuilder()
				.uri( URI.create( URL + "create" ) )
				.header( "Content-Type", "application/json" )
				.POST( HttpRequest.BodyPublishers.ofString( json.toString() ) )
				.build();

			HttpResponse<String> httpResponse = client.send(request, HttpResponse.BodyHandlers.ofString());
		} catch ( IOException e ) {
			e.printStackTrace();
		} catch ( InterruptedException e ) {
			e.printStackTrace();
		}
	}
}
