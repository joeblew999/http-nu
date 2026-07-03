#!/usr/bin/env nu
# Ephemeral-VAPID wrapper for the Claude Code preview integration (.claude/launch.json)
# so it can stay env-agnostic. Real deployments use `mise run push-demo:serve` +
# fnox; these keys are per-process and evaporate when this exits -- never reuse
# them for real subscriptions.
let port = ($env.PORT? | default "8090")

# gen_vapid prints `export VAPID_PUBLIC_KEY=...` then `export VAPID_PRIVATE_KEY=...`.
let vars = (^cargo run --quiet --example gen_vapid -p nu_plugin_push | lines | parse "export {key}={value}")
$env.VAPID_PUBLIC_KEY = ($vars | where key == "VAPID_PUBLIC_KEY" | get value.0)
$env.VAPID_PRIVATE_KEY = ($vars | where key == "VAPID_PRIVATE_KEY" | get value.0)
$env.VAPID_SUBJECT = ($env.VAPID_SUBJECT? | default "mailto:preview@example.com")
$env.PUSH_ADMIN_TOKEN = ($env.PUSH_ADMIN_TOKEN? | default $"preview-token-(random chars --length 8)")

mkdir .store/push-demo
^target/debug/http-nu --plugin $"(pwd)/target/debug/nu_plugin_push" --store .store/push-demo $":($port)" examples/push-demo/serve.nu
