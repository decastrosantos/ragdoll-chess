class_name MainMenu
extends Control
## Menu principal + HUD de status.
##
## REGRA DE OURO (i18n): nenhuma string visível ao jogador é "chumbada" aqui.
## Os nós Label/Button da cena têm `text` definido com CHAVES do
## localization/translations.csv (ex.: "UI_NEW_GAME"); o auto-translate dos
## nós Control resolve a chave via TranslationServer e re-traduz sozinho
## quando o idioma muda. Strings dinâmicas passam por set_status(chave).

signal new_game_pressed

# Locales suportados: [código do locale, chave de tradução do nome nativo].
# Nomes de idiomas são exibidos SEMPRE no próprio idioma (convenção de UX),
# por isso as chaves LANG_* têm o mesmo valor nas três colunas do CSV.
const LOCALES: Array = [
	["pt", "LANG_PT"],
	["en", "LANG_EN"],
	["es", "LANG_ES"],
]

@onready var _menu_panel: CenterContainer = $MenuPanel
@onready var _status_label: Label = $StatusLabel
@onready var _footer_label: Label = $FooterLabel
@onready var _new_game_button: Button = $MenuPanel/Panel/Margin/VBox/NewGameButton
@onready var _lang_option: OptionButton = $MenuPanel/Panel/Margin/VBox/LangRow/LangOption


func _ready() -> void:
	TranslationServer.set_locale(LOCALES[0][0])  # padrão: português
	for entry in LOCALES:
		_lang_option.add_item(tr(entry[1]))
	_lang_option.select(0)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_lang_option.item_selected.connect(_on_language_selected)
	_status_label.text = ""


func _on_new_game_pressed() -> void:
	# O rodapé de créditos pertence à tela inicial: some junto com o menu.
	_menu_panel.hide()
	_footer_label.hide()
	new_game_pressed.emit()


func _on_language_selected(index: int) -> void:
	TranslationServer.set_locale(LOCALES[index][0])


## Mostra uma mensagem de status no topo da tela. Recebe uma CHAVE de
## tradução; o auto-translate do Label converte a chave no texto do locale
## atual (e re-traduz automaticamente se o jogador trocar de idioma).
func set_status(translation_key: String) -> void:
	_status_label.text = translation_key


## Fim de jogo: exibe o xeque-mate e reabre o menu (com o rodapé).
func show_game_over() -> void:
	set_status("MSG_CHECKMATE")
	_menu_panel.show()
	_footer_label.show()
