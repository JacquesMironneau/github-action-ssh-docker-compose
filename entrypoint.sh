#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/workspace.tar.bz2
}
trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/workspace.tar.bz2 --exclude .git .
ls /tmp
log "Launching ssh agent."
eval `ssh-agent -s`

ssh-add <(echo "$SSH_PRIVATE_KEY")

remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace...'; rm -rf \"\/home/debian/workspace/!(data)\" || true ; } ; log 'Creating workspace directory...' ; ls /home/debian ; mkdir -p \"\/home/debian/workspace\" ; trap cleanup EXIT ; log 'Unpacking workspace...' ; tar -C \"\/home/debian/workspace\" -xjv ; log 'Launching docker-compose...' ; cd \"\/home/debian/workspace\" ; docker-compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" up -d --remove-orphans --build --force-recreate"

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2
