#!/usr/bin/env bash
#
# email.sh - CLI wrapper for Himalaya email client
# Supports IMAP/SMTP with multi-account configuration via environment variables
#
# Usage: ./email.sh <command> [options]
#
# Environment Variables:
#   Single Account:
#     EMAIL_ADDRESS, EMAIL_USER, EMAIL_PASSWORD, IMAP_HOST, SMTP_HOST
#     Optional: IMAP_PORT (993), SMTP_PORT (587)
#
#   Multi-Account (pattern EMAIL_{NAME}_*):
#     EMAIL_WORK_ADDRESS, EMAIL_WORK_USER, etc.
#

set -euo pipefail

# Constants
readonly DEFAULT_LIMIT=50
readonly MAX_LIMIT=500
readonly ATTACHMENT_DIR="${HOME}/Downloads/email-attachments"
readonly HIMALAYA_MIN_VERSION="1.0.0"

# Global variables
CONFIG_FILE=""
SELECTED_ACCOUNT=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Utility Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    log_error "$*"
    exit 1
}

# ============================================================================
# Himalaya Installation
# ============================================================================

check_himalaya() {
    if command -v himalaya &> /dev/null; then
        return 0
    fi

    # Check in common locations
    if [[ -x "${HOME}/.local/bin/himalaya" ]]; then
        export PATH="${HOME}/.local/bin:${PATH}"
        return 0
    fi

    if [[ -x "${HOME}/.cargo/bin/himalaya" ]]; then
        export PATH="${HOME}/.cargo/bin:${PATH}"
        return 0
    fi

    return 1
}

install_himalaya() {
    log_info "Installing himalaya..."

    # Try cargo first if available
    if command -v cargo &> /dev/null; then
        log_info "Installing via cargo..."
        cargo install himalaya 2>/dev/null && return 0
    fi

    # Fallback to install script
    log_info "Installing via install script..."
    mkdir -p "${HOME}/.local/bin"

    local install_script
    install_script=$(mktemp)
    if curl -sSL "https://raw.githubusercontent.com/pimalaya/himalaya/master/install.sh" -o "$install_script"; then
        chmod +x "$install_script"
        PREFIX="${HOME}/.local" bash "$install_script"
        rm -f "$install_script"
        export PATH="${HOME}/.local/bin:${PATH}"

        if check_himalaya; then
            log_success "Himalaya installed successfully"
            return 0
        fi
    fi

    rm -f "$install_script"
    die "Failed to install himalaya. Please install manually: https://github.com/pimalaya/himalaya"
}

ensure_himalaya() {
    if ! check_himalaya; then
        install_himalaya
    fi
}

# ============================================================================
# Account Discovery
# ============================================================================

discover_accounts() {
    local accounts=()

    # Default account
    if [[ -n "${EMAIL_ADDRESS:-}" ]]; then
        accounts+=("default")
    fi

    # Scan for EMAIL_{NAME}_ADDRESS pattern
    while IFS= read -r var; do
        local name
        name=$(echo "$var" | tr '[:upper:]' '[:lower:]')
        if [[ "$name" != "address" && "$name" != "" ]]; then
            accounts+=("$name")
        fi
    done < <(env | grep -oP '^EMAIL_\K[A-Z]+(?=_ADDRESS)' 2>/dev/null || true)

    echo "${accounts[@]}"
}

get_account_var() {
    local account="$1"
    local var_suffix="$2"

    if [[ "$account" == "default" ]]; then
        local var_name
        case "$var_suffix" in
            ADDRESS) var_name="EMAIL_ADDRESS" ;;
            USER) var_name="EMAIL_USER" ;;
            PASSWORD) var_name="EMAIL_PASSWORD" ;;
            IMAP_HOST) var_name="IMAP_HOST" ;;
            SMTP_HOST) var_name="SMTP_HOST" ;;
            IMAP_PORT) var_name="IMAP_PORT" ;;
            SMTP_PORT) var_name="SMTP_PORT" ;;
            *) var_name="EMAIL_${var_suffix}" ;;
        esac
        printenv "$var_name" 2>/dev/null || echo ""
    else
        local prefix
        prefix="EMAIL_$(echo "$account" | tr '[:lower:]' '[:upper:]')"
        printenv "${prefix}_${var_suffix}" 2>/dev/null || echo ""
    fi
}

validate_account() {
    local account="$1"
    local accounts
    read -ra accounts <<< "$(discover_accounts)"

    for acc in "${accounts[@]}"; do
        if [[ "$acc" == "$account" ]]; then
            return 0
        fi
    done

    log_error "Account '$account' not found."
    echo "Available accounts: ${accounts[*]}"
    echo ""
    echo "Use './email.sh accounts' to see configured accounts."
    exit 1
}

validate_required_vars() {
    local account="${1:-default}"
    local missing=()

    [[ -z "$(get_account_var "$account" ADDRESS)" ]] && missing+=("ADDRESS")
    [[ -z "$(get_account_var "$account" USER)" ]] && missing+=("USER")
    [[ -z "$(get_account_var "$account" PASSWORD)" ]] && missing+=("PASSWORD")
    [[ -z "$(get_account_var "$account" IMAP_HOST)" ]] && missing+=("IMAP_HOST")
    [[ -z "$(get_account_var "$account" SMTP_HOST)" ]] && missing+=("SMTP_HOST")

    if [[ ${#missing[@]} -gt 0 ]]; then
        if [[ "$account" == "default" ]]; then
            log_error "Missing required environment variables."
            echo ""
            echo "Required environment variables:"
            echo "  EMAIL_ADDRESS   - Your email address"
            echo "  EMAIL_USER      - IMAP/SMTP login"
            echo "  EMAIL_PASSWORD  - App password"
            echo "  IMAP_HOST       - IMAP server hostname"
            echo "  SMTP_HOST       - SMTP server hostname"
            echo ""
            echo "Optional:"
            echo "  IMAP_PORT       - IMAP port (default: 993)"
            echo "  SMTP_PORT       - SMTP port (default: 587)"
        else
            local prefix
            prefix="EMAIL_$(echo "$account" | tr '[:lower:]' '[:upper:]')"
            log_error "Missing required environment variables for account '$account'."
            echo ""
            echo "Required environment variables:"
            for var in "${missing[@]}"; do
                echo "  ${prefix}_${var}"
            done
        fi
        exit 1
    fi
}

# ============================================================================
# Configuration Generation
# ============================================================================

generate_account_config() {
    local name="$1"
    local addr user imap_host smtp_host imap_port smtp_port pass_var

    addr=$(get_account_var "$name" ADDRESS)
    user=$(get_account_var "$name" USER)
    imap_host=$(get_account_var "$name" IMAP_HOST)
    smtp_host=$(get_account_var "$name" SMTP_HOST)
    imap_port=$(get_account_var "$name" IMAP_PORT)
    smtp_port=$(get_account_var "$name" SMTP_PORT)

    # Determine password env var name for printenv command
    if [[ "$name" == "default" ]]; then
        pass_var="EMAIL_PASSWORD"
    else
        pass_var="EMAIL_$(echo "$name" | tr '[:lower:]' '[:upper:]')_PASSWORD"
    fi

    cat << TOML
[accounts.${name}]
email = "${addr}"
backend.type = "imap"
backend.host = "${imap_host}"
backend.port = ${imap_port:-993}
backend.login = "${user}"
backend.auth.type = "password"
backend.auth.cmd = "printenv ${pass_var}"

message.send.backend.type = "smtp"
message.send.backend.host = "${smtp_host}"
message.send.backend.port = ${smtp_port:-587}
message.send.backend.login = "${user}"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "printenv ${pass_var}"

TOML
}

generate_config() {
    CONFIG_FILE=$(mktemp --suffix=.toml)
    chmod 600 "$CONFIG_FILE"

    local accounts
    read -ra accounts <<< "$(discover_accounts)"

    for account in "${accounts[@]}"; do
        generate_account_config "$account" >> "$CONFIG_FILE"
    done

    # Note: himalaya v1.1+ doesn't support [default] section
    # Default account is selected via -a flag or first account in config
}

cleanup() {
    if [[ -n "${CONFIG_FILE:-}" && -f "$CONFIG_FILE" ]]; then
        rm -f "$CONFIG_FILE"
    fi
}

trap cleanup EXIT

# ============================================================================
# Himalaya Wrapper
# ============================================================================

run_himalaya() {
    # himalaya v1.1+ requires -a/--account as subcommand option
    # Usage: run_himalaya <subcommand> <sub-subcommand> [args...]
    local account="${SELECTED_ACCOUNT:-}"
    local args=("--config" "$CONFIG_FILE")

    # Add all arguments first
    args+=("$@")

    # Fallback to first available account if none selected
    if [[ -z "$account" ]]; then
        local accounts
        read -ra accounts <<< "$(discover_accounts)"
        if [[ ${#accounts[@]} -gt 0 ]]; then
            account="${accounts[0]}"
        fi
    fi

    # Append account at the end (required for himalaya v1.1+)
    if [[ -n "$account" ]]; then
        args+=("-a" "$account")
    fi

    himalaya "${args[@]}"
}

# ============================================================================
# Command Implementations
# ============================================================================

cmd_inbox() {
    local limit=$DEFAULT_LIMIT
    local unread=false
    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)
                limit="$2"
                [[ $limit -gt $MAX_LIMIT ]] && limit=$MAX_LIMIT
                shift 2
                ;;
            --unread)
                unread=true
                shift
                ;;
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    local query_args=()
    query_args+=("-f" "INBOX")
    query_args+=("-s" "$limit")

    if [[ "$unread" == true ]]; then
        query_args+=("-q" "UNSEEN")
    fi

    local result
    result=$(run_himalaya envelope list "${query_args[@]}" 2>&1) || true

    if [[ -z "$result" || "$result" == *"no envelope"* ]]; then
        echo "No messages in INBOX."
        return 0
    fi

    echo "$result"
}

cmd_list() {
    local folder="${1:-}"
    shift || true

    if [[ -z "$folder" ]]; then
        die "Usage: ./email.sh list <folder> [--limit N] [--account NAME]"
    fi

    local limit=$DEFAULT_LIMIT
    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)
                limit="$2"
                [[ $limit -gt $MAX_LIMIT ]] && limit=$MAX_LIMIT
                shift 2
                ;;
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    run_himalaya envelope list -f "$folder" -s "$limit"
}

cmd_read() {
    local id="${1:-}"
    shift || true

    if [[ -z "$id" ]]; then
        die "Usage: ./email.sh read <id> [--raw] [--account NAME]"
    fi

    local raw=false
    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --raw)
                raw=true
                shift
                ;;
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    if [[ "$raw" == true ]]; then
        run_himalaya message read "$id" --raw
    else
        run_himalaya message read "$id"
    fi
}

cmd_search() {
    local query="${1:-}"
    shift || true

    if [[ -z "$query" ]]; then
        die "Usage: ./email.sh search <query> [--account NAME]"
    fi

    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    # himalaya v1.1+ uses positional args for query, not -q flag
    run_himalaya envelope list "$query"
}

cmd_folders() {
    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    run_himalaya folder list
}

cmd_send() {
    local to=""
    local cc=""
    local bcc=""
    local subject=""
    local body=""
    local body_file=""
    local attachments=()
    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --to)
                to="$2"
                shift 2
                ;;
            --cc)
                cc="$2"
                shift 2
                ;;
            --bcc)
                bcc="$2"
                shift 2
                ;;
            --subject)
                subject="$2"
                shift 2
                ;;
            --body)
                body="$2"
                shift 2
                ;;
            --body-file)
                body_file="$2"
                shift 2
                ;;
            --attach)
                attachments+=("$2")
                shift 2
                ;;
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -z "$to" || -z "$subject" ]]; then
        die "Usage: ./email.sh send --to <emails> --subject <text> --body <text>|--body-file <path> [--cc <emails>] [--bcc <emails>] [--attach <file>] [--account NAME]"
    fi

    if [[ -z "$body" && -z "$body_file" ]]; then
        die "Either --body or --body-file is required"
    fi

    if [[ -n "$body_file" ]]; then
        if [[ ! -f "$body_file" ]]; then
            die "Body file not found: $body_file"
        fi
        body=$(cat "$body_file")
    fi

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    # Get sender address
    local from_addr
    from_addr=$(get_account_var "${SELECTED_ACCOUNT:-default}" ADDRESS)

    # Prepare attachments for himalaya
    local attach_args=()
    for att in "${attachments[@]}"; do
        if [[ ! -f "$att" ]]; then
            die "Attachment not found: $att"
        fi
        attach_args+=("--attachment" "$att")
    done

    # Build message
    local message
    message="From: ${from_addr}
To: ${to}"

    [[ -n "$cc" ]] && message+="
Cc: ${cc}"

    [[ -n "$bcc" ]] && message+="
Bcc: ${bcc}"

    message+="
Subject: ${subject}
Content-Type: text/plain; charset=utf-8

${body}"

    # Send via himalaya
    echo "$message" | run_himalaya message send "${attach_args[@]}"
    log_success "Email sent to: $to"
}

cmd_reply() {
    local id="${1:-}"
    shift || true

    if [[ -z "$id" ]]; then
        die "Usage: ./email.sh reply <id> --body <text> [--account NAME]"
    fi

    local body=""
    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --body)
                body="$2"
                shift 2
                ;;
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -z "$body" ]]; then
        die "Usage: ./email.sh reply <id> --body <text> [--account NAME]"
    fi

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    echo "$body" | run_himalaya message reply "$id"
    log_success "Reply sent"
}

cmd_reply_all() {
    local id="${1:-}"
    shift || true

    if [[ -z "$id" ]]; then
        die "Usage: ./email.sh reply-all <id> --body <text> [--account NAME]"
    fi

    local body=""
    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --body)
                body="$2"
                shift 2
                ;;
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -z "$body" ]]; then
        die "Usage: ./email.sh reply-all <id> --body <text> [--account NAME]"
    fi

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    echo "$body" | run_himalaya message reply "$id" --all
    log_success "Reply-all sent"
}

cmd_forward() {
    local id="${1:-}"
    shift || true

    if [[ -z "$id" ]]; then
        die "Usage: ./email.sh forward <id> --to <email> [--body <text>] [--account NAME]"
    fi

    local to=""
    local body=""
    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --to)
                to="$2"
                shift 2
                ;;
            --body)
                body="$2"
                shift 2
                ;;
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -z "$to" ]]; then
        die "Usage: ./email.sh forward <id> --to <email> [--body <text>] [--account NAME]"
    fi

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    # Forward with optional body
    if [[ -n "$body" ]]; then
        echo "$body" | run_himalaya message forward "$id" --to "$to"
    else
        run_himalaya message forward "$id" --to "$to"
    fi
    log_success "Message forwarded to: $to"
}

cmd_draft() {
    local to=""
    local cc=""
    local subject=""
    local body=""
    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --to)
                to="$2"
                shift 2
                ;;
            --cc)
                cc="$2"
                shift 2
                ;;
            --subject)
                subject="$2"
                shift 2
                ;;
            --body)
                body="$2"
                shift 2
                ;;
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -z "$to" || -z "$subject" || -z "$body" ]]; then
        die "Usage: ./email.sh draft --to <email> --subject <text> --body <text> [--account NAME]"
    fi

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    local from_addr
    from_addr=$(get_account_var "${SELECTED_ACCOUNT:-default}" ADDRESS)

    local message
    message="From: ${from_addr}
To: ${to}"

    [[ -n "$cc" ]] && message+="
Cc: ${cc}"

    message+="
Subject: ${subject}
Content-Type: text/plain; charset=utf-8

${body}"

    echo "$message" | run_himalaya message save -f Drafts
    log_success "Draft saved"
}

cmd_mark_read() {
    local id="${1:-}"
    shift || true

    if [[ -z "$id" ]]; then
        die "Usage: ./email.sh mark-read <id> [--account NAME]"
    fi

    local account=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    run_himalaya flag add "$id" seen
    log_success "Message $id marked as read"
}

cmd_mark_unread() {
    local id="${1:-}"
    shift || true

    if [[ -z "$id" ]]; then
        die "Usage: ./email.sh mark-unread <id> [--account NAME]"
    fi

    local account=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    run_himalaya flag remove "$id" seen
    log_success "Message $id marked as unread"
}

cmd_move() {
    local id="${1:-}"
    local folder="${2:-}"
    shift 2 || true

    if [[ -z "$id" || -z "$folder" ]]; then
        die "Usage: ./email.sh move <id> <folder> [--account NAME]"
    fi

    local account=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    # himalaya v1.1+: message move <TARGET> <ID>
    run_himalaya message move "$folder" "$id"
    log_success "Message $id moved to $folder"
}

cmd_delete() {
    local id="${1:-}"
    shift || true

    if [[ -z "$id" ]]; then
        die "Usage: ./email.sh delete <id> [--permanent] [--account NAME]"
    fi

    local permanent=false
    local account=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --permanent)
                permanent=true
                shift
                ;;
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    if [[ "$permanent" == true ]]; then
        run_himalaya message delete "$id"
        log_success "Message $id permanently deleted"
    else
        # himalaya v1.1+: message move <TARGET> <ID>
        run_himalaya message move Trash "$id"
        log_success "Message $id moved to Trash"
    fi
}

cmd_download() {
    local id="${1:-}"
    shift || true

    if [[ -z "$id" ]]; then
        die "Usage: ./email.sh download <id> [--account NAME]"
    fi

    local account=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --account)
                account="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ -n "$account" ]]; then
        validate_account "$account"
        SELECTED_ACCOUNT="$account"
    fi

    # himalaya v1.1+ downloads to configured downloads-dir (default: ~/Downloads)
    # No -o flag available
    run_himalaya attachment download "$id"
    log_success "Attachments downloaded to downloads directory"
}

cmd_accounts() {
    local accounts
    read -ra accounts <<< "$(discover_accounts)"

    if [[ ${#accounts[@]} -eq 0 ]]; then
        echo "No accounts configured."
        echo ""
        echo "Configure at least one account with:"
        echo "  EMAIL_ADDRESS, EMAIL_USER, EMAIL_PASSWORD, IMAP_HOST, SMTP_HOST"
        return 0
    fi

    echo "Configured accounts:"
    echo ""
    for acc in "${accounts[@]}"; do
        local addr
        addr=$(get_account_var "$acc" ADDRESS)
        echo "  - $acc: $addr"
    done
}

cmd_help() {
    cat << 'EOF'
email.sh - CLI wrapper for Himalaya email client

USAGE:
    ./email.sh <command> [options]

READING:
    inbox [--limit N] [--unread] [--account NAME]
        Show inbox messages (default limit: 50)

    list <folder> [--limit N] [--account NAME]
        List messages in a folder

    read <id> [--raw] [--account NAME]
        Read a message by ID

    search <query> [--account NAME]
        Search messages (supports IMAP search syntax)
        Examples: "FROM:boss@company.com", "SUBJECT:meeting", "UNSEEN"

    folders [--account NAME]
        List available folders

SENDING:
    send --to <emails> --subject <text> --body <text>|--body-file <path>
         [--cc <emails>] [--bcc <emails>] [--attach <file>...] [--account NAME]
        Send a new email

    reply <id> --body <text> [--account NAME]
        Reply to a message

    reply-all <id> --body <text> [--account NAME]
        Reply to all recipients

    forward <id> --to <email> [--body <text>] [--account NAME]
        Forward a message

    draft --to <email> --subject <text> --body <text> [--account NAME]
        Save a message as draft

MANAGEMENT:
    mark-read <id> [--account NAME]
        Mark message as read

    mark-unread <id> [--account NAME]
        Mark message as unread

    move <id> <folder> [--account NAME]
        Move message to folder

    delete <id> [--account NAME]
        Move message to Trash

    delete <id> --permanent [--account NAME]
        Permanently delete message (EXPUNGE)

    download <id> [--account NAME]
        Download attachments to ~/Downloads/email-attachments/

INFORMATION:
    accounts
        List configured email accounts

    help
        Show this help message

ENVIRONMENT VARIABLES:
    Single Account:
        EMAIL_ADDRESS   - Your email address
        EMAIL_USER      - IMAP/SMTP login
        EMAIL_PASSWORD  - App password
        IMAP_HOST       - IMAP server hostname
        SMTP_HOST       - SMTP server hostname
        IMAP_PORT       - IMAP port (default: 993)
        SMTP_PORT       - SMTP port (default: 587)

    Multi-Account (pattern EMAIL_{NAME}_*):
        EMAIL_WORK_ADDRESS, EMAIL_WORK_USER, EMAIL_WORK_PASSWORD, etc.
        EMAIL_PERSONAL_ADDRESS, EMAIL_PERSONAL_USER, etc.

EXAMPLES:
    ./email.sh inbox --limit 10 --unread
    ./email.sh search "FROM:support@example.com"
    ./email.sh send --to "user@example.com" --subject "Hello" --body "Hi there!"
    ./email.sh send --to "a@x.com,b@x.com" --subject "Report" --body-file report.txt --attach data.csv
    ./email.sh inbox --account work
    ./email.sh reply 123 --body "Thanks!" --account personal
EOF
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    local command="${1:-help}"
    shift || true

    # Check for help early
    if [[ "$command" == "-h" || "$command" == "--help" ]]; then
        cmd_help
        return 0
    fi

    # Commands that don't need himalaya or config
    case "$command" in
        help)
            cmd_help
            return 0
            ;;
        accounts)
            cmd_accounts
            return 0
            ;;
    esac

    # Ensure himalaya is available
    ensure_himalaya

    # Validate configuration
    local accounts
    read -ra accounts <<< "$(discover_accounts)"

    if [[ ${#accounts[@]} -eq 0 ]]; then
        validate_required_vars "default"
    fi

    # Generate configuration
    generate_config

    # Execute command
    case "$command" in
        inbox)
            cmd_inbox "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        read)
            cmd_read "$@"
            ;;
        search)
            cmd_search "$@"
            ;;
        folders)
            cmd_folders "$@"
            ;;
        send)
            cmd_send "$@"
            ;;
        reply)
            cmd_reply "$@"
            ;;
        reply-all)
            cmd_reply_all "$@"
            ;;
        forward)
            cmd_forward "$@"
            ;;
        draft)
            cmd_draft "$@"
            ;;
        mark-read)
            cmd_mark_read "$@"
            ;;
        mark-unread)
            cmd_mark_unread "$@"
            ;;
        move)
            cmd_move "$@"
            ;;
        delete)
            cmd_delete "$@"
            ;;
        download)
            cmd_download "$@"
            ;;
        *)
            die "Unknown command: $command. Use './email.sh help' for usage."
            ;;
    esac
}

main "$@"
