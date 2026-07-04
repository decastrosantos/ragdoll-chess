# Ragdoll Chess ♟️💥

Protótipo de **Battle Chess 3D** com física exagerada e humor, feito na **Godot Engine 4.3+** (GDScript). Alvo primário: **Web (HTML5)**, com exportação mobile planejada.

## O protótipo

- Tabuleiro 8x8 mapeado matematicamente no espaço 3D (matriz ↔ `Vector3`).
- Clique para selecionar, clique para mover — a peça **pula em arco** até a casa.
- **Captura**: a vítima vira corpo físico ativo (`freeze = false`) e é arremessada para fora do tabuleiro com `apply_central_impulse` + torque aleatório, poeira de partículas e **zoom dinâmico de câmera**.
- **State Machine**: Turno das Brancas → Animação/Combate → Turno das Pretas.
- **i18n desde o dia 1**: Português, English, Español — zero strings hardcoded; tudo passa pelo `TranslationServer` (`localization/translations.csv`).
- **Movimentos legais** por tipo de peça (`scripts/logic/move_rules.gd`): bloqueios, capturas, avanço duplo do peão e promoção automática a dama. Casas válidas ficam destacadas (verde = mover, vermelho = capturar).
- ⚠️ Sem xeque, roque ou en passant por enquanto — no estilo Battle Chess, a partida termina com a **captura física do rei**.

## Como rodar

1. Instale o [Godot 4.3+](https://godotengine.org/download) (versão padrão, não .NET).
2. Abra o projeto (`project.godot`) no editor — na primeira abertura o Godot importa o CSV de traduções (avisos iniciais somem).
3. Pressione **F5**.

## Estrutura

```
scenes/          # Cenas (main, peça base, menu)
scripts/logic/   # LÓGICA: board.gd, game_state_machine.gd, input_controller.gd
scripts/view/    # VISUAL: piece.gd (física da captura), battle_camera.gd, efeitos
scripts/ui/      # main_menu.gd (troca de idioma via TranslationServer)
localization/    # translations.csv (keys, pt, en, es)
```

## Deploy automático (GitHub Pages)

Todo push na `main` dispara `.github/workflows/web-build.yml`, que exporta o preset **Web** e publica no GitHub Pages.

Configuração única no repositório do GitHub:

1. Crie o repositório e faça o push da `main`.
2. Em **Settings → Pages → Build and deployment → Source**, escolha **GitHub Actions**.

> O preset Web usa `thread_support=false` de propósito: builds com threads exigem headers COOP/COEP que o GitHub Pages não fornece. Sem threads, o jogo roda no Pages e no Safari/iOS sem gambiarras.
