/* "player" — ChatBDI interpreter agent (it represents the human player talking to the NPCs).
 *
 * This agent has NO beliefs and NO plans on purpose: all of its behaviour lives in the agent
 * architecture class chatbdi.Interpreter (declared via `ag-arch: chatbdi.Interpreter` in vesna.jcm).
 * The Interpreter:
 *   - receives the player's natural-language message (from the Godot chat via GodotBridge :8090,
 *     or from the Swing chat),
 *   - classifies it, routes it to the right functor through the embedding space, translates it to a
 *     KQML message and sends it to the target agent (sender = this agent's name, i.e. "player"),
 *   - translates the agent's reply back to natural language.
 *
 * The NPC plans react to messages coming from this sender, e.g. +!kqml_received( player, tell, ... ).
 */
