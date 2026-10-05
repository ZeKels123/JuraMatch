-- =====================================================================
-- JuraMatch — schéma de jeu en ligne
-- Toutes les règles sont appliquées côté serveur (fonctions PL/pgSQL),
-- les tables ne sont pas lisibles directement par les clients :
-- chaque joueur ne voit que sa propre main via jm_get_state().
-- =====================================================================

create schema if not exists jm_private;

-- ---------- Tables ----------------------------------------------------
create table if not exists public.jm_cards (
  id       text primary key,
  kind     text not null check (kind in ('commune','special')),
  name     text not null,
  district text,
  icons    text[] not null
);

create table if not exists public.jm_rooms (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique,
  status          text not null default 'lobby' check (status in ('lobby','playing','finished')),
  host_id         uuid,
  deck            text[] not null default '{}',
  discard         text[] not null default '{}',   -- pile Communes (dernier élément = sommet)
  specials        text[] not null default '{}',   -- pile Spéciales (dernier élément = carte active)
  current_seat    int,
  phase           text not null default 'play' check (phase in ('play','drawn')),
  drawn_card      text,
  winner_id       uuid,
  log             jsonb not null default '[]'::jsonb,
  version         int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table if not exists public.jm_players (
  id         uuid primary key default gen_random_uuid(),
  room_id    uuid not null references public.jm_rooms(id) on delete cascade,
  token      uuid not null unique default gen_random_uuid(),
  name       text not null,
  seat       int not null,
  hand       text[] not null default '{}',
  active     boolean not null default true,
  joined_at  timestamptz not null default now(),
  unique (room_id, seat)
);
create index if not exists jm_players_room_idx on public.jm_players(room_id);

alter table public.jm_cards   enable row level security;
alter table public.jm_rooms   enable row level security;
alter table public.jm_players enable row level security;
-- Lecture publique du catalogue de cartes uniquement (rien de secret).
create policy jm_cards_read on public.jm_cards for select to anon, authenticated using (true);
-- RLS activé sans politique sur jm_rooms / jm_players : aucun accès direct depuis le site.

-- ---------- Fonctions internes (non exposées) -------------------------
-- Le schéma jm_private n'est pas exposé par l'API REST.

create or replace function jm_private.shuffle(arr text[])
returns text[] language sql volatile as $$
  select coalesce(array_agg(x order by random()), '{}') from unnest(arr) as x
$$;

create or replace function jm_private.new_code()
returns text language plpgsql volatile as $$
declare
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text;
begin
  loop
    c := '';
    for i in 1..5 loop
      c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.jm_rooms where code = c);
  end loop;
  return c;
end $$;

create or replace function jm_private.me(p_token uuid)
returns public.jm_players language plpgsql stable as $$
declare p public.jm_players;
begin
  select * into p from public.jm_players where token = p_token;
  if not found then
    raise exception 'Joueur introuvable (session expirée ?)' using errcode = 'P0001';
  end if;
  return p;
end $$;

-- Ajoute un évènement au journal, incrémente la version et prévient les clients.
create or replace function jm_private.bump(p_room uuid, p_event jsonb)
returns void language plpgsql as $$
declare r public.jm_rooms;
begin
  update public.jm_rooms
     set log = case when p_event is null then log
                    else (case when jsonb_array_length(log) >= 40 then log - 0 else log end)
                         || jsonb_build_array(p_event || jsonb_build_object('t', extract(epoch from now())))
               end,
         version = version + 1,
         updated_at = now()
   where id = p_room
  returning * into r;
  begin
    perform realtime.send(jsonb_build_object('version', r.version), 'update', 'juramatch:' || r.code, false);
  exception when others then
    null; -- le temps réel est un bonus : les clients interrogent aussi régulièrement
  end;
end $$;

create or replace function jm_private.forbidden_icon(r public.jm_rooms)
returns text language sql stable as $$
  select c.icons[1] from public.jm_cards c
   where cardinality(r.specials) > 0 and c.id = r.specials[cardinality(r.specials)]
$$;

-- Une carte peut-elle être posée dans l'état actuel de la partie ?
create or replace function jm_private.is_playable(p_card text, r public.jm_rooms)
returns boolean language plpgsql stable as $$
declare
  c   public.jm_cards;
  top public.jm_cards;
  forbid text;
begin
  select * into c from public.jm_cards where id = p_card;
  if not found then return false; end if;
  if c.kind = 'special' then return true; end if;           -- une Spéciale se pose toujours sur sa pile
  forbid := jm_private.forbidden_icon(r);
  if forbid is not null and forbid = any(c.icons) then      -- interdiction active
    return false;
  end if;
  if cardinality(r.discard) = 0 then return true; end if;
  select * into top from public.jm_cards where id = r.discard[cardinality(r.discard)];
  return c.district = top.district or c.icons && top.icons; -- même district OU caractéristique commune
end $$;

create or replace function jm_private.next_seat(p_room uuid, p_seat int)
returns int language sql stable as $$
  select coalesce(
    (select seat from public.jm_players where room_id = p_room and active and seat > p_seat order by seat limit 1),
    (select seat from public.jm_players where room_id = p_room and active order by seat limit 1))
$$;


-- ---------- API publique (appelée par le site via supabase.rpc) ---------

create or replace function public.jm_create_room(p_name text)
returns jsonb language plpgsql security definer set search_path = public, jm_private as $$
declare
  v_name text := left(btrim(coalesce(p_name, '')), 20);
  r public.jm_rooms;
  p public.jm_players;
begin
  if v_name = '' then raise exception 'Choisis un pseudo' using errcode = 'P0001'; end if;
  insert into public.jm_rooms(code) values (jm_private.new_code()) returning * into r;
  insert into public.jm_players(room_id, name, seat) values (r.id, v_name, 0) returning * into p;
  update public.jm_rooms set host_id = p.id where id = r.id;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'create', 'p', v_name));
  return jsonb_build_object('code', r.code, 'token', p.token, 'player_id', p.id);
end $$;

create or replace function public.jm_join_room(p_code text, p_name text)
returns jsonb language plpgsql security definer set search_path = public, jm_private as $$
declare
  v_name text := left(btrim(coalesce(p_name, '')), 20);
  r public.jm_rooms;
  p public.jm_players;
  n int;
begin
  if v_name = '' then raise exception 'Choisis un pseudo' using errcode = 'P0001'; end if;
  select * into r from public.jm_rooms where code = upper(btrim(p_code)) for update;
  if not found then raise exception 'Aucune partie avec ce code' using errcode = 'P0001'; end if;
  if r.status <> 'lobby' then raise exception 'La partie a déjà commencé' using errcode = 'P0001'; end if;
  select count(*) into n from public.jm_players where room_id = r.id and active;
  if n >= 6 then raise exception 'La partie est complète (6 joueurs max.)' using errcode = 'P0001'; end if;
  if exists (select 1 from public.jm_players where room_id = r.id and active and lower(name) = lower(v_name)) then
    raise exception 'Ce pseudo est déjà pris dans cette partie' using errcode = 'P0001';
  end if;
  insert into public.jm_players(room_id, name, seat)
  values (r.id, v_name, coalesce((select max(seat) + 1 from public.jm_players where room_id = r.id), 0))
  returning * into p;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'join', 'p', v_name));
  return jsonb_build_object('code', r.code, 'token', p.token, 'player_id', p.id);
end $$;

-- p_first : joueur qui commence (le plus jeune) ; null = tirage au sort
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

  v_deck := jm_private.shuffle(array(select id from public.jm_cards));
  for pl in select id from public.jm_players where room_id = r.id and active order by seat loop
    update public.jm_players set hand = v_deck[1:per] where id = pl.id;
    v_deck := v_deck[per + 1:];
  end loop;

  -- 1re carte de la défausse : une Commune. Une Spéciale retourne au milieu du paquet.
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
         log = '[]'::jsonb
   where id = r.id;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'start',
            'p', (select name from public.jm_players where room_id = r.id and seat = first_seat), 'n', per));
end $$;

create or replace function public.jm_play_card(p_token uuid, p_card text)
returns void language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
  v_kind text;
  left_cards int;
begin
  select * into r from public.jm_rooms where id = me.room_id for update;
  if r.status <> 'playing' then raise exception 'La partie n''est pas en cours' using errcode = 'P0001'; end if;
  if r.current_seat <> me.seat then raise exception 'Ce n''est pas ton tour' using errcode = 'P0001'; end if;
  select * into me from public.jm_players where id = me.id for update;
  if not (p_card = any(me.hand)) then raise exception 'Tu n''as pas cette carte' using errcode = 'P0001'; end if;
  if r.phase = 'drawn' and p_card <> r.drawn_card then
    raise exception 'Après avoir pioché, tu ne peux poser que la carte piochée' using errcode = 'P0001';
  end if;
  if not jm_private.is_playable(p_card, r) then
    raise exception 'Cette carte ne peut pas être posée' using errcode = 'P0001';
  end if;

  select c.kind into v_kind from public.jm_cards c where c.id = p_card;
  update public.jm_players set hand = array_remove(hand, p_card) where id = me.id
  returning cardinality(hand) into left_cards;

  if v_kind = 'special' then
    update public.jm_rooms set specials = specials || p_card where id = r.id;
  else
    update public.jm_rooms set discard = discard || p_card where id = r.id;
  end if;

  if left_cards = 0 then
    update public.jm_rooms set status = 'finished', winner_id = me.id, phase = 'play', drawn_card = null where id = r.id;
    perform jm_private.bump(r.id, jsonb_build_object('k', 'play', 'p', me.name, 'c', p_card));
    perform jm_private.bump(r.id, jsonb_build_object('k', 'win', 'p', me.name));
  else
    update public.jm_rooms
       set current_seat = jm_private.next_seat(r.id, me.seat), phase = 'play', drawn_card = null
     where id = r.id;
    perform jm_private.bump(r.id, jsonb_build_object('k', 'play', 'p', me.name, 'c', p_card, 'left', left_cards));
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
  if r.current_seat <> me.seat then raise exception 'Ce n''est pas ton tour' using errcode = 'P0001'; end if;
  if r.phase <> 'play' then raise exception 'Tu as déjà pioché ce tour-ci' using errcode = 'P0001'; end if;

  -- Pioche vide : on remélange les deux piles sauf leurs cartes du dessus.
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
    -- Règle de fluidité : la carte piochée peut être posée tout de suite.
    update public.jm_rooms set phase = 'drawn', drawn_card = c where id = r.id;
  else
    update public.jm_rooms set current_seat = jm_private.next_seat(r.id, me.seat), phase = 'play', drawn_card = null
     where id = r.id;
  end if;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'draw', 'p', me.name, 'playable', v_playable));
  return jsonb_build_object('card', c, 'playable', v_playable);
end $$;

-- Garder la carte piochée (jouable) et finir son tour.
create or replace function public.jm_pass(p_token uuid)
returns void language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
begin
  select * into r from public.jm_rooms where id = me.room_id for update;
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
    -- ses cartes retournent dans la pioche
    update public.jm_players set active = false, hand = '{}' where id = me.id;
    update public.jm_rooms set deck = jm_private.shuffle(deck || me.hand) where id = r.id;
    select count(*) into remaining from public.jm_players where room_id = r.id and active;
    if remaining < 2 then
      select * into last_one from public.jm_players where room_id = r.id and active limit 1;
      update public.jm_rooms set status = 'finished', winner_id = last_one.id where id = r.id;
    elsif r.current_seat = me.seat then
      update public.jm_rooms set current_seat = jm_private.next_seat(r.id, me.seat), phase = 'play', drawn_card = null where id = r.id;
    end if;
  else
    update public.jm_players set active = false, hand = '{}' where id = me.id;
  end if;

  if not exists (select 1 from public.jm_players where room_id = r.id and active) then
    update public.jm_rooms set status = 'finished' where id = r.id;  -- salon vide : abandonné
    return;
  end if;
  if r.host_id = me.id then
    update public.jm_rooms
       set host_id = (select id from public.jm_players where room_id = r.id and active order by seat limit 1)
     where id = r.id;
  end if;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'leave', 'p', me.name));
end $$;

-- Après une partie : l'hôte ramène tout le monde dans le salon.
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
         phase = 'play', drawn_card = null, winner_id = null, log = '[]'::jsonb
   where id = r.id;
  perform jm_private.bump(r.id, jsonb_build_object('k', 'lobby'));
end $$;

-- Vue d'un joueur : tout ce qui est public + sa propre main uniquement.
create or replace function public.jm_get_state(p_token uuid)
returns jsonb language plpgsql security definer set search_path = public, jm_private as $$
declare
  me public.jm_players := jm_private.me(p_token);
  r public.jm_rooms;
  my_turn boolean;
begin
  select * into r from public.jm_rooms where id = me.room_id;
  my_turn := r.status = 'playing' and r.current_seat = me.seat and me.active;
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

grant execute on function public.jm_create_room(text), public.jm_join_room(text, text),
  public.jm_start_game(uuid, uuid), public.jm_play_card(uuid, text), public.jm_draw_card(uuid),
  public.jm_pass(uuid), public.jm_leave_room(uuid), public.jm_back_to_lobby(uuid), public.jm_get_state(uuid)
  to anon, authenticated;

-- ---------- Catalogue des 80 cartes ----------
insert into public.jm_cards(id,kind,name,district,icons) values
('c-alle','commune','Alle','Porrentruy',array['train','industrie','agriculture']),
('c-basse-allaine','commune','Basse-Allaine','Porrentruy',array['train','eau','frontiere']),
('c-basse-vendline','commune','Basse-Vendline','Porrentruy',array['eau','frontiere','nature']),
('c-boncourt','commune','Boncourt','Porrentruy',array['train','frontiere','autoroute']),
('c-bure','commune','Bure','Porrentruy',array['autoroute','frontiere','agriculture']),
('c-clos-du-doubs','commune','Clos du Doubs','Porrentruy',array['eau','nature','patrimoine']),
('c-coeuve','commune','Cœuve','Porrentruy',array['eau','chateau','patrimoine']),
('c-cornol','commune','Cornol','Porrentruy',array['chateau','nature','patrimoine']),
('c-courchavon','commune','Courchavon','Porrentruy',array['train','eau','agriculture']),
('c-courgenay','commune','Courgenay','Porrentruy',array['train','autoroute','horlogerie']),
('c-courtedoux','commune','Courtedoux','Porrentruy',array['nature','patrimoine','sport']),
('c-damphreux-lugnez','commune','Damphreux-Lugnez','Porrentruy',array['nature','agriculture','frontiere']),
('c-fahy','commune','Fahy','Porrentruy',array['frontiere','industrie','agriculture']),
('c-fontenais','commune','Fontenais','Porrentruy',array['sport','energie','nature']),
('c-grandfontaine','commune','Grandfontaine','Porrentruy',array['frontiere','horlogerie','patrimoine']),
('c-haute-ajoie','commune','Haute-Ajoie','Porrentruy',array['frontiere','nature','patrimoine']),
('c-la-baroche','commune','La Baroche','Porrentruy',array['chateau','horlogerie','patrimoine']),
('c-porrentruy','commune','Porrentruy','Porrentruy',array['chateau','sante','horlogerie']),
('c-vendlincourt','commune','Vendlincourt','Porrentruy',array['train','industrie','horlogerie']),
('c-boecourt','commune','Boécourt','Delémont',array['autoroute','industrie','nature']),
('c-bourrignon','commune','Bourrignon','Delémont',array['agriculture','hiver','patrimoine']),
('c-chatillon','commune','Châtillon','Delémont',array['agriculture','nature','sport']),
('c-courchapoix','commune','Courchapoix','Delémont',array['eau','agriculture','nature']),
('c-courrendlin','commune','Courrendlin','Delémont',array['eau','industrie','autoroute']),
('c-courroux','commune','Courroux','Delémont',array['eau','industrie','patrimoine']),
('c-courtetelle','commune','Courtételle','Delémont',array['train','eau','industrie']),
('c-delemont','commune','Delémont','Delémont',array['chateau','sante','energie']),
('c-develier','commune','Develier','Delémont',array['autoroute','industrie','agriculture']),
('c-ederswiler','commune','Ederswiler','Delémont',array['agriculture','nature','patrimoine']),
('c-haute-sorne','commune','Haute-Sorne','Delémont',array['train','energie','horlogerie']),
('c-mervelier','commune','Mervelier','Delémont',array['eau','agriculture','nature']),
('c-mettembert','commune','Mettembert','Delémont',array['agriculture','nature','patrimoine']),
('c-movelier','commune','Movelier','Delémont',array['agriculture','nature','hiver']),
('c-pleigne','commune','Pleigne','Delémont',array['chateau','frontiere','patrimoine']),
('c-rossemaison','commune','Rossemaison','Delémont',array['sport','industrie','horlogerie']),
('c-saulcy','commune','Saulcy','Delémont',array['hiver','agriculture','nature']),
('c-soyhieres','commune','Soyhières','Delémont',array['chateau','eau','patrimoine']),
('c-val-terbi','commune','Val Terbi','Delémont',array['eau','industrie','nature']),
('c-lajoux','commune','Lajoux','Franches-Montagnes',array['hiver','horlogerie','industrie']),
('c-le-bemont','commune','Le Bémont','Franches-Montagnes',array['hiver','sport','train']),
('c-le-noirmont','commune','Le Noirmont','Franches-Montagnes',array['sante','horlogerie','energie']),
('c-les-bois','commune','Les Bois','Franches-Montagnes',array['horlogerie','frontiere','sport']),
('c-les-breuleux','commune','Les Breuleux','Franches-Montagnes',array['train','horlogerie','sport']),
('c-les-enfers','commune','Les Enfers','Franches-Montagnes',array['agriculture','hiver','nature']),
('c-les-genevez','commune','Les Genevez','Franches-Montagnes',array['agriculture','hiver','patrimoine']),
('c-montfaucon','commune','Montfaucon','Franches-Montagnes',array['hiver','sport','train']),
('c-muriaux','commune','Muriaux','Franches-Montagnes',array['chateau','hiver','train']),
('c-saignelegier','commune','Saignelégier','Franches-Montagnes',array['train','sport','horlogerie']),
('c-saint-brais','commune','Saint-Brais','Franches-Montagnes',array['hiver','agriculture','train']),
('c-soubey','commune','Soubey','Franches-Montagnes',array['eau','energie','frontiere']),
('c-moutier','commune','Moutier','Moutier',array['train','industrie','sante']),
('s-train-1','special','Interdiction : Train / transports publics',null,array['train']),
('s-train-2','special','Interdiction : Train / transports publics',null,array['train']),
('s-autoroute-1','special','Interdiction : Autoroute A16',null,array['autoroute']),
('s-autoroute-2','special','Interdiction : Autoroute A16',null,array['autoroute']),
('s-frontiere-1','special','Interdiction : Frontière',null,array['frontiere']),
('s-frontiere-2','special','Interdiction : Frontière',null,array['frontiere']),
('s-eau-1','special','Interdiction : Eau & rivières',null,array['eau']),
('s-eau-2','special','Interdiction : Eau & rivières',null,array['eau']),
('s-agriculture-1','special','Interdiction : Agriculture',null,array['agriculture']),
('s-agriculture-2','special','Interdiction : Agriculture',null,array['agriculture']),
('s-nature-1','special','Interdiction : Nature',null,array['nature']),
('s-nature-2','special','Interdiction : Nature',null,array['nature']),
('s-industrie-1','special','Interdiction : Industrie',null,array['industrie']),
('s-industrie-2','special','Interdiction : Industrie',null,array['industrie']),
('s-horlogerie-1','special','Interdiction : Horlogerie',null,array['horlogerie']),
('s-horlogerie-2','special','Interdiction : Horlogerie',null,array['horlogerie']),
('s-energie-1','special','Interdiction : Énergie',null,array['energie']),
('s-energie-2','special','Interdiction : Énergie',null,array['energie']),
('s-sante-1','special','Interdiction : Santé & hôpital',null,array['sante']),
('s-sante-2','special','Interdiction : Santé & hôpital',null,array['sante']),
('s-patrimoine-1','special','Interdiction : Patrimoine & musées',null,array['patrimoine']),
('s-patrimoine-2','special','Interdiction : Patrimoine & musées',null,array['patrimoine']),
('s-chateau-1','special','Interdiction : Château',null,array['chateau']),
('s-chateau-2','special','Interdiction : Château',null,array['chateau']),
('s-chateau-3','special','Interdiction : Château',null,array['chateau']),
('s-sport-1','special','Interdiction : Sport',null,array['sport']),
('s-sport-2','special','Interdiction : Sport',null,array['sport']),
('s-hiver-1','special','Interdiction : Hiver & neige',null,array['hiver']),
('s-hiver-2','special','Interdiction : Hiver & neige',null,array['hiver'])
on conflict (id) do update set kind = excluded.kind, name = excluded.name, district = excluded.district, icons = excluded.icons;

-- search_path figé pour les fonctions internes
alter function jm_private.shuffle(text[]) set search_path = public, jm_private;
alter function jm_private.new_code() set search_path = public, jm_private;
alter function jm_private.me(uuid) set search_path = public, jm_private;
alter function jm_private.bump(uuid, jsonb) set search_path = public, jm_private;
alter function jm_private.forbidden_icon(public.jm_rooms) set search_path = public, jm_private;
alter function jm_private.is_playable(text, public.jm_rooms) set search_path = public, jm_private;
alter function jm_private.next_seat(uuid, int) set search_path = public, jm_private;
