#!/usr/bin/env bash
set -euo pipefail

IFS=$'\n\t'
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$APP_DIR/supabase/templates"
BACKUP_DIR="${BACKUP_DIR:-$APP_DIR/.supabase-backups}"
PROJECT_REF="${PROJECT_REF:-lexiwzhuwwrqtdvdewjk}"
SITE_URL="${SITE_URL:-https://www.sheaslegacyscalping.com}"
URI_ALLOW_LIST="${URI_ALLOW_LIST:-${SITE_URL},${SITE_URL}/**}"
SMTP_HOST="${SMTP_HOST:-smtp.resend.com}"
SMTP_PORT="${SMTP_PORT:-465}"
SMTP_USER="${SMTP_USER:-resend}"
SMTP_SENDER_NAME="${SMTP_SENDER_NAME:-SLS Trading Course}"
SMTP_ADMIN_EMAIL="${SMTP_ADMIN_EMAIL:-${RESEND_FROM_EMAIL:-noreply@mail.sheaslegacyscalping.com}}"
AUTH_API_URL="https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth"

log() {
  printf '[supabase-auth] %s\n' "$*"
}

die() {
  printf '[supabase-auth] ERROR: %s\n' "$*" >&2
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

require_file() {
  local path="$1"
  [[ -f "$path" ]] || die "Missing required file: $path"
}

main() {
  require_command curl
  require_command jq
  require_env SUPABASE_ACCESS_TOKEN
  require_env RESEND_API
  require_env RESEND_FROM_EMAIL

  require_file "$TEMPLATE_DIR/magic-link.html"
  require_file "$TEMPLATE_DIR/confirmation.html"
  require_file "$TEMPLATE_DIR/recovery.html"
  require_file "$TEMPLATE_DIR/invite.html"
  require_file "$TEMPLATE_DIR/email-change.html"
  require_file "$TEMPLATE_DIR/reauthentication.html"

  mkdir -p "$BACKUP_DIR"

  local timestamp
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  local backup_file="$BACKUP_DIR/auth-config-${PROJECT_REF}-${timestamp}.json"
  local response_file="$BACKUP_DIR/auth-config-${PROJECT_REF}-${timestamp}.response.json"

  log "Backing up current auth config to $backup_file"
  curl --silent --show-error --fail-with-body \
    --header "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    --header "Content-Type: application/json" \
    "$AUTH_API_URL" \
    >"$backup_file"

  local payload
  payload="$(
    jq -n \
      --arg smtp_admin_email "$SMTP_ADMIN_EMAIL" \
      --arg smtp_host "$SMTP_HOST" \
      --arg smtp_port "$SMTP_PORT" \
      --arg smtp_user "$SMTP_USER" \
      --arg smtp_pass "$RESEND_API" \
      --arg smtp_sender_name "$SMTP_SENDER_NAME" \
      --arg site_url "$SITE_URL" \
      --arg uri_allow_list "$URI_ALLOW_LIST" \
      --arg confirmation_subject "Confirm your email for SLS Trading Course" \
      --arg invite_subject "You're invited to SLS Trading Course" \
      --arg magic_link_subject "Your SLS Trading Course sign-in link" \
      --arg recovery_subject "Reset your SLS Trading Course password" \
      --arg email_change_subject "Confirm your SLS Trading Course email change" \
      --arg reauthentication_subject "Verify your SLS Trading Course sign-in" \
      --rawfile confirmation_template "$TEMPLATE_DIR/confirmation.html" \
      --rawfile invite_template "$TEMPLATE_DIR/invite.html" \
      --rawfile magic_link_template "$TEMPLATE_DIR/magic-link.html" \
      --rawfile recovery_template "$TEMPLATE_DIR/recovery.html" \
      --rawfile email_change_template "$TEMPLATE_DIR/email-change.html" \
      --rawfile reauthentication_template "$TEMPLATE_DIR/reauthentication.html" \
      '{smtp_admin_email:$smtp_admin_email,smtp_host:$smtp_host,smtp_port:$smtp_port,smtp_user:$smtp_user,smtp_pass:$smtp_pass,smtp_sender_name:$smtp_sender_name,site_url:$site_url,uri_allow_list:$uri_allow_list,hook_send_email_enabled:false,mailer_subjects_confirmation:$confirmation_subject,mailer_subjects_invite:$invite_subject,mailer_subjects_magic_link:$magic_link_subject,mailer_subjects_recovery:$recovery_subject,mailer_subjects_email_change:$email_change_subject,mailer_subjects_reauthentication:$reauthentication_subject,mailer_templates_confirmation_content:$confirmation_template,mailer_templates_invite_content:$invite_template,mailer_templates_magic_link_content:$magic_link_template,mailer_templates_recovery_content:$recovery_template,mailer_templates_email_change_content:$email_change_template,mailer_templates_reauthentication_content:$reauthentication_template}'
  )"

  log "Applying SMTP sender, canonical URLs, and branded auth templates"
  curl --silent --show-error --fail-with-body \
    --request PATCH \
    --header "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "$payload" \
    "$AUTH_API_URL" \
    >"$response_file"

  log "Auth config updated successfully"
  log "Backup saved to $backup_file"
  jq -r '
    [
      "Sender: \(.smtp_sender_name) <\(.smtp_admin_email)>",
      "Site URL: \(.site_url)",
      "Allow list: \(.uri_allow_list)",
      "Send Email Hook Enabled: \(.hook_send_email_enabled)"
    ] | .[]
  ' "$response_file"
}

main "$@"
