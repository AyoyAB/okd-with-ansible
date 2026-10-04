#!/usr/bin/env bash
# Write an ISO to every external physical disk in parallel, then eject them.
set -euo pipefail

if [[ $# -ne 1 || ! -f $1 ]]; then
  echo "usage: $0 <file.iso>" >&2
  exit 1
fi
iso=$1

disks=()
while IFS= read -r d; do disks+=("$d"); done < <(
  diskutil list external physical | awk '/^\/dev\/disk[0-9]+/ {print $1}'
)

if [[ ${#disks[@]} -eq 0 ]]; then
  echo "No external disks found." >&2
  exit 1
fi

diskutil list external physical
echo
read -r -p "Erase ALL of ${disks[*]} and write $(basename "$iso")? [y/N] " answer
[[ $answer == [yY] ]] || { echo "Aborted."; exit 1; }

sudo -v

pids=()
for d in "${disks[@]}"; do
  diskutil unmountDisk "$d" >/dev/null
  echo "Writing $d ..."
  sudo dd if="$iso" of="${d/disk/rdisk}" bs=4m &
  pids+=($!)
done

failed=0
for i in "${!disks[@]}"; do
  if wait "${pids[$i]}"; then
    echo "${disks[$i]}: done"
  else
    echo "${disks[$i]}: FAILED" >&2
    failed=1
  fi
done

for d in "${disks[@]}"; do diskutil eject "$d" || true; done
exit $failed
