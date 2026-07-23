fn main() {
    // Cross-checking an MSVC target from macOS has no Windows resource compiler.
    // This opt-in path skips only resource/manifest generation so Rust can still
    // type-check every Windows-specific module. Normal dev and release builds do
    // not set the variable and always execute the full Tauri build pipeline.
    if std::env::var("DEVPILOT_CROSS_CHECK").as_deref() == Ok("1") {
        if let Ok(target) = std::env::var("TARGET") {
            println!("cargo:rustc-env=TAURI_ENV_TARGET_TRIPLE={target}");
        }
        println!("cargo:rustc-check-cfg=cfg(desktop)");
        println!("cargo:rustc-cfg=desktop");
        println!("cargo:rerun-if-changed=tauri.conf.json");
        println!("cargo:rerun-if-changed=capabilities");
        return;
    }

    tauri_build::build()
}
