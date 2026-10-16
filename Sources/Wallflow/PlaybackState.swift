/// 用户暂停与系统休眠分别保存，系统恢复时保留用户的暂停选择。
struct PlaybackState {
    var userPaused = false
    var systemSleeping = false
    var screensSleeping = false

    var isPaused: Bool { userPaused || systemSleeping || screensSleeping }
}
