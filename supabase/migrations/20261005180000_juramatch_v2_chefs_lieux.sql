-- =====================================================================
-- JuraMatch v2 : nouvelles cartes (1 à 5 symboles) et règle des chefs-lieux
-- Quand une carte chef-lieu est posée, le joueur suivant pioche 3 cartes.
-- =====================================================================
alter table public.jm_cards add column if not exists chef_lieu boolean not null default false;

update public.jm_cards c set icons = v.icons, chef_lieu = v.chef
from (values
('c-alle',array['train','industrie','agriculture']::text[],false),
('c-basse-allaine',array['eau','frontiere']::text[],false),
('c-basse-vendline',array['eau','nature']::text[],false),
('c-boncourt',array['train','frontiere']::text[],false),
('c-bure',array['autoroute','agriculture']::text[],false),
('c-clos-du-doubs',array['eau','patrimoine']::text[],false),
('c-coeuve',array['chateau','patrimoine']::text[],false),
('c-cornol',array['nature','patrimoine']::text[],false),
('c-courchavon',array['train']::text[],false),
('c-courgenay',array['train','autoroute','horlogerie']::text[],false),
('c-courtedoux',array['nature','patrimoine']::text[],false),
('c-damphreux-lugnez',array['nature']::text[],false),
('c-fahy',array['frontiere']::text[],false),
('c-fontenais',array['sport','energie','nature']::text[],false),
('c-grandfontaine',array['horlogerie']::text[],false),
('c-haute-ajoie',array['frontiere','nature']::text[],false),
('c-la-baroche',array['chateau','horlogerie']::text[],false),
('c-porrentruy',array['chateau','sante','horlogerie','train','patrimoine']::text[],true),
('c-vendlincourt',array['train','horlogerie']::text[],false),
('c-boecourt',array['autoroute','industrie']::text[],false),
('c-bourrignon',array['hiver']::text[],false),
('c-chatillon',array['nature']::text[],false),
('c-courchapoix',array['eau']::text[],false),
('c-courrendlin',array['eau','industrie','autoroute']::text[],false),
('c-courroux',array['eau','industrie','patrimoine']::text[],false),
('c-courtetelle',array['train','eau','industrie']::text[],false),
('c-delemont',array['chateau','sante','energie','train','patrimoine']::text[],true),
('c-develier',array['autoroute','industrie']::text[],false),
('c-ederswiler',array['agriculture']::text[],false),
('c-haute-sorne',array['train','energie','horlogerie']::text[],false),
('c-mervelier',array['eau']::text[],false),
('c-mettembert',array['nature']::text[],false),
('c-movelier',array['hiver']::text[],false),
('c-pleigne',array['frontiere']::text[],false),
('c-rossemaison',array['sport','horlogerie']::text[],false),
('c-saulcy',array['hiver']::text[],false),
('c-soyhieres',array['chateau']::text[],false),
('c-val-terbi',array['eau','industrie','nature']::text[],false),
('c-lajoux',array['hiver','horlogerie']::text[],false),
('c-le-bemont',array['train']::text[],false),
('c-le-noirmont',array['sante','horlogerie','energie']::text[],false),
('c-les-bois',array['horlogerie','frontiere']::text[],false),
('c-les-breuleux',array['train','horlogerie','sport']::text[],false),
('c-les-enfers',array['hiver']::text[],false),
('c-les-genevez',array['patrimoine']::text[],false),
('c-montfaucon',array['hiver','train']::text[],false),
('c-muriaux',array['chateau']::text[],false),
('c-saignelegier',array['train','sport','horlogerie','hiver','patrimoine']::text[],true),
('c-saint-brais',array['train']::text[],false),
('c-soubey',array['eau']::text[],false),
('c-moutier',array['train','industrie','sante','eau','patrimoine']::text[],true)
) as v(id, icons, chef)
where c.id = v.id;

-- Pioche n cartes pour un joueur (remélange la défausse si besoin). Retourne le nombre pioché.
create or replace function jm_private.draw_n(p_room uuid, p_player uuid, p_n int)
returns int language plpgsql set search_path = public, jm_private as $$
declare
  r public.jm_rooms;
  pool text[];
  got int := 0;
  take int;
begin
  select * into r from public.jm_rooms where id = p_room;
  if cardinality(r.deck) < p_n then
    pool := coalesce(r.discard[1:cardinality(r.discard) - 1], '{}') || coalesce(r.specials[1:cardinality(r.specials) - 1], '{}');
    if cardinality(pool) > 0 then
      update public.jm_rooms
         set deck = deck || jm_private.shuffle(pool),
             discard = r.discard[cardinality(r.discard):cardinality(r.discard)],
             specials = case when cardinality(r.specials) > 0 then r.specials[cardinality(r.specials):cardinality(r.specials)] else '{}' end
       where id = p_room
      returning * into r;
      perform jm_private.bump(p_room, jsonb_build_object('k', 'reshuffle', 'n', cardinality(pool)));
    end if;
  end if;
  take := least(p_n, cardinality(r.deck));
  if take > 0 then
    update public.jm_players set hand = hand || r.deck[1:take] where id = p_player;
    update public.jm_rooms set deck = deck[take + 1:] where id = p_room;
    got := take;
  end if;
  return got;
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

  -- Chef-lieu : le joueur suivant pioche 3 cartes
  if v_card.chef_lieu then
    select * into victim from public.jm_players where room_id = r.id and seat = nxt;
    got := jm_private.draw_n(r.id, victim.id, 3);
    perform jm_private.bump(r.id, jsonb_build_object('k', 'penalty', 'p', victim.name, 'n', got, 'c', p_card));
  end if;
end $$;
