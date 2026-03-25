#!/usr/bin/env bash
set -euo pipefail

IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUPABASE_DIR="$APP_DIR/supabase"
FUNCTIONS_DIR="$SUPABASE_DIR/functions"
PROJECT_REF="${PROJECT_REF:-lexiwzhuwwrqtdvdewjk}"
RUN_AUTH_CONFIG="${RUN_AUTH_CONFIG:-0}"
AUTH_CONFIG_SCRIPT="$SCRIPT_DIR/configure_supabase_auth.sh"

TEMP_ENV_FILE=""
TEMP_DIR=""

log() {
  printf '[supabase-release] %s\n' "$*"
}

die() {
  printf '[supabase-release] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || die "Missing required command: $name"
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    die "Missing required env var: $name"
  fi
}

cleanup() {
  if [[ -n "$TEMP_ENV_FILE" && -f "$TEMP_ENV_FILE" ]]; then
    rm -f "$TEMP_ENV_FILE"
  fi
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rmdir "$TEMP_DIR" 2>/dev/null || true
  fi
}

write_temp_env_file() {
  umask 077
  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sls-supabase-release.XXXXXX")"
  TEMP_ENV_FILE="$TEMP_DIR/release.env"

  write_line() {
    local key="$1"
    local value="$2"
    local escaped="${value//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    printf '%s="%s"\n' "$key" "$escaped" >>"$TEMP_ENV_FILE"
  }

  : >"$TEMP_ENV_FILE"
  write_line SUPABASE_URL "https://${PROJECT_REF}.supabase.co"
  write_line SUPABASE_SERVICE_ROLE_KEY "$SUPABASE_SERVICE_ROLE_KEY"
  write_line SUPABASE_ANON_KEY "$SUPABASE_ANON_KEY"
  write_line STRIPE_SECRET_KEY "$STRIPE_SECRET_KEY"
  write_line STRIPE_EARLY_BIRD_PRICE_ID "$STRIPE_EARLY_BIRD_PRICE_ID"
  write_line STRIPE_REGULAR_PRICE_ID "$STRIPE_REGULAR_PRICE_ID"
  write_line STRIPE_EARLY_BIRD_PRODUCT_ID "$STRIPE_EARLY_BIRD_PRODUCT_ID"
  write_line STRIPE_REGULAR_PRODUCT_ID "$STRIPE_REGULAR_PRODUCT_ID"
  write_line RESEND_API "$RESEND_API"
  write_line RESEND_FROM_EMAIL "$RESEND_FROM_EMAIL"
  write_line RESEND_ADMIN_EMAIL "$RESEND_ADMIN_EMAIL"
  write_line SITE_URL "$SITE_URL"
}

print_verification_hints() {
  cat <<EOF

Next-step verification hints:
  1. Re-run the success-page checkout redirect in a browser and confirm it lands on ${SITE_URL}/success?session_id=...
  2. POST a known Stripe session to the verify-purchase function and confirm the response returns fulfilled or already_processed.
  3. Check that get_course_videos returns START HERE! as the first lesson.
  4. Confirm purchase/access emails are sending from ${RESEND_FROM_EMAIL}.
  5. If RUN_AUTH_CONFIG=1 was used, confirm auth emails now come from SLS Trading Course <${RESEND_FROM_EMAIL}>.
EOF
}

main() {
  require_command supabase

  require_env SUPABASE_DB_PASSWORD
  require_env SUPABASE_SERVICE_ROLE_KEY
  require_env SUPABASE_ANON_KEY
  require_env STRIPE_SECRET_KEY
  require_env STRIPE_EARLY_BIRD_PRICE_ID
  require_env STRIPE_REGULAR_PRICE_ID
  require_env STRIPE_EARLY_BIRD_PRODUCT_ID
  require_env STRIPE_REGULAR_PRODUCT_ID
  require_env RESEND_API
  require_env RESEND_FROM_EMAIL
  require_env RESEND_ADMIN_EMAIL
  require_env SITE_URL

  trap cleanup EXIT INT TERM

  log "Using project ref ${PROJECT_REF}"
  log "Release root: ${APP_DIR}"

  if [[ "$RUN_AUTH_CONFIG" == "1" ]]; then
    [[ -x "$AUTH_CONFIG_SCRIPT" ]] || die "Auth config script is missing or not executable: $AUTH_CONFIG_SCRIPT"
    require_env SUPABASE_ACCESS_TOKEN
    log "Applying Supabase auth SMTP and email templates"
    "$AUTH_CONFIG_SCRIPT"
  else
    log "Skipping auth config. Set RUN_AUTH_CONFIG=1 to switch auth emails off Lovable and onto Resend."
  fi

  log "Linking Supabase project"
  supabase link --project-ref "$PROJECT_REF" --password "$SUPABASE_DB_PASSWORD" --workdir "$APP_DIR" --yes

  log "Pushing database migrations"
  supabase db push --linked --password "$SUPABASE_DB_PASSWORD" --workdir "$APP_DIR" --yes

  log "Preparing edge-function secrets"
  write_temp_env_file
  supabase secrets set --env-file "$TEMP_ENV_FILE" --project-ref "$PROJECT_REF" --workdir "$APP_DIR" --yes

  log "Deploying verify-purchase as a public checkout-verification endpoint"
  supabase functions deploy verify-purchase --project-ref "$PROJECT_REF" --workdir "$APP_DIR" --no-verify-jwt --yes

  log "Deploying grant-access with in-function admin auth validation"
  supabase functions deploy grant-access --project-ref "$PROJECT_REF" --workdir "$APP_DIR" --no-verify-jwt --yes

  if [[ -f "$FUNCTIONS_DIR/get-video/index.ts" ]]; then
    log "Deploying get-video as an authenticated endpoint with in-function JWT validation"
    supabase functions deploy get-video --project-ref "$PROJECT_REF" --workdir "$APP_DIR" --no-verify-jwt --yes
  else
    log "Skipping get-video because it is not present locally"
  fi

  log "Supabase release commands completed successfully"
  print_verification_hints
}

main "$@"
