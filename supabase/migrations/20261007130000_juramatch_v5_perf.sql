-- =====================================================================
-- JuraMatch v5 : performance
-- 1. jm_act : une action + le nouvel état en UN seul appel réseau
-- 2. Le temps réel envoie directement l'état public de la partie
--    (les autres joueurs voient le coup sans relire le serveur)
-- =====================================================================

-- État visible par tous (sans les mains, sans la réponse aux questions)
create or replace function jm_private.public_state(r public.jm_rooms)
returns jsonb language sql stable set search_path = public, jm_private as $$
  select jsonb_build_object(
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
                  from public.jm_players p where p.room_id = r.id and (p.active or r.status = 'playing'))
  )
$$;

create or replace function jm_private.bump(p_room uuid, p_event jsonb)
returns void language plpgsql set search_path = public, jm_private as $$
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
    perform realtime.send(jm_private.public_state(r), 'update', 'juramatch:' || r.code, false);
  exception when others then
    null;
  end;
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
  return jm_private.public_state(r) || jsonb_build_object(
    'me', jsonb_build_object('id', me.id, 'name', me.name, 'seat', me.seat, 'hand', to_jsonb(me.hand), 'active', me.active),
    'drawn_card', case when my_turn then r.drawn_card end,
    'playable', case when my_turn then
        (select coalesce(jsonb_agg(h), '[]'::jsonb) from unnest(me.hand) h
          where jm_private.is_playable(h, r) and (r.phase = 'play' or h = r.drawn_card))
      else '[]'::jsonb end
  );
end $$;

-- Une action de jeu + l'état qui en résulte, en un seul aller-retour
create or replace function public.jm_act(p_token uuid, p_action text, p_card text default null,
                                         p_target uuid default null, p_choice int default null)
returns jsonb language plpgsql security definer set search_path = public, jm_private as $$
declare res jsonb;
begin
  case p_action
    when 'play' then perform public.jm_play_card(p_token, p_card);
    when 'draw' then res := public.jm_draw_card(p_token);
    when 'pass' then perform public.jm_pass(p_token);
    when 'question' then perform public.jm_play_question(p_token, p_card, p_target);
    when 'answer' then res := public.jm_answer_question(p_token, p_choice);
    when 'pick' then perform public.jm_question_pick(p_token, p_target);
    when 'start' then perform public.jm_start_game(p_token, p_target);
    when 'lobby' then perform public.jm_back_to_lobby(p_token);
    else raise exception 'Action inconnue' using errcode = 'P0001';
  end case;
  return jsonb_build_object('result', res, 'state', public.jm_get_state(p_token));
end $$;

grant execute on function public.jm_act(uuid, text, text, uuid, int) to anon, authenticated;
