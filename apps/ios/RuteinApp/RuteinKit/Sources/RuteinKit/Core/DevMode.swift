public enum DevMode {
    public static var isEnabled: Bool {
        #if DEBUG
            true
        #else
            false
        #endif
    }
}
