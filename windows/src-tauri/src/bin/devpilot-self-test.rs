use std::process::ExitCode;

fn parse_args() -> Result<(u16, bool), String> {
    let mut args = std::env::args().skip(1);
    let mut port = None;
    let mut terminate = false;

    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--port" => {
                let value = args.next().ok_or_else(|| "--port 缺少端口号".to_owned())?;
                port = Some(
                    value
                        .parse::<u16>()
                        .map_err(|_| format!("无效端口号：{value}"))?,
                );
            }
            "--terminate" => terminate = true,
            _ => return Err(format!("未知参数：{argument}")),
        }
    }

    Ok((
        port.ok_or_else(|| "必须提供 --port <端口号>".to_owned())?,
        terminate,
    ))
}

fn main() -> ExitCode {
    let result = parse_args().and_then(|(port, terminate)| {
        devpilot_windows_lib::run_backend_smoke_test(port, terminate)
    });

    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("DevPilot backend smoke test failed: {error}");
            ExitCode::FAILURE
        }
    }
}
