# CLUED-AGENT

Investigative 3D video game prototype (**Godot 4.6**) coupled with a **JaCaMo + VEsNA**
multi-agent system, with natural-language NPC dialogue via **ChatBDI** (Ollama).
University internship project — *Hotel Valtieri* murder case.

This repository is a monorepo with two modules, each with its own bilingual
(English / Italian) documentation:

| Module | Description | Docs |
|--------|-------------|------|
| [`game/`](game/README.md) | Godot 4.6 game: FPS investigation, clues, UV torch, notebook/map, NPC bodies | [game/README.md](game/README.md) |
| [`mind/`](mind/README.md) | JaCaMo MAS: VEsNA agent bodies, CArtAgO artifacts, ChatBDI dialogue + Game Master | [mind/README.md](mind/README.md) |

## Quick start

1. **Ollama** — local server running (for embeddings) and `ollama signin` (for cloud
   generation); `ollama pull nomic-embed-text`.
2. **Godot** — open the `game/` folder in **Godot 4.6** (Forward+) and run `Main.tscn`
   (first open triggers an asset re-import).
3. **MAS** — `cd mind` then `gradle run` (requires **JDK 23**).

Full instructions, ports and architecture are in [`game/README.md`](game/README.md) §19
and [`mind/README.md`](mind/README.md) §1.

> **Note on assets:** binary assets (`.glb`, `.bin`, `.png`, `.res`, audio) are protected
> by [`.gitattributes`](.gitattributes) so git never normalizes their line endings — this
> keeps textures and animation-loop settings intact across clone/checkout.
