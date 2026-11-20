# ⚽ Técnico — futebol no navegador

Jogo de técnico de futebol que roda direto no navegador, sem instalar nada e sem IA.

**Jogar:** https://leomar1994.github.io/futebol/

## O que já tem (protótipo)
- Partida simulada lance a lance, com narração em texto
- 📺 Partida ao vivo em estilo "jogo de botão": os jogadores são botões nas cores do time e a bola circula pelo campo
- Notas parciais ao vivo; quem está mal ou sem fôlego fica em vermelho com a sugestão de substituição
- Intervalo com estatísticas (posse, finalizações, escanteios, cartões, passes…)
- 📋 Escalação com prancheta: arraste os jogadores para mudar posições, formação e quem joga (antes e durante a partida)
- Tela de GOL com o nome do time
- Velocidades 1x a 8x, pausa e "ir para o resultado"

## Times reais (Séries A, B, C e D)
Abra **🧰 Montar times reais** no jogo (`pacote.html`). Com uma conta grátis da [API-Football](https://dashboard.api-football.com), a página baixa os elencos atuais direto no seu navegador (a chave não sai dele) e monta o pacote. O progresso fica salvo se o limite diário de 100 pedidos acabar. O arquivo `brasil.json` gerado pode ir para `dados/brasil.json` no repositório para todos jogarem com os mesmos times.

Escudos: o jogo desenha escudos próprios com as cores e a sigla de cada clube. Os escudos oficiais são marcas dos clubes; há uma opção para exibi-los da internet, desligada por padrão.

## Próximos passos
- Pacote com os times das Séries A, B, C e D, campeonato com acesso e rebaixamento
- Gestão do clube: transferências, finanças, categorias de base
- Liga online com amigos

Os elencos são um pacote de exemplo e as forças dos jogadores são estimativas do jogo.
