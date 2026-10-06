-- =====================================================================
-- JuraMatch v3 : 14 cartes Interdiction (une par symbole) + 9 cartes +2
-- Paquet : 51 communes + 23 spéciales = 74 cartes.
-- Les anciennes interdictions en double restent dans le catalogue (parties
-- en cours) mais ne sont plus mises dans le paquet (in_deck = false).
-- =====================================================================
alter table public.jm_cards add column if not exists in_deck boolean not null default true;
alter table public.jm_cards add column if not exists draw_next int not null default 0;

update public.jm_cards set in_deck = false where id ~ '^s-.*-[23]$' and id not like 's-plus2-%';
update public.jm_cards set draw_next = 3 where chef_lieu;

insert into public.jm_cards(id, kind, name, district, icons, in_deck, draw_next)
select 's-plus2-' || n, 'special', 'Carte +2', null, '{}'::text[], true, 2
from generate_series(1, 9) n
on conflict (id) do update set in_deck = true, draw_next = 2, kind = 'special', icons = '{}'::text[];

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
  v_card public.jm_cards;
  left_cards int;
  nxt int;
  victim public.jm_players;
  got int;
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

  select * into v_card from public.jm_cards c where c.id = p_card;
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

  -- Chef-lieu (+3) ou carte +2 : le joueur suivant pioche
  if v_card.draw_next > 0 then
    select * into victim from public.jm_players where room_id = r.id and seat = nxt;
    got := jm_private.draw_n(r.id, victim.id, v_card.draw_next);
    perform jm_private.bump(r.id, jsonb_build_object('k', 'penalty', 'p', victim.name, 'n', got, 'c', p_card));
  end if;
end $$;
