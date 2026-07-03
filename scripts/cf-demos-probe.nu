#!/usr/bin/env nu

# Run every ex:cf:<demo> in turn, capture the first HTTP response,
# emit a CSV summary. ~30-45s per demo (worker-build is slow), so this
# is a several-minute run.
#
# Usage: nu scripts/cf-demos-probe.nu
#
# Output: stdout has a markdown table; stderr has per-demo build/probe logs.

const DEMOS = [
  blog
  basic
  cargo-docs
  2048
  workspace-browser
  datastar-counter
  datastar-sdk
  datastar-sdk-test
  mermaid-editor
  templates
  quotes
  tao
  stor
]

const BASE = "http://127.0.0.1:8787"

# Probe a single demo: launch its wrangler dev, wait for readiness, curl `/`,
# and return a {demo, status, note} record.
def probe-demo [demo: string] {
  let out_dir = (mktemp -d)
  let log = ($out_dir | path join "wrangler.log")

  print -e $">>> ($demo)"
  # Spawn the wrangler dev server in the background, redirecting its combined
  # stdout+stderr to the log file.
  let job_id = (job spawn {
    let res = (^mise run $"ex:cf:($demo)" | complete)
    $"($res.stdout)($res.stderr)" | save -f $log
  })

  # Wait up to 90s for wrangler to be ready.
  mut ready = false
  for i in 1..90 {
    if (($log | path exists) and (open $log | str contains "Ready on")) {
      $ready = true
      break
    }
    # Stop early if the job has already exited.
    if (job list | where id == $job_id | is-empty) {
      break
    }
    sleep 1sec
  }

  if not $ready {
    let log_text = if ($log | path exists) { open $log } else { "" }
    let result = if ($log_text | find --regex "handler failed to parse|Parse error" | is-not-empty) {
      let note = (
        $log_text
          | find --regex "x [^\"\\\\]*"
          | first
          | default ""
          | str replace --all "|" ""
      )
      {demo: $demo, status: "parse-fail", note: $note}
    } else {
      {demo: $demo, status: "build-fail", note: "build never reached Ready"}
    }
    job kill $job_id
    return $result
  }

  # Probe / on the worker (default DO).
  let probe = (^curl -s --max-time 5 $"($BASE)/" | complete)
  let code = if $probe.exit_code == 0 {
    (
      ^curl -s -o /dev/null -w "%{http_code}" --max-time 5 $"($BASE)/"
        | complete
        | get stdout
        | str trim
    )
  } else {
    "TIMEOUT"
  }
  let body = $probe.stdout

  let note = match $code {
    "200" => "serves"
    "501" | "500" => ($body | str substring 0..120 | str replace --all --regex "[\n|]" " ")
    _ => "unexpected"
  }

  job kill $job_id
  {demo: $demo, status: $code, note: $note}
}

let results = ($DEMOS | each {|demo| probe-demo $demo })

print ""
print "## CF demo probe results"
print ""
$results | table
