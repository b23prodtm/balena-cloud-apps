#!/usr/bin/env bash
STORAGE="$(find /mnt/external-drives -name "storage_*$DEVNAME*" | head -n 1)"
printf "Storage found at %s...\n" "$STORAGE"
printf "Run shell command mysqldump...\n"
export MYSQL_PWD="${MYSQL_ROOT_PASSWORD:-mariadb}"
DUMP_FILE="$STORAGE/backup_$(date +%F_%H-%M-%S).sql"
ERROR_LOG="$STORAGE/error.log"
mysqldump -h db -u root --all-databases > "$DUMP_FILE" 2>> "$ERROR_LOG"
printf "Delete dumps older than 6 months..."
find "$STORAGE" -type f -name "backup_*.sql" -mmin +259200 -exec rm -f {} \;

#Cold backup works on balenaCloud only
if [[ ! "$(command -v balena)" > /dev/null ]]; then
	printf "balena-cli was not installed, cannot perform cold backup.\n"
else
	CONTAINER_NAME=$(balena ps | grep db | xargs printf "%s\n" "$1" | head -n 1)
	printf "Making full backup of databases container %s...\n" "$CONTAINER_NAME"
	balena cp "$CONTAINER_NAME:/config" "$STORAGE/db-data_$(date +%F_%H-%M-%S)"
	printf "Delete backups older than 1 month..."
	find "$STORAGE" -type f -name "db-data_*" -mmin +64800 -exec rm -f {} \;
fi
