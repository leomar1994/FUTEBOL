-- =====================================================================
-- TÉCNICO · LIGA ONLINE — cole tudo no Supabase (SQL Editor → New query → Run)
-- Pode rodar de novo sem problema: recria as funções e mantém os dados.
-- =====================================================================

create extension if not exists pg_cron;

-- ---------- tabelas ----------
create table if not exists public.liga_clubes (
  id text primary key, nome text not null, sigla text not null, cor text not null, cor2 text not null,
  forca numeric not null, div text not null check (div in ('A','B','C','D'))
);
create table if not exists public.liga_estado (
  id int primary key default 1 check (id = 1), temporada int not null default 2026, rodada int not null default 1,
  ultima_rodada timestamptz
);
create table if not exists public.liga_jogos (
  id bigserial primary key, temporada int not null, rodada int not null, div text not null,
  casa text not null references public.liga_clubes, fora text not null references public.liga_clubes,
  gc int, gf int, jogado boolean not null default false
);
create index if not exists liga_jogos_tr on public.liga_jogos (temporada, rodada);
-- turno: 1 = 12h00, 2 = 12h20 (Brasília). inicio/fim: quando o jogo começou e quando termina "ao vivo"
alter table public.liga_jogos add column if not exists turno int, add column if not exists inicio timestamptz, add column if not exists fim timestamptz;
create table if not exists public.liga_tecnicos (
  user_id uuid primary key references auth.users on delete cascade,
  nome text not null check (length(nome) between 1 and 30), nac text not null default '🇧🇷 Brasil',
  clube text unique references public.liga_clubes, ex_clube text, div text not null, nivel int not null,
  conf int not null default 60, demitido boolean not null default false,
  propostas jsonb not null default '[]', titulos jsonb not null default '[]', avisos jsonb not null default '[]',
  criado timestamptz not null default now()
);
create table if not exists public.liga_taticas (
  user_id uuid primary key references auth.users on delete cascade,
  formacao text not null default '4-3-3', estilo text not null default 'eq' check (estilo in ('eq','of','de')),
  atualizado timestamptz not null default now()
);
-- marcação (leve/normal/pesado/muito pesado) e lado das jogadas (meio/laterais/misto)
alter table public.liga_taticas add column if not exists marcacao text not null default 'normal', add column if not exists jogada text not null default 'misto';
alter table public.liga_taticas add column if not exists linha text not null default 'normal';   -- linha de defesa: normal | alta
do $$ begin alter table public.liga_taticas add constraint liga_taticas_marc check (marcacao in ('leve','normal','pesado','mpesado') and jogada in ('misto','meio','lados')); exception when others then null; end $$;
-- marcação mais pesada tira um pouco dos gols do rival (e dá mais cartões no jogo animado); leve dá um pouco mais
create or replace function public.liga_fator_marcacao(p_clube text) returns numeric language sql stable as $$
  select coalesce((select case x.marcacao when 'leve' then 1.04 when 'pesado' then 0.96 when 'mpesado' then 0.92 else 1 end
    from public.liga_tecnicos t join public.liga_taticas x using (user_id) where t.clube = p_clube), 1)
$$;

-- ---------- clubes (Séries A, B e C reais de 2026; Série D com clubes fictícios) ----------
insert into public.liga_clubes (id, nome, sigla, cor, cor2, forca, div) values
('a_cap','Athletico-PR','CAP','#c8102e','#111111',76.0,'A'),
('a_cam','Atlético-MG','CAM','#111111','#ffffff',77.0,'A'),
('a_bah','Bahia','BAH','#0a3c8c','#e30613',77.0,'A'),
('a_bot','Botafogo','BOT','#111111','#ffffff',78.0,'A'),
('a_cha','Chapecoense','CHA','#00843d','#ffffff',71.0,'A'),
('a_cor','Corinthians','COR','#ffffff','#111111',77.0,'A'),
('a_cfc','Coritiba','CFC','#006b3f','#ffffff',73.0,'A'),
('a_cru','Cruzeiro','CRU','#0033a0','#ffffff',78.0,'A'),
('a_fla','Flamengo','FLA','#c8102e','#111111',81.0,'A'),
('a_flu','Fluminense','FLU','#7a0a2a','#00613c',78.0,'A'),
('a_gre','Grêmio','GRE','#0d80bf','#111111',76.0,'A'),
('a_int','Internacional','INT','#e30613','#ffffff',77.0,'A'),
('a_mir','Mirassol','MIR','#ffd200','#00843d',74.0,'A'),
('a_pal','Palmeiras','PAL','#006437','#ffffff',81.0,'A'),
('a_rbb','Red Bull Bragantino','RBB','#ffffff','#e30613',75.0,'A'),
('a_rem','Remo','REM','#0a2240','#ffffff',72.0,'A'),
('a_san','Santos','SAN','#ffffff','#111111',75.0,'A'),
('a_sao','São Paulo','SAO','#ffffff','#e30613',77.0,'A'),
('a_vas','Vasco','VAS','#111111','#ffffff',75.0,'A'),
('a_vit','Vitória','VIT','#e30613','#111111',73.0,'A'),
('b_ame','América-MG','AME','#00843d','#111111',68.0,'B'),
('b_ath','Athletic','ATH','#111111','#ffffff',64.0,'B'),
('b_acg','Atlético-GO','ACG','#c8102e','#111111',68.0,'B'),
('b_ava','Avaí','AVA','#0057a8','#ffffff',66.0,'B'),
('b_bfs','Botafogo-SP','BFS','#e30613','#ffffff',65.0,'B'),
('b_cea','Ceará','CEA','#111111','#ffffff',69.0,'B'),
('b_crb','CRB','CRB','#e30613','#ffffff',66.0,'B'),
('b_cri','Criciúma','CRI','#ffd200','#111111',67.0,'B'),
('b_cui','Cuiabá','CUI','#00843d','#ffd200',67.0,'B'),
('b_for','Fortaleza','FOR','#0055a4','#e30613',69.0,'B'),
('b_goi','Goiás','GOI','#00843d','#ffffff',67.0,'B'),
('b_juv','Juventude','JUV','#007a33','#ffffff',67.0,'B'),
('b_lon','Londrina','LON','#00a3e0','#ffffff',65.0,'B'),
('b_nau','Náutico','NAU','#e30613','#ffffff',66.0,'B'),
('b_nov','Novorizontino','NOV','#ffd200','#111111',67.0,'B'),
('b_ope','Operário-PR','OPE','#111111','#ffffff',66.0,'B'),
('b_pon','Ponte Preta','PON','#ffffff','#111111',65.0,'B'),
('b_sbe','São Bernardo','SBE','#ffd200','#111111',65.0,'B'),
('b_spt','Sport','SPT','#e30613','#111111',69.0,'B'),
('b_vno','Vila Nova','VNO','#e30613','#ffffff',67.0,'B'),
('c_amz','Amazonas','AMZ','#ffd200','#111111',60.0,'C'),
('c_ana','Anápolis','ANA','#e30613','#ffffff',59.0,'C'),
('c_bar','Barra','BAR','#0057a8','#ffffff',59.0,'C'),
('c_bpb','Botafogo-PB','BPB','#111111','#ffffff',60.0,'C'),
('c_bru','Brusque','BRU','#ffd200','#00843d',60.0,'C'),
('c_cax','Caxias','CAX','#7a0a2a','#ffffff',60.0,'C'),
('c_con','Confiança','CON','#0057a8','#ffffff',60.0,'C'),
('c_fer','Ferroviária','FER','#7a0a2a','#ffffff',61.0,'C'),
('c_fig','Figueirense','FIG','#111111','#ffffff',61.0,'C'),
('c_flo','Floresta','FLO','#00843d','#ffffff',59.0,'C'),
('c_gua','Guarani','GUA','#007a33','#ffffff',61.0,'C'),
('c_inl','Inter de Limeira','INL','#111111','#ffffff',60.0,'C'),
('c_ita','Itabaiana','ITA','#0057a8','#ffffff',59.0,'C'),
('c_itu','Ituano','ITU','#e30613','#111111',60.0,'C'),
('c_mar','Maranhão','MAR','#e30613','#0057a8',59.0,'C'),
('c_mga','Maringá','MGA','#1d3c8f','#ffffff',61.0,'C'),
('c_pay','Paysandu','PAY','#00a3e0','#ffffff',62.0,'C'),
('c_stc','Santa Cruz','STC','#111111','#e30613',61.0,'C'),
('c_vre','Volta Redonda','VRE','#ffd200','#111111',60.0,'C'),
('c_ypi','Ypiranga-RS','YPI','#00843d','#ffd200',60.0,'C'),
('g_D_0','Cruzeiro do Cachoeira','CAC','#7a0a2a','#ffffff',54.9,'D'),
('g_D_1','Real Mirante','MIR','#e86a10','#ffd200',53.7,'D'),
('g_D_2','Real Campo Belo','CAM','#5b2a86','#00a3e0',54.7,'D'),
('g_D_3','Operário Ouro Fino','OUR','#ffd200','#e86a10',54.7,'D'),
('g_D_4','Ferroviário Itaúna','ITA','#c8102e','#e86a10',54.1,'D'),
('g_D_5','Independente Rio Claro','RIO','#c8102e','#ffffff',50.6,'D'),
('g_D_6','Esporte Clube Monte Verde','MON','#e86a10','#111111',52.0,'D'),
('g_D_7','Esporte Clube Barra Mansa','BAR','#00a3e0','#00843d',53.8,'D'),
('g_D_8','Ferroviário Alvorada','ALV','#0057a8','#00843d',52.5,'D'),
('g_D_9','Esporte Clube Lagoa Seca','LAG','#0057a8','#00843d',52.2,'D'),
('g_D_10','Sport Club Bela Vista','BEL','#e86a10','#ffffff',54.6,'D'),
('g_D_11','Independente Juruá','JUR','#111111','#ffd200',55.6,'D'),
('g_D_12','União Serra Alta','SER','#00a3e0','#ffffff',53.7,'D'),
('g_D_13','Associação Três Rios','TRÊ','#ffd200','#ffffff',51.9,'D'),
('g_D_14','Sport Club São Lucas','SÃO','#00843d','#e86a10',49.5,'D'),
('g_D_15','Operário Vale do Sol','VAL','#111111','#ffffff',51.0,'D'),
('g_D_16','Esporte Clube Santa Rita','SAN','#00843d','#5b2a86',52.0,'D'),
('g_D_17','Associação Água Limpa','ÁGU','#0057a8','#c8102e',50.6,'D'),
('g_D_18','Associação Caiçara','CAI','#5b2a86','#00a3e0',56.4,'D'),
('g_D_19','Associação Porto Novo','POR','#e86a10','#ffffff',55.4,'D')
on conflict (id) do nothing;
insert into public.liga_estado (id) values (1) on conflict (id) do nothing;

-- ---------- classificação (calculada a partir dos jogos) ----------
create or replace view public.liga_classificacao with (security_invoker = true) as
select c.id as clube, c.div,
  coalesce(sum(case when (j.casa = c.id and j.gc > j.gf) or (j.fora = c.id and j.gf > j.gc) then 3 when j.gc = j.gf then 1 else 0 end), 0)::int as p,
  count(j.id)::int as j,
  coalesce(sum(case when (j.casa = c.id and j.gc > j.gf) or (j.fora = c.id and j.gf > j.gc) then 1 else 0 end), 0)::int as v,
  coalesce(sum(case when j.gc = j.gf then 1 else 0 end), 0)::int as e,
  coalesce(sum(case when (j.casa = c.id and j.gc < j.gf) or (j.fora = c.id and j.gf < j.gc) then 1 else 0 end), 0)::int as d,
  coalesce(sum(case when j.casa = c.id then j.gc else j.gf end), 0)::int as gp,
  coalesce(sum(case when j.casa = c.id then j.gf else j.gc end), 0)::int as gcontra
from public.liga_clubes c
left join public.liga_jogos j on j.jogado and (j.casa = c.id or j.fora = c.id)
  and (j.fim is null or j.fim <= now() or current_user not in ('anon', 'authenticated'))   -- jogo ao vivo só conta na tabela quando termina
  and j.temporada = (select temporada from public.liga_estado where id = 1) and j.div = c.div
group by c.id, c.div;

create or replace function public.liga_posicao(p_clube text) returns int language sql stable as $$
  select pos from (
    select clube, row_number() over (order by p desc, v desc, (gp - gcontra) desc, gp desc, clube) as pos
    from public.liga_classificacao where div = (select div from public.liga_clubes where id = p_clube)
  ) x where clube = p_clube;
$$;

-- ---------- calendário (turno e returno, método do círculo) ----------
-- metade dos jogos de cada divisão/rodada no 1º turno (12h00), a outra metade no 2º (12h20)
create or replace function public.liga_definir_turnos(p_temporada int) returns void language sql security definer set search_path = public as $$
  update liga_jogos j set turno = x.t from (
    select id, case when row_number() over (partition by rodada, div order by id) <= ceil(count(*) over (partition by rodada, div) / 2.0) then 1 else 2 end as t
    from liga_jogos where temporada = p_temporada) x
  where x.id = j.id and j.turno is distinct from x.t;
$$;
create or replace function public.liga_gerar_calendario(p_temporada int) returns void language plpgsql security definer set search_path = public as $$
declare v_div text; ids text[]; n int; r int; i int; a text; b text; t text;
begin
  delete from liga_jogos where temporada = p_temporada and not jogado;
  foreach v_div in array array['A','B','C','D'] loop
    select array_agg(id order by random()) into ids from liga_clubes where div = v_div;
    if ids is null then continue; end if;
    if array_length(ids, 1) % 2 = 1 then ids := ids || array[null::text]; end if;
    n := array_length(ids, 1);
    for r in 0 .. n - 2 loop
      for i in 1 .. n / 2 loop
        a := ids[i]; b := ids[n - i + 1];
        if a is not null and b is not null then
          if r % 2 = 1 then t := a; a := b; b := t; end if;
          insert into liga_jogos (temporada, rodada, div, casa, fora) values (p_temporada, r + 1, v_div, a, b), (p_temporada, r + n, v_div, b, a);
        end if;
      end loop;
      ids := array[ids[1]] || array[ids[n]] || ids[2:n-1];   -- gira todos menos o primeiro
    end loop;
  end loop;
  perform liga_definir_turnos(p_temporada);
end $$;

-- ---------- sorteio de gols ----------
create or replace function public.liga_poisson(l numeric) returns int language plpgsql volatile as $$
declare k int := 0; p numeric := exp(-l); s numeric := exp(-l); u numeric := random();
begin
  while u > s and k < 9 loop k := k + 1; p := p * l / k; s := s + p; end loop;
  return k;
end $$;

-- ---------- propostas: só da divisão do nível do técnico ou abaixo ----------
create or replace function public.liga_gerar_propostas(p_user uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare tec liga_tecnicos; res jsonb;
begin
  select * into tec from liga_tecnicos where user_id = p_user;
  select coalesce(jsonb_agg(jsonb_build_object('clube', id, 'div', div)), '[]') into res from (
    select c.id, c.div from liga_clubes c
    where position(c.div in 'ABCD') - 1 >= tec.nivel
      and c.id is distinct from tec.ex_clube
      and not exists (select 1 from liga_tecnicos t where t.clube = c.id)
      and liga_posicao(c.id) >= 13
    order by (position(c.div in 'ABCD') - 1 - tec.nivel) + random() * 2.5
    limit 3) x;
  return res;
end $$;

-- ---------- entrar na liga: clube sorteado de uma divisão sorteada ----------
create or replace function public.liga_entrar(p_nome text, p_nac text) returns public.liga_tecnicos language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); tec liga_tecnicos; c liga_clubes;
begin
  if uid is null then raise exception 'Faça login primeiro.'; end if;
  select * into tec from liga_tecnicos where user_id = uid;
  if found then return tec; end if;
  select * into c from liga_clubes x where not exists (select 1 from liga_tecnicos t where t.clube = x.id)
    order by random() limit 1;   -- divisão e clube sorteados
  if c.id is null then raise exception 'Todos os clubes já têm técnico.'; end if;
  insert into liga_tecnicos (user_id, nome, nac, clube, div, nivel, avisos)
  values (uid, left(trim(p_nome), 30), left(coalesce(p_nac, '🇧🇷 Brasil'), 30), c.id, c.div, position(c.div in 'ABCD') - 1,
          jsonb_build_array('Bem-vindo! Você assumiu o ' || c.nome || ' (Série ' || c.div || ').'))
  returning * into tec;
  insert into liga_taticas (user_id) values (uid) on conflict do nothing;
  return tec;
end $$;

-- ---------- aceitar proposta ----------
create or replace function public.liga_aceitar(p_clube text) returns public.liga_tecnicos language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); tec liga_tecnicos; c liga_clubes;
begin
  select * into tec from liga_tecnicos where user_id = uid for update;
  if not found or not tec.demitido then raise exception 'Você não está sem clube.'; end if;
  if not tec.propostas @> jsonb_build_array(jsonb_build_object('clube', p_clube)) then
    if not exists (select 1 from jsonb_array_elements(tec.propostas) e where e->>'clube' = p_clube) then raise exception 'Essa proposta não existe.'; end if;
  end if;
  if exists (select 1 from liga_tecnicos t where t.clube = p_clube) then raise exception 'Outro técnico já assumiu esse clube.'; end if;
  select * into c from liga_clubes where id = p_clube;
  update liga_tecnicos set clube = c.id, div = c.div, demitido = false, propostas = '[]', conf = 55,
    avisos = jsonb_build_array('Você assinou com o ' || c.nome || '.') where user_id = uid returning * into tec;
  return tec;
end $$;

-- ---------- a rodada (todo dia ao meio-dia de Brasília, em dois turnos: 12h00 e 12h20) ----------
create or replace function public.liga_rodar_turno(p_turno int) returns text language plpgsql security definer set search_path = public as $$
declare est liga_estado; j record; fc numeric; ff numeric; ec text; ef text; lc numeric; lf numeric; v_gc int; v_gf int;
        tec record; pos int; meta int; saldo int; nconf int; total int; ranking int;
begin
  select * into est from liga_estado where id = 1 for update;
  if not exists (select 1 from liga_jogos where temporada = est.temporada) then perform liga_gerar_calendario(est.temporada); end if;
  perform liga_definir_turnos(est.temporada);
  -- 1º turno: só os jogos do turno 1. 2º turno: todos os que faltam (se o 1º falhou, nada fica para trás)
  for j in select * from liga_jogos where temporada = est.temporada and rodada = est.rodada and not jogado and (p_turno >= 2 or coalesce(turno, 1) = 1) loop
    select forca into fc from liga_clubes where id = j.casa; select forca into ff from liga_clubes where id = j.fora;
    select coalesce(t2.estilo, 'eq') into ec from liga_tecnicos t1 left join liga_taticas t2 using (user_id) where t1.clube = j.casa;
    select coalesce(t2.estilo, 'eq') into ef from liga_tecnicos t1 left join liga_taticas t2 using (user_id) where t1.clube = j.fora;
    lc := 1.3 * exp(((fc + 2.5) - ff) / 22); lf := 1.3 * exp((ff - (fc + 2.5)) / 22);
    if ec = 'of' then lc := lc * 1.15; lf := lf * 1.12; elsif ec = 'de' then lc := lc * 0.85; lf := lf * 0.82; end if;
    if ef = 'of' then lf := lf * 1.15; lc := lc * 1.12; elsif ef = 'de' then lf := lf * 0.85; lc := lc * 0.82; end if;
    lc := lc * liga_fator_marcacao(j.fora); lf := lf * liga_fator_marcacao(j.casa);
    v_gc := liga_poisson(lc); v_gf := liga_poisson(lf);
    update liga_jogos set gc = v_gc, gf = v_gf, jogado = true, inicio = now(), fim = now() + interval '16 minutes' where id = j.id;
  end loop;
  if p_turno < 2 then return 'Turno 1 da rodada ' || est.rodada || ' começou.'; end if;
  -- bilheteria e torcida de cada jogo da rodada; obras de estádio que terminam
  perform liga_bilheteria(x.id) from liga_jogos x where x.temporada = est.temporada and x.rodada = est.rodada and x.publico is null;
  update liga_clubes set capacidade = least(100000, capacidade + 5000), obra_ate = null where obra_ate is not null and obra_ate <= est.rodada;
  -- cota de TV da rodada entra no caixa de cada clube; a folha salarial sai
  update liga_clubes c set caixa = round(coalesce(caixa, 0) + case c.div when 'A' then 1.5 when 'B' then 0.6 when 'C' then 0.25 else 0.12 end
    - coalesce((select sum(jg.salario) from liga_jogadores jg where jg.clube = c.id), 0), 2);
  -- diretoria de cada técnico humano
  for tec in select t.*, g.casa, g.fora, g.gc, g.gf from liga_tecnicos t
             join liga_jogos g on g.temporada = est.temporada and g.rodada = est.rodada and (g.casa = t.clube or g.fora = t.clube)
             where not t.demitido loop
    pos := liga_posicao(tec.clube);
    select count(*) + 1 into ranking from liga_clubes x where x.div = tec.div and x.forca > (select forca from liga_clubes where id = tec.clube);
    meta := case when ranking <= 4 then 4 when ranking <= 12 then 10 else 16 end;
    saldo := case when tec.casa = tec.clube then tec.gc - tec.gf else tec.gf - tec.gc end;
    update liga_tecnicos set tokens = tokens + case when saldo > 0 then 2 when saldo = 0 then 1 else 0 end where user_id = tec.user_id;   -- tokens do leilão
    nconf := tec.conf + case when saldo > 0 then 4 when saldo = 0 then (case when pos <= meta then 1 else -1 end) else -5 end;
    if est.rodada >= 6 then nconf := nconf + case when pos <= meta then 1 when pos > meta + 4 then -3 else -1 end; end if;
    nconf := greatest(0, least(100, nconf));
    if nconf <= 15 and est.rodada >= 7 then
      update liga_tecnicos set demitido = true, ex_clube = clube, clube = null, conf = 50,
        avisos = jsonb_build_array('Você foi demitido do ' || (select nome from liga_clubes where id = tec.clube) || '.') where user_id = tec.user_id;
      update liga_tecnicos set propostas = liga_gerar_propostas(user_id) where user_id = tec.user_id;
    else
      update liga_tecnicos set conf = nconf,
        avisos = case when nconf <= 30 then jsonb_build_array('A diretoria está insatisfeita (confiança ' || nconf || '%).') else '[]' end
      where user_id = tec.user_id;
    end if;
  end loop;
  update liga_tecnicos set propostas = liga_gerar_propostas(user_id) where demitido and propostas = '[]' and random() < 0.6;
  select max(rodada) into total from liga_jogos where temporada = est.temporada;
  if est.rodada >= total then perform liga_fim_temporada(); else update liga_estado set rodada = rodada + 1, ultima_rodada = now() where id = 1; end if;
  return 'Rodada ' || est.rodada || ' da temporada ' || est.temporada || ' jogada.';
end $$;
-- joga a rodada inteira de uma vez (útil para testar)
create or replace function public.liga_rodar_rodada() returns text language plpgsql security definer set search_path = public as $$
begin perform liga_rodar_turno(1); return liga_rodar_turno(2); end $$;

-- ---------- fim de temporada: 4 sobem e 4 caem entre cada divisão ----------
create or replace function public.liga_fim_temporada() returns void language plpgsql security definer set search_path = public as $$
declare est liga_estado; v_div text; prox text; ant text; campeao text;
begin
  select * into est from liga_estado where id = 1;
  create temp table if not exists _mov (clube text, para text) on commit drop; delete from _mov;
  foreach v_div in array array['A','B','C','D'] loop
    prox := case v_div when 'A' then 'B' when 'B' then 'C' when 'C' then 'D' end;
    ant := case v_div when 'B' then 'A' when 'C' then 'B' when 'D' then 'C' end;
    select clube into campeao from liga_classificacao where div = v_div order by p desc, v desc, (gp - gcontra) desc, gp desc limit 1;
    update liga_tecnicos set titulos = titulos || jsonb_build_array('Série ' || v_div || ' ' || est.temporada) where clube = campeao;
    if ant is not null then insert into _mov select clube, ant from liga_classificacao where div = v_div order by p desc, v desc, (gp - gcontra) desc, gp desc limit 4; end if;
    if prox is not null then insert into _mov select clube, prox from liga_classificacao where div = v_div order by p asc, v asc, (gp - gcontra) asc, gp asc limit 4; end if;
  end loop;
  update liga_clubes c set div = m.para from _mov m where m.clube = c.id;
  update liga_tecnicos t set div = c.div, nivel = least(t.nivel, position(c.div in 'ABCD') - 1),
    avisos = jsonb_build_array('Fim da temporada ' || est.temporada || '. Seu clube agora está na Série ' || c.div || '.')
    from liga_clubes c where c.id = t.clube;
  update liga_estado set temporada = temporada + 1, rodada = 1, ultima_rodada = now() where id = 1;
  perform liga_temporada_jogadores(est.temporada);
  perform liga_gerar_calendario(est.temporada + 1);
end $$;

-- ---------- segurança (RLS) ----------
alter table public.liga_clubes enable row level security;
alter table public.liga_estado enable row level security;
alter table public.liga_jogos enable row level security;
alter table public.liga_tecnicos enable row level security;
alter table public.liga_taticas enable row level security;
drop policy if exists ler on public.liga_clubes;   create policy ler on public.liga_clubes for select using (true);
drop policy if exists ler on public.liga_estado;   create policy ler on public.liga_estado for select using (true);
drop policy if exists ler on public.liga_jogos;    create policy ler on public.liga_jogos for select using (true);
drop policy if exists ler on public.liga_tecnicos; create policy ler on public.liga_tecnicos for select using (true);
drop policy if exists minha on public.liga_taticas; create policy minha on public.liga_taticas for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select on public.liga_clubes, public.liga_estado, public.liga_jogos, public.liga_tecnicos, public.liga_classificacao to anon, authenticated;
grant select, insert, update on public.liga_taticas to authenticated;
revoke all on function public.liga_rodar_turno(int), public.liga_definir_turnos(int), public.liga_rodar_rodada(), public.liga_fim_temporada(), public.liga_gerar_calendario(int), public.liga_gerar_propostas(uuid) from public, anon, authenticated;
grant execute on function public.liga_entrar(text, text), public.liga_aceitar(text) to authenticated;
grant execute on function public.liga_posicao(text), public.liga_poisson(numeric), public.liga_fator_marcacao(text) to anon, authenticated;

-- ---------- primeiro calendário e relógio das rodadas ----------
do $$ begin
  if not exists (select 1 from public.liga_jogos) then perform public.liga_gerar_calendario((select temporada from public.liga_estado where id = 1)); end if;
end $$;
do $$ begin perform cron.unschedule('liga-rodada-diaria'); exception when others then null; end $$;
do $$ begin perform cron.unschedule('liga-turno-1'); exception when others then null; end $$;
do $$ begin perform cron.unschedule('liga-turno-2'); exception when others then null; end $$;
-- rodada todo dia ao meio-dia de Brasília (15h UTC): metade dos jogos às 12h00, a outra metade às 12h20
select cron.schedule('liga-turno-1', '0 15 * * *', $$select public.liga_rodar_turno(1)$$);
select cron.schedule('liga-turno-2', '20 15 * * *', $$select public.liga_rodar_turno(2)$$);

do $$ begin perform public.liga_definir_turnos((select temporada from public.liga_estado where id = 1)); end $$;

-- ---------- amistosos entre técnicos (não valem nada: nem tabela, nem tokens, nem diretoria) ----------
create table if not exists public.liga_amistosos (
  id bigserial primary key,
  desafiante uuid not null references auth.users on delete cascade, desafiado uuid not null references auth.users on delete cascade,
  casa text not null references public.liga_clubes, fora text not null references public.liga_clubes,
  quando timestamptz not null, status text not null default 'pendente' check (status in ('pendente','aceito','recusado','cancelado','jogado')),
  gc int, gf int, inicio timestamptz, fim timestamptz, criado timestamptz not null default now()
);
create index if not exists liga_amistosos_quando on public.liga_amistosos (status, quando);

create or replace function public.liga_desafiar(p_adversario uuid, p_quando timestamptz) returns public.liga_amistosos language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); eu liga_tecnicos; ele liga_tecnicos; a liga_amistosos;
begin
  select * into eu from liga_tecnicos where user_id = uid;
  select * into ele from liga_tecnicos where user_id = p_adversario;
  if eu.clube is null then raise exception 'Você precisa estar num clube para marcar amistoso.'; end if;
  if ele.clube is null then raise exception 'Esse técnico está sem clube.'; end if;
  if p_adversario = uid then raise exception 'Escolha outro técnico.'; end if;
  if p_quando < now() + interval '5 minutes' then raise exception 'Marque com pelo menos 5 minutos de antecedência.'; end if;
  if p_quando > now() + interval '7 days' then raise exception 'Marque para no máximo 7 dias à frente.'; end if;
  if (select count(*) from liga_amistosos where desafiante = uid and status in ('pendente','aceito')) >= 3 then raise exception 'Você já tem 3 amistosos marcados ou esperando resposta.'; end if;
  if liga_conflito(uid, p_quando) is not null then raise exception '%', liga_conflito(uid, p_quando); end if;
  if liga_conflito(p_adversario, p_quando) is not null then raise exception 'O outro técnico já tem compromisso nesse horário (ou é a hora da rodada). Escolha outro.'; end if;
  insert into liga_amistosos (desafiante, desafiado, casa, fora, quando) values (uid, p_adversario, eu.clube, ele.clube, date_trunc('minute', p_quando)) returning * into a;
  return a;
end $$;

create or replace function public.liga_responder_amistoso(p_id bigint, p_aceitar boolean) returns public.liga_amistosos language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); a liga_amistosos;
begin
  select * into a from liga_amistosos where id = p_id for update;
  if a.id is null then raise exception 'Amistoso não encontrado.'; end if;
  if p_aceitar then
    if a.desafiado <> uid then raise exception 'Só o técnico convidado pode aceitar.'; end if;
    if a.status <> 'pendente' then raise exception 'Esse convite não está mais aberto.'; end if;
    if a.quando <= now() then raise exception 'O horário desse amistoso já passou.'; end if;
    update liga_amistosos set status = 'recusado' where id = p_id;   -- tira este convite da conta para checar os outros compromissos
    if liga_conflito(uid, a.quando) is not null then update liga_amistosos set status = 'pendente' where id = p_id; raise exception '%', liga_conflito(uid, a.quando); end if;
    update liga_amistosos set status = 'aceito' where id = p_id returning * into a;
  else                                            -- recusar (convidado) ou cancelar (qualquer um dos dois) antes do jogo
    if uid not in (a.desafiante, a.desafiado) then raise exception 'Esse amistoso não é seu.'; end if;
    if a.status not in ('pendente','aceito') or a.quando <= now() then raise exception 'Não dá mais para cancelar.'; end if;
    update liga_amistosos set status = case when uid = a.desafiado and a.status = 'pendente' then 'recusado' else 'cancelado' end where id = p_id returning * into a;
  end if;
  return a;
end $$;

-- roda a cada minuto: amistosos aceitos cujo horário chegou ganham placar; o "ao vivo" começa no horário marcado
create or replace function public.liga_amistosos_rodar() returns int language plpgsql security definer set search_path = public as $$
declare a record; fc numeric; ff numeric; ec text; ef text; lc numeric; lf numeric; n int := 0;
begin
  update liga_amistosos set status = 'cancelado' where status = 'pendente' and quando <= now();
  for a in select * from liga_amistosos where status = 'aceito' and quando <= now() for update skip locked loop
    select forca into fc from liga_clubes where id = a.casa; select forca into ff from liga_clubes where id = a.fora;
    select coalesce(estilo, 'eq') into ec from liga_taticas where user_id = a.desafiante;
    select coalesce(estilo, 'eq') into ef from liga_taticas where user_id = a.desafiado;
    lc := 1.3 * exp(((fc + 2.5) - ff) / 22); lf := 1.3 * exp((ff - (fc + 2.5)) / 22);
    if ec = 'of' then lc := lc * 1.15; lf := lf * 1.12; elsif ec = 'de' then lc := lc * 0.85; lf := lf * 0.82; end if;
    if ef = 'of' then lf := lf * 1.15; lc := lc * 1.12; elsif ef = 'de' then lf := lf * 0.85; lc := lc * 0.82; end if;
    lc := lc * liga_fator_marcacao(a.fora); lf := lf * liga_fator_marcacao(a.casa);
    update liga_amistosos set gc = liga_poisson(lc), gf = liga_poisson(lf), status = 'jogado', inicio = a.quando, fim = a.quando + interval '16 minutes' where id = a.id;
    n := n + 1;
  end loop;
  return n;
end $$;

alter table public.liga_amistosos enable row level security;
drop policy if exists ler on public.liga_amistosos; create policy ler on public.liga_amistosos for select using (true);
grant select on public.liga_amistosos to anon, authenticated;
revoke all on function public.liga_amistosos_rodar() from public, anon, authenticated;
revoke all on function public.liga_desafiar(uuid, timestamptz), public.liga_responder_amistoso(bigint, boolean) from public, anon;
grant execute on function public.liga_desafiar(uuid, timestamptz), public.liga_responder_amistoso(bigint, boolean) to authenticated;
do $$ begin perform cron.unschedule('liga-amistosos'); exception when others then null; end $$;
select cron.schedule('liga-amistosos', '* * * * *', $$select public.liga_amistosos_rodar()$$);

-- ---------- dinheiro do clube na liga online (R$ milhões) ----------
alter table public.liga_clubes add column if not exists caixa numeric;
update public.liga_clubes set caixa = case div when 'A' then 40 when 'B' then 12 when 'C' then 4 else 1.5 end where caixa is null;

-- ---------- torneios criados pelos técnicos (inscrição em dinheiro do jogo; pote dividido entre os primeiros) ----------
create table if not exists public.liga_torneios (
  id bigserial primary key, nome text not null check (length(nome) between 3 and 40), criador uuid not null references auth.users on delete cascade,
  formato text not null check (formato in ('mata','pontos')), vagas int not null, taxa numeric not null default 0 check (taxa >= 0),
  premio int[] not null, inicio timestamptz not null, intervalo int not null, robos boolean not null default true,
  status text not null default 'inscricoes' check (status in ('inscricoes','andamento','encerrado','cancelado')),
  pote numeric not null default 0, fase int not null default 0, campeao text, criado timestamptz not null default now()
);
create table if not exists public.liga_torneio_inscritos (
  torneio bigint not null references public.liga_torneios on delete cascade, clube text not null references public.liga_clubes,
  user_id uuid references auth.users on delete set null, pago numeric not null default 0, posicao int, premio numeric,
  primary key (torneio, clube)
);
create unique index if not exists liga_torneio_um_por_tecnico on public.liga_torneio_inscritos (torneio, user_id) where user_id is not null;
create table if not exists public.liga_torneio_jogos (
  id bigserial primary key, torneio bigint not null references public.liga_torneios on delete cascade, rodada int not null,
  casa text not null, fora text not null, quando timestamptz not null,
  gc int, gf int, pc int, pf int, jogado boolean not null default false, inicio timestamptz, fim timestamptz
);
create index if not exists liga_torneio_jogos_t on public.liga_torneio_jogos (torneio, rodada);
alter table public.liga_torneio_jogos add column if not exists terceiro boolean not null default false;   -- disputa de 3º lugar no mata-mata

create or replace function public.liga_torneio_cancelar(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
begin
  update liga_clubes c set caixa = coalesce(c.caixa, 0) + i.pago from liga_torneio_inscritos i where i.torneio = p_id and i.clube = c.id and i.pago > 0;
  update liga_torneio_inscritos set pago = 0 where torneio = p_id;
  update liga_torneios set status = 'cancelado', pote = 0 where id = p_id;
end $$;

create or replace function public.liga_inscrever_torneio(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); eu liga_tecnicos; t liga_torneios; c liga_clubes;
begin
  select * into t from liga_torneios where id = p_id for update;
  if t.id is null or t.status <> 'inscricoes' or t.inicio <= now() then raise exception 'As inscrições desse torneio estão fechadas.'; end if;
  select * into eu from liga_tecnicos where user_id = uid;
  if eu.clube is null then raise exception 'Você precisa estar num clube para jogar torneios.'; end if;
  if exists (select 1 from liga_torneio_inscritos where torneio = p_id and (user_id = uid or clube = eu.clube)) then raise exception 'Você já está inscrito nesse torneio.'; end if;
  if (select count(*) from liga_torneio_inscritos where torneio = p_id) >= t.vagas then raise exception 'O torneio está lotado.'; end if;
  declare msg text; begin
    select liga_conflito(uid, s, p_id) into msg from liga_torneio_slots(p_id) s where liga_conflito(uid, s, p_id) is not null limit 1;
    if msg is not null then raise exception 'Uma rodada desse torneio choca com sua agenda. %', msg; end if;
  end;
  select * into c from liga_clubes where id = eu.clube for update;
  if coalesce(c.caixa, 0) < t.taxa then raise exception 'Seu clube não tem dinheiro para pagar a inscrição.'; end if;
  update liga_clubes set caixa = coalesce(caixa, 0) - t.taxa where id = c.id;
  insert into liga_torneio_inscritos (torneio, clube, user_id, pago) values (p_id, c.id, uid, t.taxa);
  update liga_torneios set pote = pote + t.taxa where id = p_id;
end $$;

create or replace function public.liga_criar_torneio(p_nome text, p_formato text, p_vagas int, p_taxa numeric, p_premio int[], p_inicio timestamptz, p_intervalo int, p_robos boolean)
returns bigint language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); eu liga_tecnicos; tid bigint;
begin
  select * into eu from liga_tecnicos where user_id = uid;
  if eu.clube is null then raise exception 'Você precisa estar num clube para criar torneios.'; end if;
  if length(trim(coalesce(p_nome, ''))) < 3 then raise exception 'Dê um nome ao torneio (pelo menos 3 letras).'; end if;
  if p_formato = 'mata' and p_vagas not in (4, 8, 16, 32) then raise exception 'Mata-mata: até 4, 8, 16 ou 32 clubes.'; end if;
  if p_formato = 'pontos' and (p_vagas < 4 or p_vagas > 16 or p_vagas % 2 = 1) then raise exception 'Liga amistosa: até 4 a 16 clubes (número par).'; end if;
  if p_formato not in ('mata', 'pontos') then raise exception 'Formato inválido.'; end if;
  if p_taxa is null or p_taxa < 0 or p_taxa > 50 then raise exception 'A inscrição deve ser entre R$ 0 e R$ 50 mi.'; end if;
  if p_premio is null or array_length(p_premio, 1) > least(4, p_vagas) or (select sum(x) from unnest(p_premio) x) <> 100
     or exists (select 1 from unnest(p_premio) x where x <= 0) then raise exception 'A divisão do prêmio precisa somar 100%%.'; end if;
  if p_inicio < now() + interval '10 minutes' or p_inicio > now() + interval '14 days' then raise exception 'O início deve ser entre 10 minutos e 14 dias a partir de agora.'; end if;
  if p_intervalo < 20 or p_intervalo > 2880 then raise exception 'O intervalo entre rodadas deve ser de 20 minutos a 2 dias.'; end if;
  if (select count(*) from liga_torneios where criador = uid and status in ('inscricoes', 'andamento')) >= 2 then raise exception 'Você já tem 2 torneios abertos.'; end if;
  insert into liga_torneios (nome, criador, formato, vagas, taxa, premio, inicio, intervalo, robos)
  values (left(trim(p_nome), 40), uid, p_formato, p_vagas, round(p_taxa, 3), p_premio, date_trunc('minute', p_inicio), p_intervalo, coalesce(p_robos, true)) returning id into tid;
  perform liga_inscrever_torneio(tid);
  return tid;
end $$;

create or replace function public.liga_sair_torneio(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); t liga_torneios; i liga_torneio_inscritos;
begin
  select * into t from liga_torneios where id = p_id for update;
  if t.id is null or t.status <> 'inscricoes' or t.inicio <= now() then raise exception 'Não dá mais para sair: o torneio já começou.'; end if;
  if t.criador = uid then perform liga_torneio_cancelar(p_id); return; end if;   -- o criador saindo cancela o torneio e devolve tudo
  select * into i from liga_torneio_inscritos where torneio = p_id and user_id = uid;
  if i.clube is null then raise exception 'Você não está inscrito.'; end if;
  update liga_clubes set caixa = coalesce(caixa, 0) + i.pago where id = i.clube;
  delete from liga_torneio_inscritos where torneio = p_id and clube = i.clube;
  update liga_torneios set pote = pote - i.pago where id = p_id;
end $$;

-- divide o pote: posições empatadas dividem as fatias que ocupam. Robô entre os premiados leva a parte dele.
create or replace function public.liga_torneio_premiar(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare t liga_torneios; g record; v numeric;
begin
  select * into t from liga_torneios where id = p_id;
  for g in select posicao, count(*) c from liga_torneio_inscritos where torneio = p_id and posicao is not null group by posicao loop
    select coalesce(sum(t.premio[x]), 0) into v from generate_series(g.posicao, g.posicao + g.c - 1) x where x <= array_length(t.premio, 1);
    update liga_torneio_inscritos set premio = round(t.pote * v / 100 / g.c, 3) where torneio = p_id and posicao = g.posicao;
  end loop;
  update liga_clubes c set caixa = coalesce(c.caixa, 0) + i.premio
    from liga_torneio_inscritos i left join liga_tecnicos tt on tt.user_id = i.user_id
    where i.torneio = p_id and i.premio > 0 and c.id = coalesce(tt.clube, i.clube);   -- robô premiado fica com a parte dele (vai para o caixa do clube robô)
  update liga_tecnicos set titulos = titulos || jsonb_build_array('Torneio ' || t.nome)
    where user_id = (select user_id from liga_torneio_inscritos where torneio = p_id and posicao = 1);
  update liga_torneios set status = 'encerrado', campeao = (select clube from liga_torneio_inscritos where torneio = p_id and posicao = 1) where id = p_id;
end $$;

-- roda a cada minuto: começa torneios, sorteia placares no horário e avança as fases (só depois do fim do "ao vivo")
create or replace function public.liga_torneios_rodar() returns void language plpgsql security definer set search_path = public as $$
declare t record; g record; n int; k int; ids text[]; vivos text[]; r int; i int; a text; b text; tmp text;
        fc numeric; ff numeric; ec text; ef text; lc numeric; lf numeric; v_gc int; v_gf int; v_pc int; v_pf int;
begin
  for t in select * from liga_torneios where status = 'inscricoes' and inicio <= now() for update skip locked loop
    select count(*) filter (where user_id is not null), count(*) into n, k from liga_torneio_inscritos where torneio = t.id;
    -- o tamanho depende de quantos técnicos entraram: o menor formato que cabe todos (o resto é robô), até o máximo escolhido
    t.vagas := least(t.vagas, case when t.formato = 'mata' then (select min(x) from unnest(array[4, 8, 16, 32]) x where x >= k) else greatest(4, k + k % 2) end);
    update liga_torneios set vagas = t.vagas where id = t.id;
    if n < 2 or (k < t.vagas and not t.robos) then perform liga_torneio_cancelar(t.id); continue; end if;
    if k < t.vagas then
      insert into liga_torneio_inscritos (torneio, clube)
      select t.id, c.id from liga_clubes c
      where not exists (select 1 from liga_torneio_inscritos x where x.torneio = t.id and x.clube = c.id)
        and not exists (select 1 from liga_tecnicos h where h.clube = c.id)
      order by abs(c.forca - (select avg(c2.forca) from liga_clubes c2 join liga_torneio_inscritos x2 on x2.clube = c2.id and x2.torneio = t.id)) + random() * 6
      limit t.vagas - k;
    end if;
    select array_agg(clube order by random()) into ids from liga_torneio_inscritos where torneio = t.id;
    if t.formato = 'mata' then
      for i in 0 .. t.vagas / 2 - 1 loop insert into liga_torneio_jogos (torneio, rodada, casa, fora, quando) values (t.id, 1, ids[2 * i + 1], ids[2 * i + 2], t.inicio); end loop;
    else
      for r in 0 .. t.vagas - 2 loop
        for i in 1 .. t.vagas / 2 loop
          a := ids[i]; b := ids[t.vagas - i + 1]; if r % 2 = 1 then tmp := a; a := b; b := tmp; end if;
          insert into liga_torneio_jogos (torneio, rodada, casa, fora, quando) values (t.id, r + 1, a, b, t.inicio + make_interval(mins => r * t.intervalo));
        end loop;
        ids := array[ids[1]] || array[ids[t.vagas]] || ids[2:t.vagas - 1];
      end loop;
    end if;
    update liga_torneios set status = 'andamento', fase = 1, pote = round(pote * 1.2, 3) where id = t.id;   -- o jogo põe +20% no pote das inscrições
  end loop;

  for g in select j.*, tt.formato from liga_torneio_jogos j join liga_torneios tt on tt.id = j.torneio where not j.jogado and j.quando <= now() for update of j skip locked loop
    select forca into fc from liga_clubes where id = g.casa; select forca into ff from liga_clubes where id = g.fora;
    select coalesce(t2.estilo, 'eq') into ec from liga_tecnicos t1 left join liga_taticas t2 using (user_id) where t1.clube = g.casa;
    select coalesce(t2.estilo, 'eq') into ef from liga_tecnicos t1 left join liga_taticas t2 using (user_id) where t1.clube = g.fora;
    lc := 1.3 * exp(((fc + 1) - ff) / 22); lf := 1.3 * exp((ff - (fc + 1)) / 22);
    if ec = 'of' then lc := lc * 1.15; lf := lf * 1.12; elsif ec = 'de' then lc := lc * 0.85; lf := lf * 0.82; end if;
    if ef = 'of' then lf := lf * 1.15; lc := lc * 1.12; elsif ef = 'de' then lf := lf * 0.85; lc := lc * 0.82; end if;
    lc := lc * liga_fator_marcacao(g.fora); lf := lf * liga_fator_marcacao(g.casa);
    v_gc := liga_poisson(lc); v_gf := liga_poisson(lf); v_pc := null; v_pf := null;
    if g.formato = 'mata' and v_gc = v_gf then v_pc := 3 + floor(random() * 3); v_pf := case when random() < .5 then v_pc - 1 - floor(random() * 2) else v_pc + 1 end; end if;
    update liga_torneio_jogos set gc = v_gc, gf = v_gf, pc = v_pc, pf = v_pf, jogado = true, inicio = g.quando, fim = g.quando + interval '16 minutes' where id = g.id;
  end loop;

  for t in select * from liga_torneios where status = 'andamento' for update skip locked loop
    if exists (select 1 from liga_torneio_jogos where torneio = t.id and (not jogado or fim > now())) then continue; end if;
    if t.formato = 'mata' then
      select array_agg(case when gc > gf or (gc = gf and pc > pf) then casa else fora end order by id) into vivos from liga_torneio_jogos where torneio = t.id and rodada = t.fase and not terceiro;
      if array_length(vivos, 1) > 1 then
        for i in 0 .. array_length(vivos, 1) / 2 - 1 loop
          insert into liga_torneio_jogos (torneio, rodada, casa, fora, quando)
          values (t.id, t.fase + 1, vivos[2 * i + 1], vivos[2 * i + 2], greatest((select max(quando) from liga_torneio_jogos where torneio = t.id) + make_interval(mins => t.intervalo), now() + interval '2 minutes'));
        end loop;
        if array_length(vivos, 1) = 2 then            -- junto com a final: disputa de 3º lugar entre os que caíram na semifinal
          insert into liga_torneio_jogos (torneio, rodada, casa, fora, quando, terceiro)
          select t.id, t.fase + 1, perd[1], perd[2], (select max(quando) from liga_torneio_jogos where torneio = t.id), true
          from (select array_agg(case when gc > gf or (gc = gf and pc > pf) then fora else casa end order by id) as perd from liga_torneio_jogos where torneio = t.id and rodada = t.fase and not terceiro) x;
        end if;
        update liga_torneios set fase = fase + 1 where id = t.id;
        continue;
      end if;
      update liga_torneio_inscritos set posicao = 1 where torneio = t.id and clube = vivos[1];
      update liga_torneio_inscritos set posicao = 2 where torneio = t.id and clube in (select case when gc > gf or (gc = gf and pc > pf) then fora else casa end from liga_torneio_jogos where torneio = t.id and rodada = t.fase and not terceiro);
      update liga_torneio_inscritos set posicao = 3 where torneio = t.id and clube in (select case when gc > gf or (gc = gf and pc > pf) then casa else fora end from liga_torneio_jogos where torneio = t.id and rodada = t.fase and terceiro);
      update liga_torneio_inscritos set posicao = 4 where torneio = t.id and clube in (select case when gc > gf or (gc = gf and pc > pf) then fora else casa end from liga_torneio_jogos where torneio = t.id and rodada = t.fase and terceiro);
    else
      update liga_torneio_inscritos i set posicao = o.pos from (
        select clube, row_number() over (order by sum(p) desc, sum(sg) desc, sum(gp) desc, random()) as pos from (
          select casa as clube, case when gc > gf then 3 when gc = gf then 1 else 0 end as p, gc - gf as sg, gc as gp from liga_torneio_jogos where torneio = t.id
          union all select fora, case when gf > gc then 3 when gc = gf then 1 else 0 end, gf - gc, gf from liga_torneio_jogos where torneio = t.id) x group by clube) o
      where i.torneio = t.id and i.clube = o.clube;
    end if;
    perform liga_torneio_premiar(t.id);
  end loop;
end $$;

alter table public.liga_torneios enable row level security;
alter table public.liga_torneio_inscritos enable row level security;
alter table public.liga_torneio_jogos enable row level security;
drop policy if exists ler on public.liga_torneios; create policy ler on public.liga_torneios for select using (true);
drop policy if exists ler on public.liga_torneio_inscritos; create policy ler on public.liga_torneio_inscritos for select using (true);
drop policy if exists ler on public.liga_torneio_jogos; create policy ler on public.liga_torneio_jogos for select using (true);
grant select on public.liga_torneios, public.liga_torneio_inscritos, public.liga_torneio_jogos to anon, authenticated;
revoke all on function public.liga_torneios_rodar(), public.liga_torneio_premiar(bigint), public.liga_torneio_cancelar(bigint) from public, anon, authenticated;
revoke all on function public.liga_criar_torneio(text, text, int, numeric, int[], timestamptz, int, boolean), public.liga_inscrever_torneio(bigint), public.liga_sair_torneio(bigint) from public, anon;
grant execute on function public.liga_criar_torneio(text, text, int, numeric, int[], timestamptz, int, boolean), public.liga_inscrever_torneio(bigint), public.liga_sair_torneio(bigint) to authenticated;
do $$ begin perform cron.unschedule('liga-torneios'); exception when others then null; end $$;
select cron.schedule('liga-torneios', '* * * * *', $$select public.liga_torneios_rodar()$$);

-- =====================================================================
-- JOGADORES, CONTRATOS, SALÁRIOS, TOKENS E LEILÃO (liga online)
-- =====================================================================
create table if not exists public.liga_jogadores (
  id bigserial primary key, clube text references public.liga_clubes, nome text not null, pos text not null,
  forca int not null, idade int not null, salario numeric not null, contrato_ate int not null
);
create index if not exists liga_jogadores_clube on public.liga_jogadores (clube);
alter table public.liga_tecnicos add column if not exists tokens int not null default 0;
create table if not exists public.liga_leiloes (
  id bigserial primary key, jogador bigint not null references public.liga_jogadores on delete cascade,
  vendedor uuid references auth.users on delete set null, origem text, motivo text not null default 'venda' check (motivo in ('venda','contrato')),
  status text not null default 'aberto' check (status in ('aberto','vendido','sem_lances')),
  fim timestamptz not null, ultimo uuid references auth.users on delete set null, ultimo_clube text, lances int not null default 0,
  destino text, criado timestamptz not null default now()
);
create unique index if not exists liga_leilao_um_por_jogador on public.liga_leiloes (jogador) where status = 'aberto';
create table if not exists public.liga_lances (
  id bigserial primary key, leilao bigint not null references public.liga_leiloes on delete cascade, user_id uuid, clube text, quando timestamptz not null default now()
);

-- valor de mercado e salário por rodada (R$ milhões), iguais aos da carreira
create or replace function public.liga_valor(f int, i int) returns numeric language sql immutable as $$
  select round(0.3 * power(1.13, f - 50) * case when i <= 21 then 1.4 when i <= 27 then 1.2 when i <= 30 then 1 when i <= 33 then 0.6 else 0.3 end, 2)
$$;
create or replace function public.liga_salario(f int, i int) returns numeric language sql immutable as $$ select round(public.liga_valor(f, i) * 0.007, 4) $$;

create or replace function public.liga_nome() returns text language sql volatile as $$
  select (array['Lucas','Gabriel','Matheus','João','Pedro','Rafael','Bruno','Felipe','Thiago','Diego','Caio','Vitor','Igor','Renan','Wesley','Alan','Douglas','Jean','Kaique','Luan','Murilo','Nathan','Otávio','Ruan','Sandro','Tiago','Yuri','Everton','Fábio','Hugo','Davi','Enzo','Henrique','Leandro','Marcos','Paulo','Rodrigo','Samuel','Vinícius','Arthur'])[1 + floor(random() * 40)::int]
    || ' ' || (array['Silva','Santos','Oliveira','Souza','Lima','Pereira','Costa','Ferreira','Almeida','Ribeiro','Carvalho','Gomes','Martins','Rocha','Barbosa','Araújo','Dias','Moreira','Nunes','Teixeira','Cardoso','Mendes','Freitas','Pinto','Vieira','Ramos','Batista','Campos','Monteiro','Correia'])[1 + floor(random() * 30)::int]
$$;
create or replace function public.liga_novo_jogador(p_clube text, p_pos text, p_forca int, p_idade int, p_ate int) returns void language sql volatile as $$
  insert into public.liga_jogadores (clube, nome, pos, forca, idade, salario, contrato_ate)
  values (p_clube, public.liga_nome(), p_pos, greatest(38, least(94, p_forca)), p_idade, public.liga_salario(greatest(38, least(94, p_forca)), p_idade), p_ate)
$$;
create or replace function public.liga_recalcular_forca(p_clube text) returns void language sql volatile security definer set search_path = public as $$
  update liga_clubes set forca = coalesce((select round(avg(forca), 1) from (select forca from liga_jogadores where clube = p_clube order by forca desc limit 11) x
    having count(*) >= 11), forca) where id = p_clube
$$;
-- elenco de 24 para cada clube que ainda não tem jogadores (em volta da força atual do clube)
create or replace function public.liga_gerar_elencos() returns void language plpgsql security definer set search_path = public as $$
declare c record; k int; temp int; pos text[] := array['GOL','GOL','GOL','ZAG','ZAG','ZAG','ZAG','LD','LD','LE','LE','VOL','VOL','MC','MC','MC','MEI','MEI','MEI','PE','PD','CA','CA','CA'];
begin
  select temporada into temp from liga_estado where id = 1;
  for c in select * from liga_clubes x where not exists (select 1 from liga_jogadores j where j.clube = x.id) loop
    for k in 1 .. 24 loop
      perform liga_novo_jogador(c.id, pos[k], round(c.forca - 2 + random() * 10 - 5 + case when k in (1,4,5,8,10,12,14,17,20,22,23) then 3 else -2 end)::int,
        18 + floor(random() * 16)::int, temp + floor(random() * 3)::int);
    end loop;
    perform liga_recalcular_forca(c.id);
  end loop;
end $$;

-- colocar jogador no leilão (sai do elenco na hora; se ninguém der lance, volta)
create or replace function public.liga_leiloar(p_jogador bigint) returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); eu liga_tecnicos; j liga_jogadores;
begin
  select * into eu from liga_tecnicos where user_id = uid;
  select * into j from liga_jogadores where id = p_jogador for update;
  if eu.clube is null or j.clube is distinct from eu.clube then raise exception 'Esse jogador não é do seu clube.'; end if;
  if (select count(*) from liga_jogadores where clube = eu.clube) <= 16 then raise exception 'O elenco não pode ficar com menos de 16 jogadores.'; end if;
  if (select count(*) from liga_leiloes where vendedor = uid and status = 'aberto') >= 3 then raise exception 'Você já tem 3 jogadores no leilão.'; end if;
  insert into liga_leiloes (jogador, vendedor, origem, motivo, fim) values (j.id, uid, eu.clube, 'venda', now() + interval '24 hours');
  update liga_jogadores set clube = null where id = j.id;
  perform liga_recalcular_forca(eu.clube);
end $$;

-- lance: custa 1 token e reinicia o cronômetro (12 h). Quem der o último lance quando o tempo acabar leva o jogador.
create or replace function public.liga_lance(p_leilao bigint) returns public.liga_leiloes language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); eu liga_tecnicos; l liga_leiloes;
begin
  select * into l from liga_leiloes where id = p_leilao for update;
  select * into eu from liga_tecnicos where user_id = uid for update;
  if l.id is null or l.status <> 'aberto' or l.fim <= now() then raise exception 'Esse leilão já terminou.'; end if;
  if eu.clube is null then raise exception 'Você precisa estar num clube para dar lance.'; end if;
  if l.vendedor = uid then raise exception 'Você não pode dar lance no seu próprio jogador.'; end if;
  if l.ultimo = uid then raise exception 'O último lance já é seu.'; end if;
  if eu.tokens < 1 then raise exception 'Você não tem tokens. Ganhe jogos da liga: vitória dá 2, empate dá 1.'; end if;
  if (select count(*) from liga_jogadores where clube = eu.clube) >= 35 then raise exception 'Seu elenco já tem 35 jogadores.'; end if;
  update liga_tecnicos set tokens = tokens - 1 where user_id = uid;
  insert into liga_lances (leilao, user_id, clube) values (l.id, uid, eu.clube);
  update liga_leiloes set lances = lances + 1, ultimo = uid, ultimo_clube = eu.clube, fim = now() + interval '12 hours' where id = l.id returning * into l;
  return l;
end $$;

-- renovar contrato antes de vencer: paga luvas (15% do valor por ano) e o salário sobe 10%
create or replace function public.liga_renovar(p_jogador bigint, p_anos int) returns void language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); eu liga_tecnicos; j liga_jogadores; temp int; luvas numeric;
begin
  select * into eu from liga_tecnicos where user_id = uid;
  select * into j from liga_jogadores where id = p_jogador for update;
  select temporada into temp from liga_estado where id = 1;
  if eu.clube is null or j.clube is distinct from eu.clube then raise exception 'Esse jogador não é do seu clube.'; end if;
  if p_anos not between 1 and 3 then raise exception 'Renove por 1, 2 ou 3 temporadas.'; end if;
  if j.contrato_ate >= temp + 2 then raise exception 'O contrato dele ainda é longo.'; end if;
  luvas := round(liga_valor(j.forca, j.idade) * 0.15 * p_anos, 2);
  if (select coalesce(caixa, 0) from liga_clubes where id = eu.clube) < luvas then raise exception 'Seu clube não tem dinheiro para as luvas.'; end if;
  update liga_clubes set caixa = caixa - luvas where id = eu.clube;
  update liga_jogadores set contrato_ate = greatest(contrato_ate, temp) + p_anos, salario = round(salario * 1.1, 4) where id = j.id;
end $$;

-- fecha leilões vencidos (roda a cada minuto)
create or replace function public.liga_leiloes_rodar() returns void language plpgsql security definer set search_path = public as $$
declare l record; dest text; temp int;
begin
  select temporada into temp from liga_estado where id = 1;
  for l in select * from liga_leiloes where status = 'aberto' and fim <= now() for update skip locked loop
    dest := null;
    if l.lances > 0 then
      select clube into dest from liga_tecnicos where user_id = l.ultimo;
      dest := coalesce(dest, l.ultimo_clube);
      if (select count(*) from liga_jogadores where clube = dest) >= 35 then dest := null; end if;
    end if;
    if dest is not null then
      update liga_jogadores set clube = dest, contrato_ate = temp + 2 where id = l.jogador;
      update liga_tecnicos set tokens = tokens + l.lances / 2 where user_id = l.vendedor;     -- vendedor fica com 50% dos tokens gastos
      update liga_leiloes set status = 'vendido', destino = dest where id = l.id;
    else
      dest := case when l.motivo = 'venda' and l.origem is not null and (select count(*) from liga_jogadores where clube = l.origem) < 35 then l.origem
                   else (select c.id from liga_clubes c where not exists (select 1 from liga_tecnicos t where t.clube = c.id)
                         and (select count(*) from liga_jogadores j where j.clube = c.id) < 30 order by random() limit 1) end;
      update liga_jogadores set clube = dest, contrato_ate = greatest(contrato_ate, temp + 1) where id = l.jogador;
      update liga_leiloes set status = 'sem_lances', destino = dest where id = l.id;
    end if;
    if dest is not null then perform liga_recalcular_forca(dest); end if;
  end loop;
end $$;

-- fim de temporada dos jogadores: envelhecem, contratos vencidos vão ao leilão, elencos curtos recebem jovens da base
create or replace function public.liga_temporada_jogadores(p_velha int) returns void language plpgsql security definer set search_path = public as $$
declare j record; c record; k int;
begin
  update liga_jogadores set forca = greatest(38, least(94, forca + case when idade < 23 then 2 when idade < 28 then 1 when idade > 32 then -2 else 0 end)), idade = idade + 1;
  update liga_jogadores set salario = liga_salario(forca, idade) where salario < liga_salario(forca, idade) * 0.8;
  -- vencidos de clubes com técnico humano: leilão. Dos clubes robô, os 8 melhores vencidos também vão; o resto renova.
  for j in select x.* from liga_jogadores x where x.contrato_ate <= p_velha and x.clube is not null
           and (exists (select 1 from liga_tecnicos t where t.clube = x.clube)
                or x.id in (select y.id from liga_jogadores y where y.contrato_ate <= p_velha and not exists (select 1 from liga_tecnicos t where t.clube = y.clube) order by y.forca desc limit 8)) loop
    insert into liga_leiloes (jogador, vendedor, origem, motivo, fim) values (j.id, null, j.clube, 'contrato', now() + interval '24 hours');
    update liga_jogadores set clube = null where id = j.id;
  end loop;
  update liga_jogadores set contrato_ate = p_velha + 1 + floor(random() * 3)::int where contrato_ate <= p_velha and clube is not null;
  for c in select x.id, x.forca, (select count(*) from liga_jogadores jg where jg.clube = x.id) n from liga_clubes x loop
    for k in c.n + 1 .. 18 loop
      perform liga_novo_jogador(c.id, (array['GOL','ZAG','LD','LE','VOL','MC','MEI','PE','PD','CA'])[1 + floor(random() * 10)::int], round(c.forca - 10 + random() * 6)::int, 17 + floor(random() * 3)::int, p_velha + 3);
    end loop;
  end loop;
  for c in select id from liga_clubes loop perform liga_recalcular_forca(c.id); end loop;
end $$;

alter table public.liga_jogadores enable row level security;
alter table public.liga_leiloes enable row level security;
alter table public.liga_lances enable row level security;
drop policy if exists ler on public.liga_jogadores; create policy ler on public.liga_jogadores for select using (true);
drop policy if exists ler on public.liga_leiloes; create policy ler on public.liga_leiloes for select using (true);
drop policy if exists ler on public.liga_lances; create policy ler on public.liga_lances for select using (true);
grant select on public.liga_jogadores, public.liga_leiloes, public.liga_lances to anon, authenticated;
revoke all on function public.liga_gerar_elencos(), public.liga_leiloes_rodar(), public.liga_temporada_jogadores(int), public.liga_recalcular_forca(text), public.liga_novo_jogador(text, text, int, int, int) from public, anon, authenticated;
revoke all on function public.liga_leiloar(bigint), public.liga_lance(bigint), public.liga_renovar(bigint, int) from public, anon;
grant execute on function public.liga_leiloar(bigint), public.liga_lance(bigint), public.liga_renovar(bigint, int) to authenticated;
do $$ begin perform cron.unschedule('liga-leiloes'); exception when others then null; end $$;
select cron.schedule('liga-leiloes', '* * * * *', $$select public.liga_leiloes_rodar()$$);
select public.liga_gerar_elencos();

-- =====================================================================
-- ESTÁDIO, TORCIDA E BILHETERIA (liga online)
-- público = capacidade × ocupação (torcida e preço); renda = público × preço; ampliar custa tokens (obra de 3 rodadas)
-- =====================================================================
alter table public.liga_clubes add column if not exists capacidade int, add column if not exists preco int, add column if not exists torcida int not null default 60,
  add column if not exists ampliacoes int not null default 0, add column if not exists obra_ate int;
update public.liga_clubes c set capacidade = round((case div when 'A' then 42000 when 'B' then 22000 when 'C' then 12000 else 6000 end)
  * (0.75 + (forca - (select min(forca) from public.liga_clubes x where x.div = c.div)) / greatest(1, (select max(forca) - min(forca) from public.liga_clubes x where x.div = c.div)) * 0.55) / 500) * 500
  where capacidade is null;
update public.liga_clubes set preco = case div when 'A' then 60 when 'B' then 40 when 'C' then 25 else 15 end where preco is null;
alter table public.liga_jogos add column if not exists publico int, add column if not exists renda numeric;

create or replace function public.liga_preco_base(p_div text) returns int language sql immutable as $$ select case p_div when 'A' then 60 when 'B' then 40 when 'C' then 25 else 15 end $$;

-- bilheteria e torcida de um jogo já decidido (chamada pela rodada)
create or replace function public.liga_bilheteria(p_jogo bigint) returns void language plpgsql security definer set search_path = public as $$
declare g liga_jogos; c liga_clubes; r numeric; ocup numeric; pub int; ren numeric;
begin
  select * into g from liga_jogos where id = p_jogo;
  select * into c from liga_clubes where id = g.casa for update;
  r := c.preco::numeric / liga_preco_base(c.div);
  ocup := least(1, greatest(0.06, (0.22 + 0.62 * c.torcida / 100.0) * power(1 / r, case when r > 1 then 1.35 else 0.45 end) * (0.94 + random() * 0.12)));
  pub := least(c.capacidade, round(c.capacidade * ocup)::int);
  ren := round(pub * c.preco / 1e6, 2);
  update liga_jogos set publico = pub, renda = ren where id = g.id;
  update liga_clubes set caixa = coalesce(caixa, 0) + ren,
    torcida = greatest(0, torcida - case when r > 1.4 then 1 else 0 end) where id = c.id;
  update liga_clubes x set torcida = least(100, greatest(0, x.torcida + case
      when (x.id = g.casa and g.gc > g.gf) or (x.id = g.fora and g.gf > g.gc) then case when abs(g.gc - g.gf) >= 3 then 5 else 3 end
      when g.gc = g.gf then -1 else -4 end))
    where x.id in (g.casa, g.fora);
end $$;

-- ampliar o estádio: +5.000 lugares, custa tokens (10, 16, 22…), obra pronta em 3 rodadas
create or replace function public.liga_ampliar_estadio() returns int language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); eu liga_tecnicos; c liga_clubes; custo int; rod int;
begin
  select * into eu from liga_tecnicos where user_id = uid for update;
  if eu.clube is null then raise exception 'Você precisa estar num clube.'; end if;
  select * into c from liga_clubes where id = eu.clube for update;
  if c.obra_ate is not null then raise exception 'Já tem uma obra em andamento.'; end if;
  if c.capacidade >= 100000 then raise exception 'O estádio já está no tamanho máximo.'; end if;
  custo := 10 + 6 * c.ampliacoes;
  if eu.tokens < custo then raise exception 'Faltam tokens: precisa de %, você tem %.', custo, eu.tokens; end if;
  select rodada into rod from liga_estado where id = 1;
  update liga_tecnicos set tokens = tokens - custo where user_id = uid;
  update liga_clubes set ampliacoes = ampliacoes + 1, obra_ate = rod + 3 where id = c.id;
  return custo;
end $$;

create or replace function public.liga_definir_preco(p_preco int) returns void language plpgsql security definer set search_path = public as $$
declare eu liga_tecnicos;
begin
  select * into eu from liga_tecnicos where user_id = auth.uid();
  if eu.clube is null then raise exception 'Você precisa estar num clube.'; end if;
  if p_preco not between 5 and 500 then raise exception 'Escolha um preço entre R$ 5 e R$ 500.'; end if;
  update liga_clubes set preco = p_preco where id = eu.clube;
end $$;

revoke all on function public.liga_bilheteria(bigint) from public, anon, authenticated;
revoke all on function public.liga_ampliar_estadio(), public.liga_definir_preco(int) from public, anon;
grant execute on function public.liga_ampliar_estadio(), public.liga_definir_preco(int) to authenticated;

-- =====================================================================
-- AGENDA E CONFLITO DE HORÁRIOS (amistosos e torneios não podem bater com a rodada da liga nem entre si)
-- =====================================================================
create or replace function public.liga_torneio_slots(p_id bigint) returns setof timestamptz language sql stable as $$
  select t.inicio + make_interval(mins => k * t.intervalo)
  from public.liga_torneios t, generate_series(0, (case when t.formato = 'mata' then round(log(2, t.vagas))::int else t.vagas - 1 end) - 1) k
  where t.id = p_id
$$;
-- compromissos de um técnico: amistosos marcados/pendentes e rodadas dos torneios em que está inscrito
create or replace function public.liga_compromissos(p_user uuid, p_exceto_torneio bigint default null) returns table (quando timestamptz, oque text)
language sql stable security definer set search_path = public as $$
  select a.quando, 'Amistoso ' || (select nome from liga_clubes where id = a.casa) || ' × ' || (select nome from liga_clubes where id = a.fora)
    from liga_amistosos a where p_user in (a.desafiante, a.desafiado) and a.status in ('pendente', 'aceito') and a.quando > now() - interval '20 minutes'
  union all
  select s, 'Torneio ' || t.nome
    from liga_torneios t join liga_torneio_inscritos i on i.torneio = t.id and i.user_id = p_user, liga_torneio_slots(t.id) s
    where t.status = 'inscricoes' and t.id is distinct from p_exceto_torneio
  union all
  select g.quando, 'Torneio ' || t.nome
    from liga_torneios t join liga_torneio_inscritos i on i.torneio = t.id and i.user_id = p_user join liga_torneio_jogos g on g.torneio = t.id and i.clube in (g.casa, g.fora)
    where t.status = 'andamento' and not g.jogado and t.id is distinct from p_exceto_torneio
$$;
-- devolve o motivo do conflito (ou null se o horário estiver livre)
create or replace function public.liga_conflito(p_user uuid, p_quando timestamptz, p_exceto_torneio bigint default null) returns text
language plpgsql stable security definer set search_path = public as $$
declare h time := (p_quando at time zone 'America/Sao_Paulo')::time; c record;
begin
  if h >= time '11:40' and h <= time '12:40' then return 'O horário bate com a rodada da liga (todo dia, 12h00–12h40). Escolha outro.'; end if;
  select * into c from liga_compromissos(p_user, p_exceto_torneio) x where abs(extract(epoch from x.quando - p_quando)) < 20 * 60 order by x.quando limit 1;
  if found then return 'Choca com outro jogo já marcado: ' || c.oque || ' às ' || to_char(c.quando at time zone 'America/Sao_Paulo', 'DD/MM HH24:MI') || '. Os jogos precisam ter pelo menos 20 minutos de diferença.'; end if;
  return null;
end $$;
create or replace function public.liga_minha_agenda() returns table (quando timestamptz, oque text) language sql stable security definer set search_path = public as $$
  select * from public.liga_compromissos(auth.uid()) order by 1
$$;
revoke all on function public.liga_compromissos(uuid, bigint), public.liga_conflito(uuid, timestamptz, bigint) from public, anon, authenticated;
grant execute on function public.liga_minha_agenda(), public.liga_torneio_slots(bigint) to authenticated;

-- Para testar sem esperar: select public.liga_rodar_turno(1);  (e 20 min depois, ou na hora: select public.liga_rodar_turno(2);)
