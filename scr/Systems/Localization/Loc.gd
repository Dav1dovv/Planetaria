extends RefCounted
class_name Loc

## Локализация: русский / английский / армянский.
## Все строки лежат в common/Translations/strings.json в формате
## { "ключ": { "en": "...", "ru": "...", "hy": "..." } } и регистрируются в
## TranslationServer кодом — менять Project Settings не нужно.
## Благодаря этому Label/Button/OptionButton/tooltip с текстом-ключом переводятся
## автоматически, а для собранных строк (формат, склейка) используй Loc.t("ключ").

const TABLE_PATH := "res://common/Translations/strings.json"
const LANGUAGES: Array[String] = ["ru", "en", "hy"]

const FONT_ARMENIAN := "res://Assets/Fonts/Shushi Regular.ttf"
## Шрифты проекта, у которых нет армянских букв: к ним подключается запасной
const PROJECT_FONTS: Array[String] = [
	"res://Assets/Fonts/Conthrax-SemiBold.otf",
	"res://Assets/Fonts/HemiHead-Bold.otf",
	"res://Assets/Fonts/Zekton-Regular.otf",
	"res://Assets/Fonts/NavirianScript-Regular.ttf",
]

static var _is_setup: bool = false
static var _registered: Array[Translation] = []


## Загружает таблицу и настраивает шрифты. Безопасно вызывать много раз.
static func setup() -> void:
	if _is_setup:
		return
	_is_setup = true
	reload_table()
	_setup_font_fallbacks()


## Перечитать strings.json (удобно при правке таблицы без перезапуска).
static func reload_table() -> void:
	for old in _registered:
		TranslationServer.remove_translation(old)
	_registered.clear()

	if not FileAccess.file_exists(TABLE_PATH):
		push_warning("Loc: нет файла переводов " + TABLE_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Loc: strings.json повреждён — ожидался объект")
		return
	var table: Dictionary = parsed

	var by_lang: Dictionary = {}
	for lang in LANGUAGES:
		var translation := Translation.new()
		translation.locale = lang
		by_lang[lang] = translation

	for key: String in table:
		var entry: Dictionary = table[key]
		for lang in LANGUAGES:
			var text: String = entry.get(lang, "")
			if not text.is_empty():
				(by_lang[lang] as Translation).add_message(key, text)

	for lang in LANGUAGES:
		var translation := by_lang[lang] as Translation
		TranslationServer.add_translation(translation)
		_registered.append(translation)


## Перевод строки-ключа на текущий язык (если перевода нет — вернёт сам ключ).
static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## "ru" / "en" / "hy" — текущий язык интерфейса.
static func get_language() -> String:
	var code := TranslationServer.get_locale().substr(0, 2)
	return code if LANGUAGES.has(code) else "en"


## Сменить язык и сохранить выбор в настройках.
static func set_language(code: String) -> void:
	if not LANGUAGES.has(code):
		return
	var settings = Global.setting_manager
	if settings != null:
		settings.set_value("language", code)
		settings.save_settings()
	else:
		TranslationServer.set_locale(code)


## Файл с фразами заставки для текущего языка (английский — базовый файл).
static func splash_path() -> String:
	var base := "res://common/SplashTexts.json"
	var lang := get_language()
	if lang == "en":
		return base
	var localized := "res://common/SplashTexts.%s.json" % lang
	return localized if FileAccess.file_exists(localized) else base


# ─────────────────────────────────────────────────────────────────────────────
#  Шрифты: у Conthrax / Zekton / HemiHead нет армянских букв
# ─────────────────────────────────────────────────────────────────────────────
static func _setup_font_fallbacks() -> void:
	var armenian: Font = null
	if ResourceLoader.exists(FONT_ARMENIAN):
		armenian = load(FONT_ARMENIAN) as Font
	if armenian == null:
		push_warning("Loc: нет шрифта с армянскими буквами (%s) — будет системный запасной" % FONT_ARMENIAN)
		return

	for path in PROJECT_FONTS:
		if ResourceLoader.exists(path):
			_add_fallback(load(path) as Font, armenian)

	# Шрифт темы по умолчанию (для Label/Button без своего шрифта)
	_add_fallback(ThemeDB.fallback_font, armenian)
	var project_theme := ThemeDB.get_project_theme()
	if project_theme != null and project_theme.has_default_font():
		_add_fallback(project_theme.default_font, armenian)


static func _add_fallback(font: Font, fallback: Font) -> void:
	if font == null or font == fallback:
		return
	var list: Array[Font] = font.fallbacks.duplicate()
	if not list.has(fallback):
		list.append(fallback)
		font.fallbacks = list
