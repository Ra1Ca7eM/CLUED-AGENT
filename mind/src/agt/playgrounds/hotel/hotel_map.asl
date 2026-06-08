// HOTEL VALTIERI — mappa RCC (topologia confermata 2026-05-31)

// POI comuni
map_ntpp(salone_camino, salone).
map_ntpp(salone_tavolino, salone).
map_ntpp(cucina_lavandino, cucina).
map_ntpp(bagno_wc, bagno).

// POI stanze (room1=Evelina, room2=Investigatore, room3=Vittorio, room4=Clarissa, room5=Alberto, room6=Aurelio)
map_ntpp(evelinaRoom_contratto, room1).
map_ntpp(evelinaRoom_lettera, room1).
map_ntpp(investigatoreRoom_chiave, room2).
map_ntpp(vittorioRoom_stivali, room3).
map_ntpp(clarissaRoom_chiave, room4).
map_ntpp(albertoRoom_chiave, room5).
map_ntpp(albertoRoom_digitalina_release, room5).
map_ntpp(aurelioRoom_diario, room6).
map_ntpp(aurelioRoom_accendino, room6).
map_ntpp(aurelioRoom_bicchieri, room6).

// POI cantina / giardino
map_ntpp(cantina_baule, cantina).
map_ntpp(cantina_boccetta, cantina).
map_ntpp(giardino1, giardino).
map_ntpp(giardino2, giardino).

// Pool patrol randomico (solo POI navigabili)
walk_poi(salone_camino).
walk_poi(salone_tavolino).
walk_poi(cucina_lavandino).
walk_poi(evelinaRoom_contratto).
walk_poi(evelinaRoom_lettera).
walk_poi(investigatoreRoom_chiave).
walk_poi(vittorioRoom_stivali).
walk_poi(clarissaRoom_chiave).
walk_poi(albertoRoom_chiave).
walk_poi(aurelioRoom_diario).
walk_poi(aurelioRoom_accendino).
walk_poi(aurelioRoom_bicchieri).
walk_poi(cantina_baule).
walk_poi(cantina_boccetta).
walk_poi(giardino1).
walk_poi(giardino2).

// Zone hotel (piano terra)
map_ntpp(salone, hotel).
map_ntpp(cucina, hotel).
map_ntpp(bagno, hotel).
map_ntpp(scalaEst_pt, hotel).
map_ntpp(scalaOvest_pt, hotel).

// Zone hotel (primo piano)
map_ntpp(scalaEst_pp, hotel).
map_ntpp(scalaOvest_pp, hotel).
map_ntpp(corridoio, hotel).
map_ntpp(room1, hotel).
map_ntpp(room2, hotel).
map_ntpp(room3, hotel).
map_ntpp(room4, hotel).
map_ntpp(room5, hotel).
map_ntpp(room6, hotel).

// Zone hotel (cantina / giardino)
map_ntpp(scalaOvest_cantina, hotel).
map_ntpp(cantina, hotel).
map_ntpp(giardino, hotel).

// Adiacenza senza porta — scale e passaggi liberi
map_ec(salone, scalaEst_pt).
map_ec(salone, scalaOvest_pt).
map_ec(scalaEst_pt, scalaEst_pp).
map_ec(scalaEst_pp, corridoio).
map_ec(scalaOvest_pt, scalaOvest_pp).
map_ec(scalaOvest_pp, corridoio).
map_ec(scalaOvest_pt, scalaOvest_cantina).
map_ec(scalaOvest_cantina, cantina).

// Porte — piano terra
map_po(salone, doorway).
map_po(doorway, bagno).
map_po(cucina, door_B2).
map_po(door_B2, giardino).
map_po(cucina, door_B3).
map_po(door_B3, salone).
map_po(giardino, door_B4).
map_po(door_B4, cucina).

// Porte — primo piano (corridoio ↔ stanze)
map_po(corridoio, doorway2).
map_po(doorway2, room6).
map_po(corridoio, doorway3).
map_po(doorway3, room4).
map_po(corridoio, doorway4).
map_po(doorway4, room2).
map_po(corridoio, doorway5).
map_po(doorway5, room1).
map_po(corridoio, doorway6).
map_po(doorway6, room3).
map_po(corridoio, doorway7).
map_po(doorway7, room5).

// Nomi artifact porta (per follow_path)
map_door(doorway).
map_door(doorway2).
map_door(doorway3).
map_door(doorway4).
map_door(doorway5).
map_door(doorway6).
map_door(doorway7).
map_door(door_B2).
map_door(door_B3).
map_door(door_B4).

door_art(D) :- map_door(D).

door_passage_region( Door, [ Next | _ ], Next ) :-
    not door_art( Next )
    & po( Next, Door ).

requires_door(From, To, Door) :- po(From, Door) & po(Door, To) & not ec(From, To).

// Zona portal (teleport Godot obbligatorio)
map_portal_zone(giardino).
map_portal_entry(giardino, cucina, door_B2).
map_portal_exit(giardino, cucina, door_B4).

portal_zone(Z) :- map_portal_zone(Z).
portal_entry(Target, Via, Door) :- map_portal_entry(Target, Via, Door).
portal_exit(From, Via, Door) :- map_portal_exit(From, Via, Door).

hotel_zone(Z) :- map_ntpp(Z, hotel).

poi_target(T) :- map_ntpp(T, Z) & not hotel_zone(T).

// Zone di transito: niente walk al centro (solo arrivo simbolico)
transit_zone(corridoio).
transit_zone(scalaEst_pt).
transit_zone(scalaEst_pp).
transit_zone(scalaOvest_pt).
transit_zone(scalaOvest_pp).
transit_zone(scalaOvest_cantina).

// Scale: transito simbolico disabilitato — follow_path fa vesna.walk
map_stair_zone(scalaEst_pt).
map_stair_zone(scalaEst_pp).
map_stair_zone(scalaOvest_pt).
map_stair_zone(scalaOvest_pp).
map_stair_zone(scalaOvest_cantina).

stair_zone(Z) :- map_stair_zone(Z).

needs_center_walk(T) :- nav_goal(T) & not transit_zone(T).
needs_center_walk(T) :- poi_target(T).
