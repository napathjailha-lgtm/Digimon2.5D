extends AdventureMenuScreen
## Scene นี้ใช้ทั้ง Boot→Login และ Character→Gameplay ไม่เรียก threaded_get ก่อนพร้อม
signal loading_finished(scene: PackedScene)
@export var auto_transition: bool = true
@export var target_override: String = ""
@export_range(0.0, 3.0) var minimum_visible_seconds: float = 0.55
@onready var progress_bar: TextureProgressBar = $Margin/Column/Center/Panel/Inner/Stack/Progress
@onready var percent_label: Label = $Margin/Column/Center/Panel/Inner/Stack/Percent
@onready var status_label: Label = $Margin/Column/Center/Panel/Inner/Stack/Status
@onready var retry_button: Button = $Margin/Column/Center/Panel/Inner/Stack/Retry
var _target: String = ""
var _elapsed: float = 0.0
var _request_active: bool = false
var _ready_to_finish: bool = false
var _catalog_required: bool = false
var loaded_scene: PackedScene

func _ready() -> void:
    super._ready()
    retry_button.pressed.connect(start_loading)
    start_loading.call_deferred()

func start_loading() -> void:
    # วัด progress จริงจาก ResourceLoader มี minimum time แค่ให้ผู้เล่นเห็น 100% หนึ่งเฟรม
    _target = target_override if not target_override.is_empty() else GameManager.loading_target
    progress_bar.value = 0
    percent_label.text = "0%"
    _elapsed = 0
    loaded_scene = null
    _ready_to_finish = false
    retry_button.hide()
    if not ResourceLoader.exists(_target):
        _loading_error("ไม่พบ Scene ที่ต้องการโหลด")
        return
    var error: Error = ResourceLoader.load_threaded_request(_target, "PackedScene")
    if error != OK:
        _loading_error("เริ่มโหลดไม่ได้: " + error_string(error))
        return
    _catalog_required = GameManager.catalog == null
    if _catalog_required:
        var catalog_error: Error = ResourceLoader.load_threaded_request(GameManager.CATALOG_PATH, "Resource")
        if catalog_error != OK:
            _loading_error("เริ่มโหลด Catalog ไม่ได้")
            return
    _request_active = true
    status_label.text = "กำลังเชื่อมประตูสู่โลกดิจิตอล…"

func _process(delta: float) -> void:
    if not _request_active:
        return
    _elapsed += delta
    var progress: Array = []
    var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_target, progress)
    var catalog_done: bool = not _catalog_required
    var catalog_progress: float = 1.0 if catalog_done else 0.0
    if _catalog_required:
        var resource_progress: Array = []
        var resource_status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(GameManager.CATALOG_PATH, resource_progress)
        if not resource_progress.is_empty():
            catalog_progress = float(resource_progress[0])
        if resource_status == ResourceLoader.THREAD_LOAD_LOADED:
            GameManager.catalog = ResourceLoader.load_threaded_get(GameManager.CATALOG_PATH) as PregameCatalog
            if GameManager.catalog == null:
                _loading_error("Catalog ไม่ถูกต้อง")
                return
            _catalog_required = false
            catalog_done = true
            catalog_progress = 1.0
        elif resource_status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
            _loading_error("โหลด Catalog ไม่สำเร็จ")
            return
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            if not progress.is_empty():
                progress_bar.value = maxf(progress_bar.value, (float(progress[0]) + catalog_progress) * 49.5)
        ResourceLoader.THREAD_LOAD_LOADED:
            if _elapsed < minimum_visible_seconds or not catalog_done:
                progress_bar.value = maxf(progress_bar.value, (1.0 + catalog_progress) * 49.5)
            elif not _ready_to_finish:
                # รอ LOADED ก่อน threaded_get จึงไม่ block main thread ระหว่างโหลด
                loaded_scene = ResourceLoader.load_threaded_get(_target) as PackedScene
                if loaded_scene == null:
                    _loading_error("Resource ที่โหลดไม่ใช่ PackedScene")
                    return
                progress_bar.value = 100
                _ready_to_finish = true
                _complete_after_frame.call_deferred()
        ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            _loading_error("โหลด Scene ไม่สำเร็จ กรุณาลองใหม่")
    percent_label.text = "%d%%" % int(progress_bar.value)

func _complete_after_frame() -> void:
    # 100% วาดก่อนเปลี่ยน Scene; ใช้ process_frame จึงทดสอบ headless ได้ด้วย
    await get_tree().process_frame
    if not is_inside_tree() or not _ready_to_finish:
        return
    _request_active = false
    status_label.text = "พร้อมแล้ว — เข้าสู่ Digital Adventure"
    loading_finished.emit(loaded_scene)
    if not auto_transition:
        return
    if _target in GameManager.ZONE_SCENES.values():
        GameManager.set_menu_input(false)
    var error: Error = get_tree().change_scene_to_packed(loaded_scene)
    if error != OK:
        _loading_error("เปลี่ยน Scene ไม่ได้: " + error_string(error))

func _loading_error(text: String) -> void:
    # ไม่มีการวนเปลี่ยน Scene เมื่อโหลดพลาด ปุ่ม Retry ให้ลองใหม่ได้
    _request_active = false
    status_label.text = text
    retry_button.show()

func back() -> void:
    # ไม่ยกเลิก threaded load กลางทาง เพราะ request ต้องถูกเก็บผลให้ครบ
    show_message("กรุณารอการโหลดให้เสร็จก่อน")
