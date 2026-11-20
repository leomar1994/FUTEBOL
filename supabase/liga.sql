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
  and j.temporada = (select temporada from public.liga_estado where id = 1) and j.div = c.div
group by c.id, c.div;

create or replace function public.liga_posicao(p_clube text) returns int language sql stable as $$
  select pos from (
    select clube, row_number() over (order by p desc, v desc, (gp - gcontra) desc, gp desc, clube) as pos
    from public.liga_classificacao where div = (select div from public.liga_clubes where id = p_clube)
  ) x where clube = p_clube;
$$;

-- ---------- calendário (turno e returno, método do círculo) ----------
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

-- ---------- a rodada (roda sozinha todo dia às 21h de Brasília) ----------
create or replace function public.liga_rodar_rodada() returns text language plpgsql security definer set search_path = public as $$
declare est liga_estado; j record; fc numeric; ff numeric; ec text; ef text; lc numeric; lf numeric; v_gc int; v_gf int;
        tec record; pos int; meta int; saldo int; nconf int; total int; ranking int;
begin
  select * into est from liga_estado where id = 1 for update;
  if not exists (select 1 from liga_jogos where temporada = est.temporada) then perform liga_gerar_calendario(est.temporada); end if;
  for j in select * from liga_jogos where temporada = est.temporada and rodada = est.rodada and not jogado loop
    select forca into fc from liga_clubes where id = j.casa; select forca into ff from liga_clubes where id = j.fora;
    select coalesce(t2.estilo, 'eq') into ec from liga_tecnicos t1 left join liga_taticas t2 using (user_id) where t1.clube = j.casa;
    select coalesce(t2.estilo, 'eq') into ef from liga_tecnicos t1 left join liga_taticas t2 using (user_id) where t1.clube = j.fora;
    lc := 1.3 * exp(((fc + 2.5) - ff) / 22); lf := 1.3 * exp((ff - (fc + 2.5)) / 22);
    if ec = 'of' then lc := lc * 1.15; lf := lf * 1.12; elsif ec = 'de' then lc := lc * 0.85; lf := lf * 0.82; end if;
    if ef = 'of' then lf := lf * 1.15; lc := lc * 1.12; elsif ef = 'de' then lf := lf * 0.85; lc := lc * 0.82; end if;
    v_gc := liga_poisson(lc); v_gf := liga_poisson(lf);
    update liga_jogos set gc = v_gc, gf = v_gf, jogado = true where id = j.id;
  end loop;
  -- diretoria de cada técnico humano
  for tec in select t.*, g.casa, g.fora, g.gc, g.gf from liga_tecnicos t
             join liga_jogos g on g.temporada = est.temporada and g.rodada = est.rodada and (g.casa = t.clube or g.fora = t.clube)
             where not t.demitido loop
    pos := liga_posicao(tec.clube);
    select count(*) + 1 into ranking from liga_clubes x where x.div = tec.div and x.forca > (select forca from liga_clubes where id = tec.clube);
    meta := case when ranking <= 4 then 4 when ranking <= 12 then 10 else 16 end;
    saldo := case when tec.casa = tec.clube then tec.gc - tec.gf else tec.gf - tec.gc end;
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
revoke all on function public.liga_rodar_rodada(), public.liga_fim_temporada(), public.liga_gerar_calendario(int), public.liga_gerar_propostas(uuid) from public, anon, authenticated;
grant execute on function public.liga_entrar(text, text), public.liga_aceitar(text) to authenticated;
grant execute on function public.liga_posicao(text), public.liga_poisson(numeric) to anon, authenticated;

-- ---------- primeiro calendário e relógio das rodadas ----------
do $$ begin
  if not exists (select 1 from public.liga_jogos) then perform public.liga_gerar_calendario((select temporada from public.liga_estado where id = 1)); end if;
end $$;
do $$ begin
  perform cron.unschedule('liga-rodada-diaria');
exception when others then null; end $$;
select cron.schedule('liga-rodada-diaria', '0 0 * * *', $$select public.liga_rodar_rodada()$$);   -- 00:00 UTC = 21h de Brasília

-- Para testar sem esperar: select public.liga_rodar_rodada();
