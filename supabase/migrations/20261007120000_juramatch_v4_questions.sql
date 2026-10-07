-- =====================================================================
-- JuraMatch v4 : 6 cartes Question
-- Le joueur A pose une carte Question et désigne un joueur B.
-- B voit une question (tirée des descriptions des communes) et 3 réponses.
-- Bonne réponse : B choisit qui pioche 2 cartes. Mauvaise : B pioche 2 cartes.
-- Paquet : 51 communes + 14 Interdictions + 9 cartes +2 + 6 Questions = 80 cartes.
-- =====================================================================
alter table public.jm_cards add column if not exists effect text;
update public.jm_cards set effect = 'interdiction' where kind = 'special' and cardinality(icons) = 1;
update public.jm_cards set effect = 'plus2' where id like 's-plus2-%';

insert into public.jm_cards(id, kind, name, district, icons, in_deck, draw_next, effect)
select 's-question-' || n, 'special', 'Carte Question', null, '{}'::text[], true, 0, 'question'
from generate_series(1, 6) n
on conflict (id) do update set in_deck = true, effect = 'question', kind = 'special', icons = '{}'::text[], draw_next = 0;

create table if not exists public.jm_questions (
  id         int primary key,
  commune_id text not null references public.jm_cards(id),
  question   text not null,
  choices    text[] not null   -- choices[1] = bonne réponse
);
alter table public.jm_questions enable row level security;

-- Question en cours dans la partie (null s'il n'y en a pas)
alter table public.jm_rooms add column if not exists question jsonb;
insert into public.jm_questions(id, commune_id, question, choices) values
(1, 'c-alle', 'Quel bourg d''Ajoie est desservi par les Chemins de fer du Jura et entouré de terres agricoles ?', array['Alle', 'Bure', 'Soubey']),
(2, 'c-basse-allaine', 'Quelle commune réunit notamment Buix, Courtemaîche et Montignez ?', array['Basse-Allaine', 'Haute-Ajoie', 'La Baroche']),
(3, 'c-basse-vendline', 'Quelle commune est née de la réunion de Bonfol et Beurnevésin ?', array['Basse-Vendline', 'Damphreux-Lugnez', 'Vendlincourt']),
(4, 'c-boncourt', 'Quel village-frontière du nord de l''Ajoie est relié au rail vers Delle ?', array['Boncourt', 'Fahy', 'Courchavon']),
(5, 'c-bure', 'Quel village agricole de Haute-Ajoie est connu pour sa place d''armes ?', array['Bure', 'Grandfontaine', 'Fahy']),
(6, 'c-clos-du-doubs', 'Quelle commune est organisée autour de Saint-Ursanne, cité médiévale emblématique du Jura ?', array['Clos du Doubs', 'Soubey', 'Saint-Brais']),
(7, 'c-coeuve', 'Quel village ajoulot est connu pour son château et ses lavoirs historiques ?', array['Cœuve', 'Cornol', 'Courchavon']),
(8, 'c-cornol', 'Quel village se trouve proche du Mont Terri ?', array['Cornol', 'Courgenay', 'Alle']),
(9, 'c-courchavon', 'Quel petit village se trouve dans la vallée de l''Allaine, entre Porrentruy et la frontière française ?', array['Courchavon', 'Courtedoux', 'Cœuve']),
(10, 'c-courgenay', 'Quel bourg d''Ajoie, desservi par le rail et l''A16, a une tradition microtechnique liée à l''horlogerie ?', array['Courgenay', 'Bure', 'Damphreux-Lugnez']),
(11, 'c-courtedoux', 'Quelle commune est connue pour les découvertes paléontologiques faites lors des travaux de l''A16 ?', array['Courtedoux', 'Boncourt', 'Bure']),
(12, 'c-damphreux-lugnez', 'Quelle commune issue d''une fusion est connue pour ses zones humides ?', array['Damphreux-Lugnez', 'Fahy', 'Courchavon']),
(13, 'c-fahy', 'Dans quel village de Haute-Ajoie, contre la France, l''agriculture côtoie-t-elle des activités industrielles ?', array['Fahy', 'Courgenay', 'Cœuve']),
(14, 'c-fontenais', 'Quelle commune voisine de Porrentruy comprend notamment Bressaucourt ?', array['Fontenais', 'Courtedoux', 'Courchavon']),
(15, 'c-grandfontaine', 'Quel village de Haute-Ajoie est marqué historiquement par le travail de la pierre ?', array['Grandfontaine', 'Fahy', 'Bure']),
(16, 'c-haute-ajoie', 'Dans quelle commune se trouvent les grottes de Réclère ?', array['Haute-Ajoie', 'Grandfontaine', 'Fahy']),
(17, 'c-la-baroche', 'Quelle commune réunit notamment Asuel, Charmoille, Miécourt et Pleujouse ?', array['La Baroche', 'Haute-Ajoie', 'Basse-Allaine']),
(18, 'c-porrentruy', 'Quelle ville est l''ancienne résidence des princes-évêques ?', array['Porrentruy', 'Courgenay', 'Saignelégier']),
(19, 'c-vendlincourt', 'Quel village d''Ajoie réunit scierie, mécanique de précision et héritage horloger ?', array['Vendlincourt', 'Alle', 'Cœuve']),
(20, 'c-boecourt', 'Quelle commune se trouve proche du nœud routier jurassien ?', array['Boécourt', 'Courtételle', 'Mettembert']),
(21, 'c-bourrignon', 'Quel village se trouve sur l''ancien passage vers Lucelle et les Rangiers ?', array['Bourrignon', 'Saulcy', 'Soyhières']),
(22, 'c-chatillon', 'Quelle petite commune est connue pour son célèbre chêne monumental ?', array['Châtillon', 'Mettembert', 'Movelier']),
(23, 'c-courchapoix', 'Quel village du Val Terbi est traversé par la Scheulte ?', array['Courchapoix', 'Courroux', 'Soyhières']),
(24, 'c-courrendlin', 'Quelle commune est marquée par le passé industriel de Choindez ?', array['Courrendlin', 'Courroux', 'Moutier']),
(25, 'c-courroux', 'Quelle grande commune de l''agglomération de Delémont se trouve dans la vallée de la Birse ?', array['Courroux', 'Develier', 'Courtételle']),
(26, 'c-courtetelle', 'Quelle commune de la vallée de la Sorne se trouve entre Delémont et Haute-Sorne ?', array['Courtételle', 'Develier', 'Rossemaison']),
(27, 'c-delemont', 'Quelle ville est la capitale du canton du Jura ?', array['Delémont', 'Porrentruy', 'Moutier']),
(28, 'c-develier', 'Quelle commune se trouve immédiatement à l''ouest de Delémont, sur le corridor de l''A16 ?', array['Develier', 'Rossemaison', 'Courroux']),
(29, 'c-ederswiler', 'Quelle commune jurassienne est essentiellement germanophone ?', array['Ederswiler', 'Movelier', 'Pleigne']),
(30, 'c-haute-sorne', 'Quelle commune comprend notamment Bassecourt, Courfaivre et Glovelier ?', array['Haute-Sorne', 'Courtételle', 'Val Terbi']),
(31, 'c-mervelier', 'Quel village se trouve au pied des reliefs menant au col du Schelten ?', array['Mervelier', 'Saulcy', 'Bourrignon']),
(32, 'c-mettembert', 'Quelle petite commune est installée sur les hauteurs au nord de Delémont, entre forêts et terres agricoles ?', array['Mettembert', 'Courtételle', 'Rossemaison']),
(33, 'c-movelier', 'Quel village élevé et boisé est proche du plateau de Pleigne ?', array['Movelier', 'Soyhières', 'Develier']),
(34, 'c-pleigne', 'Quelle commune de plateau comprend le secteur de Lucelle ?', array['Pleigne', 'Saulcy', 'Ederswiler']),
(35, 'c-rossemaison', 'Quelle commune est connue dans le Jura pour l''inline hockey ?', array['Rossemaison', 'Courtételle', 'Develier']),
(36, 'c-saulcy', 'Quel village de montagne du district de Delémont se trouve à plus de 900 m d''altitude ?', array['Saulcy', 'Movelier', 'Soyhières']),
(37, 'c-soyhieres', 'Quel village au nord de Delémont se trouve au pied des vestiges de son château ?', array['Soyhières', 'Châtillon', 'Courroux']),
(38, 'c-val-terbi', 'Quelle grande commune est organisée autour de Vicques ?', array['Val Terbi', 'Courchapoix', 'Mervelier']),
(39, 'c-lajoux', 'Quel village élevé des Franches-Montagnes, historiquement agricole, est aussi marqué par l''horlogerie et la mécanique ?', array['Lajoux', 'Les Enfers', 'Soubey']),
(40, 'c-le-bemont', 'Quelle petite commune du haut plateau est desservie par le train rouge des CJ ?', array['Le Bémont', 'Les Enfers', 'Lajoux']),
(41, 'c-le-noirmont', 'Quelle commune est connue pour sa clinique de réadaptation ?', array['Le Noirmont', 'Saignelégier', 'Les Bois']),
(42, 'c-les-bois', 'Quelle commune du haut plateau, proche de la France, est connue pour l''horlogerie et les sports d''hiver ?', array['Les Bois', 'Les Genevez', 'Saint-Brais']),
(43, 'c-les-breuleux', 'Quel bourg industriel des Franches-Montagnes, à plus de 1000 m, est associé à l''horlogerie et aux sports d''hiver ?', array['Les Breuleux', 'Soubey', 'Le Bémont']),
(44, 'c-les-enfers', 'Quelle très petite commune de montagne est caractérisée par ses fermes et ses pâturages boisés ?', array['Les Enfers', 'Saignelégier', 'Le Noirmont']),
(45, 'c-les-genevez', 'Quel village abrite le Musée rural jurassien ?', array['Les Genevez', 'Lajoux', 'Montfaucon']),
(46, 'c-montfaucon', 'Dans quelle commune se trouve la gare de Pré-Petitjean ?', array['Montfaucon', 'Saint-Brais', 'Muriaux']),
(47, 'c-muriaux', 'Quelle commune du plateau possède des vestiges castraux et une halte ferroviaire des CJ ?', array['Muriaux', 'Les Enfers', 'Lajoux']),
(48, 'c-saignelegier', 'Quelle commune accueille le Marché-Concours national de chevaux ?', array['Saignelégier', 'Le Noirmont', 'Montfaucon']),
(49, 'c-saint-brais', 'Quelle commune comprend la halte ferroviaire de Bollement ?', array['Saint-Brais', 'Soubey', 'Muriaux']),
(50, 'c-soubey', 'Quel petit village de la vallée du Doubs possède un ancien moulin hydroélectrique ?', array['Soubey', 'Saint-Brais', 'Les Enfers']),
(51, 'c-moutier', 'Quelle ville est devenue jurassienne en 2026 ?', array['Moutier', 'Courrendlin', 'Delémont'])
on conflict (id) do update set commune_id = excluded.commune_id, question = excluded.question, choices = excluded.choices;

-- ---------- Fonctions ----------

-- Termine la question en cours : le tour passe au joueur après celui qui l'a posée.
create or replace function jm_private.end_question(p_room uuid)
returns void language plpgsql set search_path = public, jm_private as $$
declare r public.jm_rooms; by_seat int;
begin
  select * into r from public.jm_rooms where id = p_room;
  select seat into by_seat from public.jm_players where id = (r.question->>'by')::uuid;
  update public.jm_rooms
     set question = null, phase = 'play', drawn_card = null,
         current_seat = jm_private.next_seat(p_room, coalesce(by_seat, r.current_seat))
   where id = p_room;
end $$;

create or replace function public.jm_play_question(p_token uuid, p_card text, p_target uuid)
returns void language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
  tgt public.jm_players;
  qq public.jm_questions;
  ord int[];
  left_cards int;
begin
  select * into r from public.jm_rooms where id = me.room_id for update;
  if r.status <> 'playing' then raise exception 'La partie n''est pas en cours' using errcode = 'P0001'; end if;
  if r.question is not null then raise exception 'Une question est déjà en cours' using errcode = 'P0001'; end if;
  if r.current_seat <> me.seat then raise exception 'Ce n''est pas ton tour' using errcode = 'P0001'; end if;
  select * into me from public.jm_players where id = me.id for update;
  if not (p_card = any(me.hand)) then raise exception 'Tu n''as pas cette carte' using errcode = 'P0001'; end if;
  if (select effect from public.jm_cards where id = p_card) is distinct from 'question' then
    raise exception 'Ce n''est pas une carte Question' using errcode = 'P0001';
  end if;
  if r.phase = 'drawn' and p_card <> r.drawn_card then
    raise exception 'Après avoir pioché, tu ne peux poser que la carte piochée' using errcode = 'P0001';
  end if;
  select * into tgt from public.jm_players where id = p_target and room_id = r.id and active;
  if not found or tgt.id = me.id then raise exception 'Choisis un autre joueur de la partie' using errcode = 'P0001'; end if;

  update public.jm_players set hand = array_remove(hand, p_card) where id = me.id
  returning cardinality(hand) into left_cards;
  update public.jm_rooms set specials = specials || p_card, phase = 'play', drawn_card = null where id = r.id;

  if left_cards = 0 then
    update public.jm_rooms set status = 'finished', winner_id = me.id where id = r.id;
    perform jm_private.bump(r.id, jsonb_build_object('k', 'play', 'p', me.name, 'c', p_card));
    perform jm_private.bump(r.id, jsonb_build_object('k', 'win', 'p', me.name));
    return;
  end if;

  select * into qq from public.jm_questions order by random() limit 1;
  ord := array(select x from unnest(array[1, 2, 3]) x order by random());
  update public.jm_rooms
     set question = jsonb_build_object(
           'by', me.id, 'by_name', me.name, 'target', tgt.id, 'target_name', tgt.name,
           'text', qq.question,
           'choices', jsonb_build_array(qq.choices[ord[1]], qq.choices[ord[2]], qq.choices[ord[3]]),
           'answer', array_position(ord, 1) - 1,
           'commune', qq.commune_id,
           'stage', 'answer')
   where id = r.id;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'question', 'p', me.name, 'q', tgt.name, 'c', p_card, 'left', left_cards));
end $$;

create or replace function public.jm_answer_question(p_token uuid, p_choice int)
returns jsonb language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
  q jsonb;
  ok boolean;
  got int;
  good text;
begin
  select * into r from public.jm_rooms where id = me.room_id for update;
  q := r.question;
  if q is null or q->>'stage' <> 'answer' then raise exception 'Aucune question en attente' using errcode = 'P0001'; end if;
  if (q->>'target')::uuid <> me.id then raise exception 'Cette question n''est pas pour toi' using errcode = 'P0001'; end if;
  if p_choice is null or p_choice not between 0 and 2 then raise exception 'Réponse invalide' using errcode = 'P0001'; end if;

  ok := p_choice = (q->>'answer')::int;
  good := q->'choices'->>((q->>'answer')::int);
  perform jm_private.bump(r.id, jsonb_build_object('k', 'answer', 'p', me.name, 'ok', ok, 'a', good,
          'g', q->'choices'->>p_choice, 'c', q->>'commune'));
  if ok then
    update public.jm_rooms set question = q || jsonb_build_object('stage', 'pick') where id = r.id;
    perform jm_private.bump(r.id, null);
  else
    got := jm_private.draw_n(r.id, me.id, 2);
    perform jm_private.end_question(r.id);
    perform jm_private.bump(r.id, jsonb_build_object('k', 'penalty', 'p', me.name, 'n', got, 'c', 's-question-1'));
  end if;
  return jsonb_build_object('correct', ok, 'answer', good);
end $$;

-- Après une bonne réponse : le joueur interrogé choisit qui pioche 2 cartes.
create or replace function public.jm_question_pick(p_token uuid, p_victim uuid)
returns void language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
  victim public.jm_players;
  got int;
begin
  select * into r from public.jm_rooms where id = me.room_id for update;
  if r.question is null or r.question->>'stage' <> 'pick' then raise exception 'Rien à choisir' using errcode = 'P0001'; end if;
  if (r.question->>'target')::uuid <> me.id then raise exception 'Ce choix ne t''appartient pas' using errcode = 'P0001'; end if;
  select * into victim from public.jm_players where id = p_victim and room_id = r.id and active;
  if not found or victim.id = me.id then raise exception 'Choisis un autre joueur' using errcode = 'P0001'; end if;
  got := jm_private.draw_n(r.id, victim.id, 2);
  perform jm_private.end_question(r.id);
  perform jm_private.bump(r.id, jsonb_build_object('k', 'penalty', 'p', victim.name, 'n', got, 'c', 's-question-1', 'by', me.name));
end $$;

-- Les autres actions sont bloquées pendant une question
create or replace function public.jm_play_card(p_token uuid, p_card text)
returns void language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
  v_card public.jm_cards;
  left_cards int;
  nxt int;
  victim public.jm_players;
  got int;
begin
  select * into r from public.jm_rooms where id = me.room_id for update;
  if r.status <> 'playing' then raise exception 'La partie n''est pas en cours' using errcode = 'P0001'; end if;
  if r.question is not null then raise exception 'Une question est en cours' using errcode = 'P0001'; end if;
  if r.current_seat <> me.seat then raise exception 'Ce n''est pas ton tour' using errcode = 'P0001'; end if;
  select * into me from public.jm_players where id = me.id for update;
  if not (p_card = any(me.hand)) then raise exception 'Tu n''as pas cette carte' using errcode = 'P0001'; end if;
  if r.phase = 'drawn' and p_card <> r.drawn_card then
    raise exception 'Après avoir pioché, tu ne peux poser que la carte piochée' using errcode = 'P0001';
  end if;
  select * into v_card from public.jm_cards c where c.id = p_card;
  if v_card.effect = 'question' then
    raise exception 'Choisis d''abord le joueur qui doit répondre' using errcode = 'P0001';
  end if;
  if not jm_private.is_playable(p_card, r) then
    raise exception 'Cette carte ne peut pas être posée' using errcode = 'P0001';
  end if;

  update public.jm_players set hand = array_remove(hand, p_card) where id = me.id
  returning cardinality(hand) into left_cards;

  if v_card.kind = 'special' then
    update public.jm_rooms set specials = specials || p_card where id = r.id;
  else
    update public.jm_rooms set discard = discard || p_card where id = r.id;
  end if;

  if left_cards = 0 then
    update public.jm_rooms set status = 'finished', winner_id = me.id, phase = 'play', drawn_card = null where id = r.id;
    perform jm_private.bump(r.id, jsonb_build_object('k', 'play', 'p', me.name, 'c', p_card));
    perform jm_private.bump(r.id, jsonb_build_object('k', 'win', 'p', me.name));
    return;
  end if;

  nxt := jm_private.next_seat(r.id, me.seat);
  update public.jm_rooms set current_seat = nxt, phase = 'play', drawn_card = null where id = r.id;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'play', 'p', me.name, 'c', p_card, 'left', left_cards));

  if v_card.draw_next > 0 then
    select * into victim from public.jm_players where room_id = r.id and seat = nxt;
    got := jm_private.draw_n(r.id, victim.id, v_card.draw_next);
    perform jm_private.bump(r.id, jsonb_build_object('k', 'penalty', 'p', victim.name, 'n', got, 'c', p_card));
  end if;
end $$;

create or replace function public.jm_draw_card(p_token uuid)
returns jsonb language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
  c text;
  pool text[];
  v_playable boolean;
begin
  select * into r from public.jm_rooms where id = me.room_id for update;
  if r.status <> 'playing' then raise exception 'La partie n''est pas en cours' using errcode = 'P0001'; end if;
  if r.question is not null then raise exception 'Une question est en cours' using errcode = 'P0001'; end if;
  if r.current_seat <> me.seat then raise exception 'Ce n''est pas ton tour' using errcode = 'P0001'; end if;
  if r.phase <> 'play' then raise exception 'Tu as déjà pioché ce tour-ci' using errcode = 'P0001'; end if;

  if cardinality(r.deck) = 0 then
    pool := coalesce(r.discard[1:cardinality(r.discard) - 1], '{}') || coalesce(r.specials[1:cardinality(r.specials) - 1], '{}');
    if cardinality(pool) > 0 then
      update public.jm_rooms
         set deck = jm_private.shuffle(pool),
             discard = r.discard[cardinality(r.discard):cardinality(r.discard)],
             specials = case when cardinality(r.specials) > 0 then r.specials[cardinality(r.specials):cardinality(r.specials)] else '{}' end
       where id = r.id
      returning * into r;
      perform jm_private.bump(r.id, jsonb_build_object('k', 'reshuffle', 'n', cardinality(pool)));
    end if;
  end if;

  if cardinality(r.deck) = 0 then
    update public.jm_rooms set current_seat = jm_private.next_seat(r.id, me.seat) where id = r.id;
    perform jm_private.bump(r.id, jsonb_build_object('k', 'empty', 'p', me.name));
    return jsonb_build_object('card', null, 'playable', false);
  end if;

  c := r.deck[1];
  update public.jm_rooms set deck = deck[2:] where id = r.id returning * into r;
  update public.jm_players set hand = hand || c where id = me.id;
  v_playable := jm_private.is_playable(c, r);

  if v_playable then
    update public.jm_rooms set phase = 'drawn', drawn_card = c where id = r.id;
  else
    update public.jm_rooms set current_seat = jm_private.next_seat(r.id, me.seat), phase = 'play', drawn_card = null
     where id = r.id;
  end if;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'draw', 'p', me.name, 'playable', v_playable));
  return jsonb_build_object('card', c, 'playable', v_playable);
end $$;

create or replace function public.jm_pass(p_token uuid)
returns void language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
begin
  select * into r from public.jm_rooms where id = me.room_id for update;
  if r.question is not null then raise exception 'Une question est en cours' using errcode = 'P0001'; end if;
  if r.status <> 'playing' or r.current_seat <> me.seat then raise exception 'Ce n''est pas ton tour' using errcode = 'P0001'; end if;
  if r.phase <> 'drawn' then raise exception 'Pioche d''abord une carte' using errcode = 'P0001'; end if;
  update public.jm_rooms set current_seat = jm_private.next_seat(r.id, me.seat), phase = 'play', drawn_card = null where id = r.id;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'keep', 'p', me.name));
end $$;

create or replace function public.jm_leave_room(p_token uuid)
returns void language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players;
  r public.jm_rooms;
  remaining int;
  last_one public.jm_players;
begin
  select * into me from public.jm_players where token = p_token;
  if not found then return; end if;
  select * into r from public.jm_rooms where id = me.room_id for update;

  if r.status = 'playing' then
    update public.jm_players set active = false, hand = '{}' where id = me.id;
    update public.jm_rooms set deck = jm_private.shuffle(deck || me.hand) where id = r.id;
    select count(*) into remaining from public.jm_players where room_id = r.id and active;
    if remaining < 2 then
      select * into last_one from public.jm_players where room_id = r.id and active limit 1;
      update public.jm_rooms set status = 'finished', winner_id = last_one.id, question = null where id = r.id;
    elsif r.question is not null and ((r.question->>'target')::uuid = me.id or (r.question->>'by')::uuid = me.id) then
      perform jm_private.end_question(r.id);
    elsif r.question is null and r.current_seat = me.seat then
      update public.jm_rooms set current_seat = jm_private.next_seat(r.id, me.seat), phase = 'play', drawn_card = null where id = r.id;
    end if;
  else
    update public.jm_players set active = false, hand = '{}' where id = me.id;
  end if;

  if not exists (select 1 from public.jm_players where room_id = r.id and active) then
    update public.jm_rooms set status = 'finished' where id = r.id;
    return;
  end if;
  if r.host_id = me.id then
    update public.jm_rooms
       set host_id = (select id from public.jm_players where room_id = r.id and active order by seat limit 1)
     where id = r.id;
  end if;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'leave', 'p', me.name));
end $$;

create or replace function public.jm_back_to_lobby(p_token uuid)
returns void language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
begin
  select * into r from public.jm_rooms where id = me.room_id for update;
  if r.host_id <> me.id then raise exception 'Seul l''hôte peut faire ça' using errcode = 'P0001'; end if;
  if r.status <> 'finished' then raise exception 'La partie n''est pas terminée' using errcode = 'P0001'; end if;
  update public.jm_players set hand = '{}' where room_id = r.id;
  update public.jm_rooms
     set status = 'lobby', deck = '{}', discard = '{}', specials = '{}', current_seat = null,
         phase = 'play', drawn_card = null, winner_id = null, log = '[]'::jsonb, question = null
   where id = r.id;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'lobby'));
end $$;

create or replace function public.jm_start_game(p_token uuid, p_first uuid default null)
returns void language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
  n int; per int;
  v_deck text[]; c text; pos int;
  pl record;
  first_seat int;
begin
  select * into r from public.jm_rooms where id = me.room_id for update;
  if r.host_id <> me.id then raise exception 'Seul l''hôte peut lancer la partie' using errcode = 'P0001'; end if;
  if r.status = 'playing' then raise exception 'Partie déjà en cours' using errcode = 'P0001'; end if;

  select count(*) into n from public.jm_players where room_id = r.id and active;
  if n < 2 then raise exception 'Il faut au moins 2 joueurs' using errcode = 'P0001'; end if;
  per := case when n <= 4 then 8 else 6 end;

  v_deck := jm_private.shuffle(array(select id from public.jm_cards where in_deck));
  for pl in select id from public.jm_players where room_id = r.id and active order by seat loop
    update public.jm_players set hand = v_deck[1:per] where id = pl.id;
    v_deck := v_deck[per + 1:];
  end loop;

  loop
    c := v_deck[1];
    v_deck := v_deck[2:];
    exit when (select k.kind from public.jm_cards k where k.id = c) = 'commune';
    pos := cardinality(v_deck) / 2;
    v_deck := v_deck[1:pos] || c || v_deck[pos + 1:];
  end loop;

  select seat into first_seat from public.jm_players where room_id = r.id and active and id = p_first;
  if first_seat is null then
    select seat into first_seat from public.jm_players where room_id = r.id and active order by random() limit 1;
  end if;

  update public.jm_rooms
     set status = 'playing', deck = v_deck, discard = array[c], specials = '{}',
         current_seat = first_seat, phase = 'play', drawn_card = null, winner_id = null,
         log = '[]'::jsonb, question = null
   where id = r.id;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'start',
            'p', (select name from public.jm_players where room_id = r.id and seat = first_seat), 'n', per));
end $$;

create or replace function public.jm_get_state(p_token uuid)
returns jsonb language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
  my_turn boolean;
begin
  select * into r from public.jm_rooms where id = me.room_id;
  my_turn := r.status = 'playing' and r.current_seat = me.seat and me.active and r.question is null;
  return jsonb_build_object(
    'code', r.code,
    'status', r.status,
    'version', r.version,
    'host_id', r.host_id,
    'current_seat', r.current_seat,
    'phase', r.phase,
    'winner_id', r.winner_id,
    'deck_count', cardinality(r.deck),
    'discard_count', cardinality(r.discard),
    'specials_count', cardinality(r.specials),
    'top_commune', case when cardinality(r.discard) > 0 then r.discard[cardinality(r.discard)] end,
    'top_special', case when cardinality(r.specials) > 0 then r.specials[cardinality(r.specials)] end,
    'forbidden', jm_private.forbidden_icon(r),
    'question', r.question - 'answer' - 'commune',
    'log', r.log,
    'players', (select coalesce(jsonb_agg(jsonb_build_object(
                    'id', p.id, 'name', p.name, 'seat', p.seat,
                    'count', cardinality(p.hand), 'active', p.active) order by p.seat), '[]'::jsonb)
                  from public.jm_players p where p.room_id = r.id and (p.active or r.status = 'playing')),
    'me', jsonb_build_object('id', me.id, 'name', me.name, 'seat', me.seat, 'hand', to_jsonb(me.hand), 'active', me.active),
    'drawn_card', case when my_turn then r.drawn_card end,
    'playable', case when my_turn then
        (select coalesce(jsonb_agg(h), '[]'::jsonb) from unnest(me.hand) h
          where jm_private.is_playable(h, r) and (r.phase = 'play' or h = r.drawn_card))
      else '[]'::jsonb end
  );
end $$;

grant execute on function public.jm_play_question(uuid, text, uuid), public.jm_answer_question(uuid, int),
  public.jm_question_pick(uuid, uuid) to anon, authenticated;
