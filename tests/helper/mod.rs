use std::net::TcpListener;
use daysquare::telemetry::{get_subscriber, init_subscriber};
use daysquare::run;
use once_cell::sync::Lazy;

// Ensure `tracing` stack is only initialized once using `once_cell`
static TRACING: Lazy<()> = Lazy::new(|| {
    let default_filter_level = "info".to_string();
    let subscriber_name = "test".to_string();

    // Logs to stdout if `TEST_LOG` is set. If not set send into the void
    if std::env::var("TEST_LOG").is_ok() {
        let subscriber = get_subscriber(subscriber_name, default_filter_level, std::io::stdout);
        init_subscriber(subscriber);
    } else {
        let subscriber = get_subscriber(subscriber_name, default_filter_level, std::io::sink);
        init_subscriber(subscriber);
    };
});

pub struct TestApp {
    pub address: String,
    pub db_pool: String,
}

pub fn spawn_app() -> TestApp {
    // First tie `initialize` is invoked the code in `TRACING` is executed.
    // All other invocations will instead skip execution
    Lazy::force(&TRACING);

    let listener = TcpListener::bind("127.0.0.1:0")
        .expect("Failed to bind to random port");

    // Retrieve the port assigned to us by the OS
    let port = listener.local_addr().unwrap().port();
    let address = format!("http://127.0.0.1:{}", port);

    let server = run(listener).expect("Failed to bind to address");

    let _ = tokio::spawn(server);

    TestApp {
        address,
        db_pool: "".to_string(),
    }
}
