## rxwatch

`rxwatch` is a low-overhead bash utility for monitoring Linux RX-path diagnostics. It periodically polls hardware and kernel-level counters to help identify silent packet drops, ring buffer overflows, and CPU backlog issues.

This version features a **rolling log** mechanism, making it suitable for long-term troubleshooting of intermittent network issues (like WCCP or GRE tunnel instability) without exhausting disk space.

---

### Capabilities

The script aggregates data from:

* **NIC Hardware:** RX ring configuration and driver-level stats (`ethtool`).
* **Kernel Backlog:** CPU packet processing health (`/proc/net/softnet_stat`).
* **Protocol Stack:** Global TCP/IP statistics (`netstat -s`).
* **Interface Stats:** OS-level packet and error counters (`ip -s link`).

---

### Usage

Run as `root` or with `sudo` for full access to hardware counters.

```bash
chmod +x rxwatch_rolling.sh
sudo ./rxwatch_rolling.sh -i eth0 -t 5 -n 0 -o /var/log/rxwatch -m 2048

```

#### Options:

* `-i`: Comma-separated interfaces (e.g., `eth0,eth1`).
* `-t`: Interval in seconds between samples.
* `-n`: Number of samples to collect. Set to **0** for infinite/continuous loop.
* `-o`: Output directory for `.log` files.
* `-m`: Rolling limit in MB. Deletes the oldest log file when the directory exceeds this size.

---

### Interpreting the Logs

1. **`rx_fifo_errors` / `rx_no_bufs`:** Visible in the `ethtool` sections. Indicates the NIC hardware buffer is full.
2. **`softnet_stat` column 2:** Indicates the kernel's input queue (backlog) is full. The CPU is not draining packets fast enough.
3. **`squeezed` (softnet column 3):** The CPU budget for packet processing was exhausted before the ring was empty.

---

### Requirements

* `bash`
* `ethtool`
* `iproute2` (`ip`)
* `net-tools` (`netstat`)
